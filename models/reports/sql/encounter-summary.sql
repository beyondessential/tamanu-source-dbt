select
    display_id as "{{ translate_label('patientDisplayId', 'Patient ID') }}",
    first_name as "{{ translate_label('patientFirstName', 'First name') }}",
    last_name as "{{ translate_label('patientLastName', 'Last name') }}",
    date_of_birth as "{{ translate_label('patientDateOfBirth', 'Date of birth') }}",
    age as "{{ translate_label('patientAge', 'Age') }}",
    sex as "{{ translate_label('patientSex', 'Sex') }}",
    ethnicity as "{{ translate_label('patientEthnicity', 'Ethnicity') }}",
    patient_billing_type as "{{ translate_label('patientBillingType', 'Billing type') }}",
    start_datetime as "{{ translate_label('encounterStartDateTime', 'Encounter start date and time') }}",
    end_datetime as "{{ translate_label('encounterEndDateTime', 'Encounter end date and time') }}",
    length_of_stay as "{{ translate_label('encounterLengthOfStay', 'Length of stay (days)') }}",
    facility as "{{ translate_label('facility', 'Facility') }}",
    encounter_type_emergency as "{{ translate_label('encounterTypeEmergency', 'Emergency encounter') }}",
    encounter_type_inpatient as "{{ translate_label('encounterTypeInpatient', 'Inpatient encounter') }}",
    encounter_type_outpatient as "{{ translate_label('encounterTypeOutpatient', 'Outpatient encounter') }}",
    discharge_disposition as "{{ translate_label('dischargeDisposition', 'Discharge disposition') }}",
    triage_score as "{{ translate_label('triageCategory', 'Triage category') }}",
    arrival_mode as "{{ translate_label('triageArrivalMode', 'Arrival mode') }}",
    triage_wait_time as "{{ translate_label('triageWaitTime', 'Time seen following triage/Wait time (hh:mm:ss)') }}",
    encountering_clinician as "{{ translate_label('encounterEncounteringClinician', 'Encountering clinician') }}",
    supervising_clinician as "{{ translate_label('encounterSupervisingClinician', 'Supervising clinician') }}",
    discharging_department as "{{ translate_label('dischargeDischargingDepartment', 'Discharging department') }}",
    time_assigned_to_discharging_department as "{{ translate_label('dischargeTimeAssignedToDischargingDepartment', 'Time assigned to discharging department') }}",
    discharging_location_group as "{{ translate_label('dischargeDischargingLocationGroup', 'Discharging area') }}",
    time_assigned_to_discharging_location_group as "{{ translate_label('dischargeTimeAssignedToDischargingArea', 'Time assigned to discharging area') }}",
    discharging_location as "{{ translate_label('dischargeDischargingLocation', 'Discharging location') }}",
    time_assigned_to_discharging_location as "{{ translate_label('dischargeTimeAssignedToDischargingLocation', 'Time assigned to discharging location') }}",
    departments as "{{ translate_label('encounterDepartmentHistory', 'Department history') }}",
    department_datetimes as "{{ translate_label('encounterDepartmentHistoryDatetimes', 'Department date & time history') }}",
    location_groups as "{{ translate_label('encounterLocationGroupHistory', 'Area history') }}",
    location_group_datetimes as "{{ translate_label('encounterLocationGroupHistoryDatetimes', 'Area date & time history') }}",
    locations as "{{ translate_label('encounterLocationHistory', 'Location history') }}",
    location_datetimes as "{{ translate_label('encounterLocationHistoryDatetimes', 'Location date & time history') }}",
    reason_for_encounter as "{{ translate_label('encounterReasonForEncounter', 'Reason for encounter') }}",
    diagnoses as "{{ translate_label('encounterDiagnoses', 'Diagnoses') }}",
    medications as "{{ translate_label('encounterMedications', 'Medications') }}",
    vaccinations as "{{ translate_label('encounterVaccinations', 'Vaccinations') }}",
    procedures as "{{ translate_label('encounterProcedures', 'Procedures') }}",
    lab_requests as "{{ translate_label('encounterLabRequests', 'Lab requests') }}",
    imaging_requests as "{{ translate_label('encounterImagingRequests', 'Imaging requests') }}",
    notes as "{{ translate_label('encounterNotes', 'Notes') }}"
from {{ ref('ds__encounter_summary') }}
where case when {{ parameter('fromDate', default_value='2024-01-01', data_type='date') }} is null then true
        else end_datetime >= {{ parameter('fromDate', default_value='2024-01-01', data_type='date') }}
    end
    and case when {{ parameter('toDate', default_value='2024-01-31', data_type='date') }} is null then true
        else end_datetime <= {{ parameter('toDate', default_value='2024-01-31', data_type='date') }}
    end
    and case when {{ parameter('facilityId') }} is null then true
        else facility_id::text = {{ parameter('facilityId') }}
    end
    and case when {{ parameter('departmentId') }} is null then true
        else {{ parameter('departmentId') }} = any(department_ids::text[])
    end
    and case when {{ parameter('locationGroupId') }} is null then true
        else {{ parameter('locationGroupId') }} = any(location_group_ids::text[])
    end
    and case when {{ parameter('patientBillingTypeId') }} is null then true
        else patient_billing_type = {{ parameter('patientBillingTypeId') }}
    end
    and case when {{ parameter('supervisingClinicianId') }} is null then true
        else supervising_clinician_id = {{ parameter('supervisingClinicianId') }}
    end