select
    to_char({{ to_user_selected_timezone('datetime') }}, '{{ var("date_format") }}') as "{{ translate_label('prescriptionDate') }}",
    display_id as "{{ translate_label('patientDisplayId') }}",
    first_name as "{{ translate_label('patientFirstName') }}",
    last_name as "{{ translate_label('patientLastName') }}",
    to_char(date_of_birth, '{{ var("date_format") }}') as "{{ translate_label('patientDateOfBirth') }}",
    age as "{{ translate_label('patientAge') }}",
    sex as "{{ translate_label('patientSex') }}",
    village as "{{ translate_label('patientVillage') }}",
    facility as "{{ translate_label('facility') }}",
    is_selected_for_discharge as "{{ translate_label('prescriptionSelectedForDischarge') }}",
    medication_code as "{{ translate_label('prescriptionMedicationCode') }}",
    medication as "{{ translate_label('prescriptionMedication') }}",
    route as "{{ translate_label('prescriptionRoute') }}",
    quantity as "{{ translate_label('prescriptionQuantity') }}",
    repeats as "{{ translate_label('prescriptionRepeats') }}",
    is_ongoing as "{{ translate_label('prescriptionIsOngoing') }}",
    is_prn as "{{ translate_label('prescriptionIsPRN') }}",
    is_variable_dose as "{{ translate_label('prescriptionIsVariableDose') }}",
    dose_amount as "{{ translate_label('prescriptionDoseAmount') }}",
    units as "{{ translate_label('prescriptionUnits') }}",
    frequency as "{{ translate_label('prescriptionFrequency') }}"
from {{ ref('ds__sensitive_encounter_prescriptions') }}
where
    case when {{ parameter('fromDate', default_value='2024-01-01', data_type='date') }} is null then true
        else {{ to_user_selected_timezone('datetime') }} >= {{ parameter('fromDate', default_value='2024-01-01', data_type='date') }}
    end
    and case when {{ parameter('toDate', default_value='2024-01-31', data_type='date') }} is null then true
        else {{ to_user_selected_timezone('datetime') }} <= {{ parameter('toDate', default_value='2024-01-31', data_type='date') }}
    end
    and case when {{ parameter('facilityId') }} is null then true
        else {{ parameter('facilityId') }} = facility_id
    end
order by datetime desc
