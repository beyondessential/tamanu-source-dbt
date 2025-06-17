select
    display_id as "{{ translate_label('patientDisplayId', 'Patient ID') }}",
    first_name as "{{ translate_label('patientFirstName', 'First name') }}",
    last_name as "{{ translate_label('patientLastName', 'Last name') }}",
    date_of_birth as "{{ translate_label('patientDateOfBirth', 'Date of birth') }}",
    age as "{{ translate_label('patientAge', 'Age') }}",
    sex as "{{ translate_label('patientSex', 'Sex') }}",
    village as "{{ translate_label('patientVillage', 'Village') }}",
    billing_type as "{{ translate_label('patientBillingType', 'Billing type') }}",
    admitting_clinician as "{{ translate_label('admittingClinician', 'Admitting clinician') }}",
    admission_datetime as "{{ translate_label('admissionDateTime', 'Admission date and time') }}",
    admission_status as "{{ translate_label('admissionStatus', 'Admission status') }}",
    discharge_datetime as "{{ translate_label('dischargeDateTime', 'Discharge date and time') }}",
    facility as "{{ translate_label('facilityName', 'Facility') }}",
    departments as "{{ translate_label('departmentNames', 'Departments') }}",
    department_datetimes as "{{ translate_label('departmentChangeDateTimes', 'Department change date and times') }}",
    location_groups as "{{ translate_label('locationGroupNames', 'Location groups') }}",
    location_group_datetimes as "{{ translate_label('locationGroupChangeDateTimes', 'Location group change date and times') }}",
    locations as "{{ translate_label('locationNames', 'Locations') }}",
    location_datetimes as "{{ translate_label('locationChangeDateTimes', 'Location change date and times') }}",
    primary_diagnoses as "{{ translate_label('diagnosesPrimary', 'Primary diagnoses') }}",
    secondary_diagnoses as "{{ translate_label('diagnosesSecondary', 'Secondary diagnoses') }}"
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
