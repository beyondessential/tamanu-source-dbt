{% macro discharge_audit_dataset(is_sensitive=false) %}

-- Discharge Audit Dataset
-- One row per discharge record, which is one row per discharged encounter.
--
-- Exposes both discharge timestamps side by side:
--   discharge_datetime_entered   - the clinical discharge date and time keyed into the discharge form
--   discharge_recorded_datetime  - when the discharge was actually recorded in Tamanu
--
-- The gap between them is the discharge-recording backlog.

-- BL-001: the discharges base is already one row per encounter with deleted discharges,
-- deleted encounters and the test patient removed
with discharge_records as (
    select
        d.id as discharge_id,
        d.encounter_id,
        d.discharged_by_id,
        d.disposition_id,
        d.created_datetime,
        -- BL-004: system-generated discharges are flagged, not filtered out
        coalesce(d.note like 'Automatically discharged%', false) as is_auto_discharge
    from {{ ref('discharges') }} d
),

-- BL-002: the earliest change log entry for a discharge is its insert
change_log_summary as (
    select
        cl.discharge_id,
        min(cl.changed_datetime) as recorded_datetime,
        -- BL-008: edits after the insert. The left join below leaves this null, not zero,
        -- where the change log does not cover the discharge at all
        count(*) - 1 as later_edit_count,
        max(cl.changed_by_user_id) filter (where cl.change_sequence = 1) as recorded_by_user_id
    from {{ ref('discharges_change_logs') }} cl
    group by cl.discharge_id
),

encounter_details as (
    select
        e.id as encounter_id,
        e.patient_id,
        e.encounter_type,
        e.start_datetime,
        e.end_datetime,
        e.department_id,
        e.location_id,
        dept.name as department_name,
        loc.name as location_name,
        f.id as facility_id,
        f.name as facility_name
    from {{ ref('encounters') }} e
    join {{ ref('locations') }} loc on loc.id = e.location_id
    join {{ ref('facilities') }} f on f.id = loc.facility_id
        -- BL-009: the standard and sensitive variants partition on this flag
        and f.is_sensitive = {{ is_sensitive }}
    left join {{ ref('departments') }} dept on dept.id = e.department_id
),

discharge_audit as (
    select
        dr.discharge_id,
        dr.is_auto_discharge,
        dr.disposition_id as discharge_disposition_id,
        dr.discharged_by_id as discharger_id,
        ed.encounter_id,
        ed.encounter_type,
        ed.patient_id,
        ed.department_id,
        ed.department_name,
        ed.location_id,
        ed.location_name,
        ed.facility_id,
        ed.facility_name,
        ed.start_datetime as admission_datetime,
        ed.end_datetime as discharge_datetime_entered,
        cls.later_edit_count,
        cls.recorded_by_user_id,
        -- BL-002: fall back to the discharge record's own creation time where the
        -- change log does not reach back far enough
        coalesce(cls.recorded_datetime, dr.created_datetime) as discharge_recorded_datetime
    from discharge_records dr
    join encounter_details ed on ed.encounter_id = dr.encounter_id
    left join change_log_summary cls on cls.discharge_id = dr.discharge_id
)

select
    da.discharge_id,
    da.encounter_id,
    da.encounter_type,
    p.id as patient_id,
    p.display_id,
    p.first_name,
    p.last_name,
    p.date_of_birth,
    initcap(p.sex::text) as sex,
    p.village_id,
    village.name as village,
    da.facility_id,
    da.facility_name as facility,
    da.department_id,
    da.department_name as department,
    da.location_id,
    da.location_name as location,
    da.admission_datetime,
    da.discharge_datetime_entered,
    da.discharge_recorded_datetime,
    -- BL-003: both timestamps are naive deployment-local, so the date difference is
    -- the number of calendar days the discharge went unrecorded
    da.discharge_recorded_datetime::date
    - da.discharge_datetime_entered::date as days_between_discharge_and_recording,
    da.discharge_disposition_id,
    disposition.name as discharge_disposition,
    da.discharger_id,
    -- BL-006: the clinician named on the form and the user who recorded it are
    -- different people in general, so both are kept
    discharger.display_name as discharger_on_form,
    da.recorded_by_user_id,
    -- BL-005: the nil UUID audit user has no matching user, so this renders blank
    recorder.display_name as recorded_by_user,
    da.is_auto_discharge,
    da.later_edit_count
from discharge_audit da
-- BL-001: the patient base drops deleted, merged and test patients, and this join
-- carries that exclusion into the grain
join {{ ref('patients') }} p on p.id = da.patient_id
left join {{ ref('reference_data') }} village on village.id = p.village_id
left join {{ ref('reference_data') }} disposition on disposition.id = da.discharge_disposition_id
left join {{ ref('users') }} discharger on discharger.id = da.discharger_id
left join {{ ref('users') }} recorder on recorder.id = da.recorded_by_user_id

{% endmacro %}
