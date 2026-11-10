-- See specs/reports/medication-administration-record-line-list.md for BL-001..BL-011.
{% macro medication_administration_record_line_list_report(is_sensitive=false) %}

{% set dataset = 'ds__sensitive_prescription_administrations' if is_sensitive else 'ds__prescription_administrations' %}

select
    display_id as "{{ translate_label('patientDisplayId') }}",
    first_name as "{{ translate_label('patientFirstName') }}",
    last_name as "{{ translate_label('patientLastName') }}",
    to_char(date_of_birth, '{{ var("date_format") }}') as "{{ translate_label('patientDateOfBirth') }}",
    sex as "{{ translate_label('patientSex') }}",
    medication as "{{ translate_label('encounterPrescriptionMedication') }}",
    to_char({{ to_user_selected_timezone('datetime') }}, '{{ var("datetime_format") }}') as "{{ translate_label('prescriptionPrescribedDate') }}",
    -- BL-005: prescriber is NULL when none was recorded against the prescription
    prescriber as "{{ translate_label('prescriptionPrescriber') }}",
    -- BL-006: dose and unit come from the prescription, not the administration
    case
        when is_variable_dose then 'Variable'
        else nullif(concat_ws(' ', trim_scale(dose_amount)::text, dosing_unit), '')
    end as "{{ translate_label('prescriptionDose') }}",
    route as "{{ translate_label('prescriptionRoute') }}",
    -- BL-007: administration columns are NULL for a prescription never administered
    to_char({{ to_user_selected_timezone('administered_datetime') }}, '{{ var("datetime_format") }}') as "{{ translate_label('prescriptionAdministeredDateTime') }}",
    administered_by as "{{ translate_label('prescriptionAdministeredBy') }}",
    -- BL-010
    case
        when administration_id is null then null
        when administration_status = 'GIVEN' then 'Given'
        when administration_status = 'NOT_GIVEN' then 'Not given'
        else 'Not recorded'
    end as "{{ translate_label('prescriptionAdministrationStatus') }}",
    -- BL-011: the encounter's current department and location
    department as "{{ translate_label('department') }}",
    location as "{{ translate_label('location') }}",
    facility as "{{ translate_label('facility') }}",
    encounter_type as "{{ translate_label('prescriptionEncounterType') }}",
    -- BL-008: prescription and administration notes, whichever are present
    nullif(concat_ws(' | ', nullif(trim(prescription_notes), ''), nullif(trim(administration_notes), '')), '') as "{{ translate_label('notes') }}"
from {{ ref(dataset) }}
where
    -- BL-002: date range filter on prescription date
    {{ to_user_selected_timezone('datetime') }} >= {{ parameter('fromDate', default_value='2024-01-01', data_type='date') }}
    and {{ to_user_selected_timezone('datetime') }} <= {{ parameter('toDate', default_value='2024-01-31', data_type='date') }}
    -- BL-001, BL-003: multi-select over all drugs. Nothing selected means every medication.
    and {{ multi_select_filter('medication_id', 'medicationId') }}
    -- BL-004: facility, department and location filters, each nullable
    and case when {{ parameter('facilityId') }} is null then true
        else facility_id = {{ parameter('facilityId') }}
    end
    and case when {{ parameter('departmentId') }} is null then true
        else department_id = {{ parameter('departmentId') }}
    end
    and case when {{ parameter('locationId') }} is null then true
        else location_id = {{ parameter('locationId') }}
    end
-- BL-009
order by datetime desc, prescription_id, administration_due_datetime, administration_dose_index

{% endmacro %}
