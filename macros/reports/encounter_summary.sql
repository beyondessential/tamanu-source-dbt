{% macro encounter_summary_report(date_field, is_sensitive=false) %}
{#-
    See specs/reports/encounter-summary.md for the BL clauses this macro implements.

    Presentation only. Every row comes from encounter_summary_core(), which resolves the
    encounter, its movement history and its clinical aggregates; this macro applies
    translate_label, to_char and the viewer's timezone, and nothing else.

    A deployment repo needing extra columns calls the core directly and writes its own
    projection, rather than forking this body.
-#}

select
    display_id as "{{ translate_label('patientDisplayId') }}",
    first_name as "{{ translate_label('patientFirstName') }}",
    last_name as "{{ translate_label('patientLastName') }}",
    to_char(date_of_birth, '{{ var("date_format") }}') as "{{ translate_label('patientDateOfBirth') }}",
    date_part('year', age(start_datetime, date_of_birth)) as "{{ translate_label('patientAge') }}",
    sex as "{{ translate_label('patientSex') }}",
    ethnicity as "{{ translate_label('patientEthnicity') }}",
    billing_type as "{{ translate_label('patientBillingType') }}",
    division as "{{ translate_label('patientDivision') }}",
    subdivision as "{{ translate_label('patientSubDivision') }}",
    village as "{{ translate_label('patientVillage') }}",
    to_char({{ to_user_selected_timezone('start_datetime') }}, '{{ var("datetime_format") }}') as "{{ translate_label('encounterStartDateTime') }}",
    to_char({{ to_user_selected_timezone('end_datetime') }}, '{{ var("datetime_format") }}') as "{{ translate_label('encounterEndDateTime') }}",
    case
        when end_datetime is not null then
            case
                when {{ to_user_selected_timezone('end_datetime') }}::date - {{ to_user_selected_timezone('start_datetime') }}::date < 1 then 1
                else {{ to_user_selected_timezone('end_datetime') }}::date - {{ to_user_selected_timezone('start_datetime') }}::date
            end
    end as "{{ translate_label('encounterLengthOfStay') }}",
    facility as "{{ translate_label('facility') }}",
    encounter_type_emergency as "{{ translate_label('encounterTypeEmergency') }}",
    encounter_type_inpatient as "{{ translate_label('encounterTypeInpatient') }}",
    encounter_type_outpatient as "{{ translate_label('encounterTypeOutpatient') }}",
    discharge_disposition as "{{ translate_label('dischargeDisposition') }}",
    triage_score as "{{ translate_label('triageCategory') }}",
    triage_arrival_mode as "{{ translate_label('triageArrivalMode') }}",
    case
        when triage_closed_datetime notnull and triage_datetime notnull and triage_closed_datetime > triage_datetime
            then concat(
                lpad((
                    extract(day from (triage_closed_datetime - triage_datetime)) * 24
                    + extract(hour from (triage_closed_datetime - triage_datetime))
                )::text, 2, '0'), ':',
                lpad(extract(minute from (triage_closed_datetime - triage_datetime))::text, 2, '0'), ':',
                lpad(
                    (extract(second from (triage_closed_datetime - triage_datetime))::int)::text, 2, '0'
                )
            )
    end as "{{ translate_label('triageWaitingTime') }}",
    encountering_clinician as "{{ translate_label('encounterClinician') }}",
    supervising_clinician as "{{ translate_label('encounterSupervisingClinician') }}",
    discharge_department as "{{ translate_label('dischargeDepartment') }}",
    discharge_department_datetime as "{{ translate_label('dischargeAssignedTime') }} {{ translate_label('dischargeDepartment') }}",
    discharge_location_group as "{{ translate_label('dischargeLocationGroup') }}",
    discharge_location_group_datetime as "{{ translate_label('dischargeAssignedTime') }} {{ translate_label('dischargeLocationGroup') }}",
    discharge_location as "{{ translate_label('dischargeLocation') }}",
    discharge_location_datetime as "{{ translate_label('dischargeAssignedTime') }} {{ translate_label('dischargeLocation') }}",
    departments as "{{ translate_label('encounterDepartmentHistory') }}",
    array_to_string(department_datetimes, ', ') as "{{ translate_label('encounterDepartmentHistoryDateTimes') }}",
    location_groups as "{{ translate_label('encounterLocationGroupHistory') }}",
    array_to_string(location_group_datetimes, ', ') as "{{ translate_label('encounterLocationGroupHistoryDateTimes') }}",
    locations as "{{ translate_label('encounterLocationHistory') }}",
    array_to_string(location_datetimes, ', ') as "{{ translate_label('encounterLocationHistoryDateTimes') }}",
    reason_for_encounter as "{{ translate_label('encounterReasonForEncounter') }}",
    diagnoses as "{{ translate_label('diagnoses') }}",
    diagnosis_codes as "{{ translate_label('diagnosesCodes') }}",
    medications as "{{ translate_label('medications') }}",
    vaccinations as "{{ translate_label('vaccinations') }}",
    procedures as "{{ translate_label('procedures') }}",
    lab_requests as "{{ translate_label('labRequests') }}",
    imaging_requests as "{{ translate_label('imagingRequests') }}",
    case
        when length(notes) > 32000
            then concat(
                'THIS CELL HAS BEEN CROPPED AS IT EXCEEDED THE MAXIMUM LENGTH IN EXCEL - PLEASE SEE TAMANU FOR ',
                'FULL NOTES HISTORY', '' || E'\n' || '', left(notes, 32000)
            )
        else notes
    end as "{{ translate_label('notes') }}"
from (
    {{ encounter_summary_core(date_field=date_field, is_sensitive=is_sensitive) }}
) core
order by {{ date_field }} desc

{% endmacro %}
