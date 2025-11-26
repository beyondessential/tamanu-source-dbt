select
    display_id as "{{ translate_label_from_seed('patientDisplayId') }}",
    first_name as "{{ translate_label_from_seed('patientFirstName') }}",
    last_name as "{{ translate_label_from_seed('patientLastName') }}",
    to_char(date_of_birth, '{{ var("date_format") }}') as "{{ translate_label_from_seed('patientDateOfBirth') }}",
    age as "{{ translate_label_from_seed('patientAge') }}",
    sex as "{{ translate_label_from_seed('patientSex') }}",
    village as "{{ translate_label_from_seed('patientVillage') }}",
    billing_type as "{{ translate_label_from_seed('patientBillingType') }}",
    admitting_clinician as "{{ translate_label_from_seed('admittingClinician') }}",
    to_char(admission_datetime, '{{ var("datetime_format") }}') as "{{ translate_label_from_seed('admissionDateTime') }}",
    admission_status as "{{ translate_label_from_seed('admissionStatus') }}",
    to_char(discharge_datetime, '{{ var("datetime_format") }}') as "{{ translate_label_from_seed('dischargeDateTime') }}",
    facility as "{{ translate_label_from_seed('facility') }}",
    departments as "{{ translate_label_from_seed('encounterDepartmentHistory') }}",
    department_datetimes as "{{ translate_label_from_seed('encounterDepartmentHistoryDateTimes') }}",
    location_groups as "{{ translate_label_from_seed('encounterLocationGroupHistory') }}",
    location_group_datetimes as "{{ translate_label_from_seed('encounterLocationGroupHistoryDateTimes') }}",
    locations as "{{ translate_label_from_seed('encounterLocationHistory') }}",
    location_datetimes as "{{ translate_label_from_seed('encounterLocationHistoryDateTimes') }}",
    primary_diagnoses as "{{ translate_label_from_seed('diagnosesPrimary') }}",
    secondary_diagnoses as "{{ translate_label_from_seed('diagnosesSecondary') }}"
from {{ ref('ds__admissions') }}
where
    case when {{ parameter('fromDate', default_value='2024-01-01', data_type='date') }} is null then true
        else admission_datetime >= {{ parameter('fromDate', default_value='2024-01-01', data_type='date') }}
    end
    and case when {{ parameter('toDate', default_value='2024-01-31', data_type='date') }} is null then true
        else admission_datetime <= {{ parameter('toDate', default_value='2024-01-31', data_type='date') }}
    end
    and case when {{ parameter('locationGroupId') }} is null then true
        else {{ parameter('locationGroupId') }} = any(location_group_ids::text [])
    end
    and case when {{ parameter('facilityId') }} is null then true
        else {{ parameter('facilityId') }} = facility_id
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
