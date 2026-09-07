{% macro outpatient_appointments_dataset(is_sensitive=false, appointment_filter=none) %}
{#-
    Appointment rows resolved to their patient, area, facility and creator.

    See specs/reports/outpatient-appointments-line-list.md for the BL clauses this macro
    implements.

    # BL-046: alias contract, mirroring encounters_core()'s BL-003. `appointment_filter` is
    raw SQL spliced into the scope CTE's where clause, so it may reference exactly these
    aliases:
        a   outpatient_appointments
        lg  location_groups
        f   facilities
    Nothing else is in scope, and these aliases must not be renamed without updating every
    caller. The predicate is row-selecting only -- the scope CTE has no window functions or
    aggregates, so a caller's predicate cannot change the value of any column, only which
    rows survive.

    # BL-046: deliberately contains no parameter() call. Datasets build on analytics targets,
    where parameter() falls through to a var() literal rather than a bind placeholder, so a
    filter baked in here would be a footgun for dataset callers. Report callers pass their
    own predicate text -- see outpatient_appointments_line_list_report().
-#}

with appointments_in_scope as (
    -- BL-040: one row per appointment, over the population bases/outpatient_appointments
    -- defines -- not one row per change event, which is the audit report's grain.
    select
        a.id as appointment_id,
        a.patient_id,
        a.start_datetime,
        a.end_datetime,
        a.appointment_type_id,
        a.status,
        a.clinician_id,
        a.priority,
        a.schedule_id,
        a.until_date,
        a.interval,
        a.days_of_week,
        a.frequency,
        a.nth_weekday,
        lg.id as location_group_id,
        lg.name as location_group,
        f.id as facility_id,
        f.name as facility
    from {{ ref('outpatient_appointments') }} a
    -- BL-045: area and facility are inner joins, so an appointment whose location_group_id
    -- is null or dangling produces no row at all, and the facility partition is applied
    -- here rather than left to the caller.
    join {{ ref('location_groups') }} lg on lg.id = a.location_group_id
    join {{ ref('facilities') }} f on f.id = lg.facility_id
        and f.is_sensitive = {{ is_sensitive }}
{#- BL-042: `where` and each paren sit on their own line. A caller's predicate text may
    legally end on a `--` comment, and a same-line `)` would then be commented out and the
    model would fail to compile. Same reasoning as encounters_core(). #}
{%- if appointment_filter %}
    where
    (
    {{ appointment_filter }}
    )
{%- endif %}
),

appointment_creators as (
    -- BL-044: the creator is the actor on the appointment's earliest surviving change
    -- event. `distinct on` picks the same row that `change_sequence = 1` picks in
    -- outpatient_appointments_change_logs: same source rows (both read
    -- outpatient_appointments_change_events, which applies the BL-037 filters), same
    -- ordering, and at that row first_value(updated_by_user_id) is just
    -- updated_by_user_id.
    --
    -- Reading outpatient_appointments_change_logs instead would put row_number() / lag()
    -- between this scope filter and the change-log scan, and window functions are an
    -- optimisation fence -- a one-month report would window the whole appointment change
    -- history, carrying every row's JSONB record_data through the sort. Filtering the
    -- change events by the appointments already in scope is the same move BL-030 makes in
    -- audit_outpatient_appointments. BL-031's note that the base model itself cannot be
    -- date-scoped still holds; this simply no longer depends on that model.
    select distinct on (c.record_id)
        c.record_id as appointment_id,
        c.updated_by_user_id as created_by_user_id
    from {{ ref('outpatient_appointments_change_events') }} c
    join appointments_in_scope s on s.appointment_id = c.record_id
    order by c.record_id, c.logged_at, c.record_updated_at, c.id
)

select
    a.appointment_id,
    p.id as patient_id,
    p.display_id,
    p.first_name,
    p.last_name,
    p.date_of_birth,
    date_part('year', age(a.start_datetime, p.date_of_birth)) as age,
    p.sex,
    coalesce(pd.primary_contact_number, pd.secondary_contact_number) as contact_number,
    vil.id as village_id,
    vil.name as village,
    billing.id as billing_type_id,
    billing.name as billing_type,
    a.start_datetime as appointment_start_datetime,
    a.end_datetime as appointment_end_datetime,
    a.appointment_type_id,
    apt.name as appointment_type,
    a.status as appointment_status,
    u.id as clinician_id,
    u.display_name as clinician,
    a.location_group_id,
    a.location_group,
    a.facility_id,
    a.facility,
    a.priority,
    a.schedule_id,
    a.until_date,
    a.interval,
    a.days_of_week,
    a.frequency,
    a.nth_weekday,
    ac.created_by_user_id,
    creator.display_name as created_by
-- BL-042: the patient, reference-data and creator joins run against the scoped set, not
-- the whole appointment table.
from appointments_in_scope a
join {{ ref('patients') }} p on p.id = a.patient_id
left join {{ ref('users') }} u on u.id = a.clinician_id
left join {{ ref('patient_additional_data') }} pd on pd.patient_id = p.id
left join {{ ref('reference_data') }} billing on billing.id = pd.patient_billing_type_id
left join {{ ref('reference_data') }} vil on vil.id = p.village_id
left join {{ ref('reference_data') }} apt on apt.id = a.appointment_type_id
left join appointment_creators ac on ac.appointment_id = a.appointment_id
left join {{ ref('users') }} creator on creator.id = ac.created_by_user_id

{% endmacro %}
