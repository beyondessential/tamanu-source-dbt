select
    display_id as "{{ translate_label('patientDisplayId') }}",
    first_name as "{{ translate_label('patientFirstName') }}",
    last_name as "{{ translate_label('patientLastName') }}",
    date_of_birth as "{{ translate_label('patientDateOfBirth') }}",
    age as "{{ translate_label('patientAge') }}",
    sex as "{{ translate_label('patientSex') }}",
    village as "{{ translate_label('patientVillage') }}",
    billing_type as "{{ translate_label('patientBillingType') }}",
    admitting_clinician as "{{ translate_label('admittingClinician') }}",
    admission_datetime as "{{ translate_label('admissionDateTime') }}",
    admission_status as "{{ translate_label('admissionStatus') }}",
    discharge_datetime as "{{ translate_label('dischargeDateTime') }}",
    facility as "{{ translate_label('facility') }}",
    departments as "{{ translate_label('departments') }}",
    department_datetimes as "{{ translate_label('encounterDepartmentHistoryDateTimes') }}",
    location_groups as "{{ translate_label('locationGroups') }}",
    location_group_datetimes as "{{ translate_label('encounterLocationGroupHistoryDateTimes') }}",
    locations as "{{ translate_label('locations') }}",
    location_datetimes as "{{ translate_label('encounterLocationHistoryDateTimes') }}",
    primary_diagnoses as "{{ translate_label('diagnosesPrimary') }}",
    secondary_diagnoses as "{{ translate_label('diagnosesSecondary') }}"
from {{ ref('ds__admissions') }}
where
    case when {{ parameter('fromDate', default_value='2024-01-01', data_type='text') }} is null then true
        else admission_datetime::text >= {{ parameter('fromDate', default_value='2024-01-01', data_type='text') }}
    end
    and case when {{ parameter('toDate', default_value='2024-01-31', data_type='text') }} is null then true
        else admission_datetime::text <= {{ parameter('toDate', default_value='2024-01-31', data_type='text') }}
    end
    and case when {{ parameter('locationGroupId') }} is null then true
        else {{ parameter('locationGroupId') }} = any(location_group_ids::text [])
    end
    and case when {{ parameter('facilityId') }} is null then true
        else {{ parameter('facilityId') }} = facility_id::text
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
