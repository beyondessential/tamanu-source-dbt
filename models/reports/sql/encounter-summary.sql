select
    display_id as "{{ translate_label('patientDisplayId') }}",
    first_name as "{{ translate_label('patientFirstName') }}",
    last_name as "{{ translate_label('patientLastName') }}",
    to_char(date_of_birth, '{{ var("date_format") }}') as "{{ translate_label('patientDateOfBirth') }}",
    age as "{{ translate_label('patientAge') }}",
    sex as "{{ translate_label('patientSex') }}",
    ethnicity as "{{ translate_label('patientEthnicity') }}",
    patient_billing_type as "{{ translate_label('patientBillingType') }}",
    to_char(start_datetime, '{{ var("datetime_format") }}') as "{{ translate_label('encounterStartDateTime') }}",
    to_char(end_datetime, '{{ var("datetime_format") }}') as "{{ translate_label('encounterEndDateTime') }}",
    length_of_stay as "{{ translate_label('encounterLengthOfStay') }}",
    facility as "{{ translate_label('facility') }}",
    encounter_type_emergency as "{{ translate_label('encounterTypeEmergency') }}",
    encounter_type_inpatient as "{{ translate_label('encounterTypeInpatient') }}",
    encounter_type_outpatient as "{{ translate_label('encounterTypeOutpatient') }}",
    discharge_disposition as "{{ translate_label('dischargeDisposition') }}",
    triage_score as "{{ translate_label('triageCategory') }}",
    arrival_mode as "{{ translate_label('triageArrivalMode') }}",
    triage_wait_time as "{{ translate_label('triageWaitingTime') }}",
    encountering_clinician as "{{ translate_label('encounterClinician') }}",
    supervising_clinician as "{{ translate_label('encounterSupervisingClinician') }}",
    discharging_department as "{{ translate_label('dischargeDepartment') }}",
    time_assigned_to_discharging_department as "{{ translate_label('dischargeDateTime') }} of {{ translate_label('dischargeDepartment') }}",
    discharging_location_group as "{{ translate_label('dischargeLocationGroup') }}",
    time_assigned_to_discharging_location_group as "{{ translate_label('dischargeDateTime') }} of {{ translate_label('dischargeLocationGroup') }}",
    discharging_location as "{{ translate_label('dischargeLocation') }}",
    time_assigned_to_discharging_location as "{{ translate_label('dischargeDateTime') }} of {{ translate_label('dischargeLocation') }}",
    departments as "{{ translate_label('encounterDepartmentHistory') }}",
    department_datetimes as "{{ translate_label('encounterDepartmentHistoryDateTimes') }}",
    location_groups as "{{ translate_label('encounterLocationGroupHistory') }}",
    location_group_datetimes as "{{ translate_label('encounterLocationGroupHistoryDateTimes') }}",
    locations as "{{ translate_label('encounterLocationHistory') }}",
    location_datetimes as "{{ translate_label('encounterLocationHistoryDateTimes') }}",
    reason_for_encounter as "{{ translate_label('encounterReasonForEncounter') }}",
    diagnoses as "{{ translate_label('diagnoses') }}",
    medications as "{{ translate_label('medications') }}",
    vaccinations as "{{ translate_label('vaccinations') }}",
    procedures as "{{ translate_label('procedures') }}",
    lab_requests as "{{ translate_label('labRequests') }}",
    imaging_requests as "{{ translate_label('imagingRequests') }}",
    notes as "{{ translate_label('notes') }}"
from {{ ref('ds__encounter_summary') }}
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
