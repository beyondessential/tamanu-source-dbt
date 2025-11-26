select
    display_id as "{{ translate_label_from_seed('patientDisplayId') }}",
    first_name as "{{ translate_label_from_seed('patientFirstName') }}",
    last_name as "{{ translate_label_from_seed('patientLastName') }}",
    to_char(date_of_birth, '{{ var("date_format") }}') as "{{ translate_label_from_seed('patientDateOfBirth') }}",
    age as "{{ translate_label_from_seed('patientAge') }}",
    sex as "{{ translate_label_from_seed('patientSex') }}",
    ethnicity as "{{ translate_label_from_seed('patientEthnicity') }}",
    patient_billing_type as "{{ translate_label_from_seed('patientBillingType') }}",
    to_char(start_datetime, '{{ var("datetime_format") }}') as "{{ translate_label_from_seed('encounterStartDateTime') }}",
    to_char(end_datetime, '{{ var("datetime_format") }}') as "{{ translate_label_from_seed('encounterEndDateTime') }}",
    length_of_stay as "{{ translate_label_from_seed('encounterLengthOfStay') }}",
    facility as "{{ translate_label_from_seed('facility') }}",
    encounter_type_emergency as "{{ translate_label_from_seed('encounterTypeEmergency') }}",
    encounter_type_inpatient as "{{ translate_label_from_seed('encounterTypeInpatient') }}",
    encounter_type_outpatient as "{{ translate_label_from_seed('encounterTypeOutpatient') }}",
    discharge_disposition as "{{ translate_label_from_seed('dischargeDisposition') }}",
    triage_score as "{{ translate_label_from_seed('triageCategory') }}",
    arrival_mode as "{{ translate_label_from_seed('triageArrivalMode') }}",
    triage_wait_time as "{{ translate_label_from_seed('triageWaitingTime') }}",
    encountering_clinician as "{{ translate_label_from_seed('encounterClinician') }}",
    supervising_clinician as "{{ translate_label_from_seed('encounterSupervisingClinician') }}",
    discharging_department as "{{ translate_label_from_seed('dischargeDepartment') }}",
    time_assigned_to_discharging_department as "{{ translate_label_from_seed('dischargeDateTime') }} of {{ translate_label_from_seed('dischargeDepartment') }}",
    discharging_location_group as "{{ translate_label_from_seed('dischargeLocationGroup') }}",
    time_assigned_to_discharging_location_group as "{{ translate_label_from_seed('dischargeDateTime') }} of {{ translate_label_from_seed('dischargeLocationGroup') }}",
    discharging_location as "{{ translate_label_from_seed('dischargeLocation') }}",
    time_assigned_to_discharging_location as "{{ translate_label_from_seed('dischargeDateTime') }} of {{ translate_label_from_seed('dischargeLocation') }}",
    departments as "{{ translate_label_from_seed('encounterDepartmentHistory') }}",
    department_datetimes as "{{ translate_label_from_seed('encounterDepartmentHistoryDateTimes') }}",
    location_groups as "{{ translate_label_from_seed('encounterLocationGroupHistory') }}",
    location_group_datetimes as "{{ translate_label_from_seed('encounterLocationGroupHistoryDateTimes') }}",
    locations as "{{ translate_label_from_seed('encounterLocationHistory') }}",
    location_datetimes as "{{ translate_label_from_seed('encounterLocationHistoryDateTimes') }}",
    reason_for_encounter as "{{ translate_label_from_seed('encounterReasonForEncounter') }}",
    diagnoses as "{{ translate_label_from_seed('diagnoses') }}",
    medications as "{{ translate_label_from_seed('medications') }}",
    vaccinations as "{{ translate_label_from_seed('vaccinations') }}",
    procedures as "{{ translate_label_from_seed('procedures') }}",
    lab_requests as "{{ translate_label_from_seed('labRequests') }}",
    imaging_requests as "{{ translate_label_from_seed('imagingRequests') }}",
    notes as "{{ translate_label_from_seed('notes') }}"
from {{ ref('ds__sensitive_encounter_summary') }}
where case when {{ parameter('fromDate', default_value='2024-01-01', data_type='date') }} is null then true
        else end_datetime >= {{ parameter('fromDate', default_value='2024-01-01', data_type='date') }}
    end
    and case when {{ parameter('toDate', default_value='2024-01-31', data_type='date') }} is null then true
        else end_datetime <= {{ parameter('toDate', default_value='2024-01-31', data_type='date') }}
    end
    and case when {{ parameter('facilityId') }} is null then true
        else facility_id = {{ parameter('facilityId') }}
    end
    and case when {{ parameter('departmentId') }} is null then true
        else {{ parameter('departmentId') }} = any(department_ids::text [])
    end
    and case when {{ parameter('locationGroupId') }} is null then true
        else {{ parameter('locationGroupId') }} = any(location_group_ids::text [])
    end
    and case when {{ parameter('patientBillingTypeId') }} is null then true
        else patient_billing_type_id = {{ parameter('patientBillingTypeId') }}
    end
    and case when {{ parameter('supervisingClinicianId') }} is null then true
        else supervising_clinician_id = {{ parameter('supervisingClinicianId') }}
    end
order by end_datetime desc
