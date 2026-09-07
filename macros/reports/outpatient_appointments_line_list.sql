{% macro outpatient_appointments_line_list_report(is_sensitive=false) %}
{#-
    Outpatient Appointments Line List.

    See specs/reports/outpatient-appointments-line-list.md for the BL clauses this macro
    implements.

    # BL-047: presentation only, and shared by both variants. Every row comes from
    outpatient_appointments_dataset(), which resolves the appointment, its patient, its
    area/facility and its creator; this macro builds the scope predicate and applies
    translate_label, to_char and the viewer's timezone, and nothing else. The standard and
    sensitive report models are one-line calls, so the two cannot drift.

    A deployment repo needing extra columns calls the dataset macro directly with its own
    appointment_filter and writes its own projection, rather than forking this body.

    # BL-042: every filter is pushed into the dataset's scope CTE rather than applied on the
    outside. That is what stops the creator lookup windowing the whole appointment change
    history on every run (BL-044), and it is the same move BL-030 makes in
    audit_outpatient_appointments. Unlike BL-030 there is no outer where clause acting as a
    safety net, so these predicates must be exact rather than a superset -- with the one
    deliberate exception in BL-043, which is paired with the exact bound it widens.
-#}

{%- set from_bound = parameter('fromDate', default_value='2025-01-01', data_type='date') -%}
{%- set to_bound = parameter('toDate', default_value='2025-01-31', data_type='date') -%}

{%- set appointment_filter -%}
    -- BL-043: bare-column bounds, widened a day past each exact bound, so a btree index on
    -- appointments.start_time can prune -- the exact predicate below wraps the column in
    -- two `at time zone` conversions and can use no index at all. The widening covers the
    -- :timezone round trip, which can move the value by up to the zone offset in either
    -- direction; correctness rests on the exact predicate, so the superset only has to be
    -- a superset.
    --
    -- from_user_selected_timezone() is not usable here: it is only valid against a
    -- timestamptz column, and start_datetime is a naive timestamp
    -- (`a.start_time::timestamp` in the base model).
    --
    -- The ::date cast keeps `:toDate + interval` out of interval parsing -- parameter()
    -- compiles to an untyped placeholder, the same trap BL-029 documents.
    a.start_datetime >= ({{ from_bound }})::date - interval '1 day'
    and a.start_datetime < ({{ to_bound }})::date + interval '2 days'
    -- BL-041: the range bounds the appointment's scheduled start time, not when it was
    -- booked -- the opposite of the audit report's BL-029. Tamanu binds fromDate as
    -- start-of-day and toDate as end-of-day (getReportQueryReplacements in ../tamanu), so
    -- the house `<= toDate` form covers the whole of toDate.
    and {{ to_user_selected_timezone('a.start_datetime') }} >= {{ from_bound }}
    and {{ to_user_selected_timezone('a.start_datetime') }} <= {{ to_bound }}
    -- BL-045: facilityId is declared by the report config's FacilityField. It went
    -- unreferenced until this macro existed, so a facility selection returned every
    -- facility's appointments.
    and case
        when {{ parameter('facilityId') }} is null then true
        else f.id = {{ parameter('facilityId') }}
    end
    and case
        when {{ parameter('locationGroupId') }} is null then true
        else lg.id = {{ parameter('locationGroupId') }}
    end
    and case
        when {{ parameter('appointmentStatus') }} is null then true
        else a.status in ({{ parameter('appointmentStatus') }})
    end
    and case
        when {{ parameter('clinicianId') }} is null then true
        else a.clinician_id = {{ parameter('clinicianId') }}
    end
    and case
        when {{ parameter('appointmentTypeId') }} is null then true
        else a.appointment_type_id = {{ parameter('appointmentTypeId') }}
    end
{%- endset -%}

select
    display_id as "{{ translate_label('patientDisplayId') }}",
    first_name as "{{ translate_label('patientFirstName') }}",
    last_name as "{{ translate_label('patientLastName') }}",
    to_char(date_of_birth, '{{ var("date_format") }}') as "{{ translate_label('patientDateOfBirth') }}",
    age as "{{ translate_label('patientAge') }}",
    sex as "{{ translate_label('patientSex') }}",
    contact_number as "{{ translate_label('patientContactNumber') }}",
    village as "{{ translate_label('patientVillage') }}",
    billing_type as "{{ translate_label('patientBillingType') }}",
    to_char({{ to_user_selected_timezone('appointment_start_datetime') }}, '{{ var("datetime_format") }}') as "{{ translate_label('appointmentDateTime') }}",
    to_char({{ to_user_selected_timezone('appointment_end_datetime') }}, '{{ var("datetime_format") }}') as "{{ translate_label('appointmentEndDateTime') }}",
    appointment_type as "{{ translate_label('appointmentType') }}",
    appointment_status as "{{ translate_label('appointmentStatus') }}",
    clinician as "{{ translate_label('appointmentClinician') }}",
    location_group as "{{ translate_label('appointmentLocationGroup') }}",
    priority as "{{ translate_label('appointmentPriority') }}",
    -- BL-048: one column carries two kinds of value -- the recurrence description for a
    -- scheduled appointment, the literal 'No' for a one-off.
    case
        when schedule_id notnull then {{ get_recurrence_description('interval', 'frequency', 'days_of_week', 'nth_weekday') }}
        else 'No'
    end as "{{ translate_label('appointmentIsRepeating') }}",
    to_char(until_date, '{{ var("date_format") }}') as "{{ translate_label('appointmentRepeatingEndDate') }}",
    created_by as "{{ translate_label('appointmentCreatedBy') }}"
from (
    {{ outpatient_appointments_dataset(
        is_sensitive=is_sensitive,
        appointment_filter=appointment_filter
    ) }}
) core
order by appointment_start_datetime

{% endmacro %}
