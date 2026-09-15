{% macro admissions_line_list_report(is_sensitive=false) %}

{% set dataset = 'ds__sensitive_admissions' if is_sensitive else 'ds__admissions' %}

select
    display_id as "{{ translate_label('patientDisplayId') }}",
    first_name as "{{ translate_label('patientFirstName') }}",
    last_name as "{{ translate_label('patientLastName') }}",
    to_char(date_of_birth, '{{ var("date_format") }}') as "{{ translate_label('patientDateOfBirth') }}",
    age as "{{ translate_label('patientAge') }}",
    sex as "{{ translate_label('patientSex') }}",
    village as "{{ translate_label('patientVillage') }}",
    billing_type as "{{ translate_label('patientBillingType') }}",
    admitting_clinician as "{{ translate_label('admittingClinician') }}",
    to_char({{ to_user_selected_timezone('admission_datetime') }}, '{{ var("datetime_format") }}') as "{{ translate_label('admissionDateTime') }}",
    admission_status as "{{ translate_label('admissionStatus') }}",
    to_char({{ to_user_selected_timezone('discharge_datetime') }}, '{{ var("datetime_format") }}') as "{{ translate_label('dischargeDateTime') }}",
    facility as "{{ translate_label('facility') }}",
    departments as "{{ translate_label('encounterDepartmentHistory') }}",
    department_datetimes as "{{ translate_label('encounterDepartmentHistoryDateTimes') }}",
    location_groups as "{{ translate_label('encounterLocationGroupHistory') }}",
    location_group_datetimes as "{{ translate_label('encounterLocationGroupHistoryDateTimes') }}",
    locations as "{{ translate_label('encounterLocationHistory') }}",
    location_datetimes as "{{ translate_label('encounterLocationHistoryDateTimes') }}",
    primary_diagnoses as "{{ translate_label('diagnosesPrimary') }}",
    primary_diagnoses_codes as "{{ translate_label('diagnosesPrimaryCodes') }}",
    secondary_diagnoses as "{{ translate_label('diagnosesSecondary') }}",
    secondary_diagnoses_codes as "{{ translate_label('diagnosesSecondaryCodes') }}"
from {{ ref(dataset) }}
where
    {{ to_user_selected_timezone('admission_datetime') }} >= {{ parameter('fromDate', default_value='2024-01-01', data_type='date') }}
    and {{ to_user_selected_timezone('admission_datetime') }} <= {{ parameter('toDate', default_value='2024-01-31', data_type='date') }}
    and case when {{ parameter('locationGroupId') }} is null then true
        else {{ parameter('locationGroupId') }} = any(location_group_ids::text [])
    end
    and case when {{ parameter('facilityId') }} is null then true
        else facility_id = {{ parameter('facilityId') }}
    end
    and case when {{ parameter('departmentId') }} is null then true
        else {{ parameter('departmentId') }} = any(department_ids::text [])
    end
    and case when {{ parameter('patientBillingTypeId') }} is null then true
        else billing_type_id like {{ parameter('patientBillingTypeId') }}
    end
    and case when {{ parameter('clinicianId') }} is null then true
        else admitting_clinician_id = {{ parameter('clinicianId') }}
    end
    and case when coalesce({{ parameter('admissionStatus') }}) is null then true
        else admission_status in ({{ parameter('admissionStatus') }})
    end
order by admission_datetime desc

{% endmacro %}
