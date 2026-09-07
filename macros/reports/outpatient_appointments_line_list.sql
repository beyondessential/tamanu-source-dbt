{% macro outpatient_appointments_line_list_report(is_sensitive=false) %}
{#-
    Outpatient Appointments Line List.

    Presentation only. Every row comes from outpatient_appointments_dataset(), which
    resolves the appointment, its patient, its area/facility and its creator; this macro
    builds the scope predicate and applies translate_label, to_char and the viewer's
    timezone, and nothing else.

    A deployment repo needing extra columns calls the dataset macro directly with its own
    appointment_filter and writes its own projection, rather than forking this body.

    Every filter is pushed into the dataset's scope CTE rather than applied on the
    outside. That is what stops the creator lookup windowing the whole appointment change
    history on every run -- see the appointment_creators comment in
    macros/datasets/outpatient_appointments.sql -- and it is the same move BL-030 makes
    in audit_outpatient_appointments. There is no outer where clause to act as a safety
    net, so unlike BL-030 these predicates must be exact, not a superset.
-#}

{%- set from_bound = parameter('fromDate', default_value='2025-01-01', data_type='date') -%}
{%- set to_bound = parameter('toDate', default_value='2025-01-31', data_type='date') -%}

{%- set appointment_filter -%}
    {#- Bare-column bounds, widened a day at each end, so a btree index on
        appointments.start_time can prune -- the exact predicate below wraps the column in
        two `at time zone` conversions and can use no index at all. The widening covers
        the :timezone round trip, which can move the value by up to the zone offset in
        either direction; the exact predicate is what correctness rests on, so the
        superset only has to be a superset.

        `from_user_selected_timezone()` is not usable here: it is only valid against a
        timestamptz column, and start_datetime is a naive timestamp (`a.start_time::timestamp`
        in the base model).

        The ::date cast keeps `:toDate + interval` out of interval parsing -- parameter()
        compiles to an untyped placeholder, same trap as BL-029. -#}
    a.start_datetime >= ({{ from_bound }})::date - interval '1 day'
    and a.start_datetime < ({{ to_bound }})::date + interval '2 days'
    -- Exact bounds. Tamanu binds fromDate as start-of-day and toDate as end-of-day
    -- (getReportQueryReplacements in ../tamanu), so `<=` covers the whole of toDate.
    and {{ to_user_selected_timezone('a.start_datetime') }} >= {{ from_bound }}
    and {{ to_user_selected_timezone('a.start_datetime') }} <= {{ to_bound }}
    -- Declared by the report config's FacilityField and previously never applied, so a
    -- facility selection returned every facility's appointments.
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
