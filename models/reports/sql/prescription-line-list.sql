select
    to_char(datetime, '{{ var("date_format") }}') as "{{ translate_label_from_seed('prescriptionDate') }}",
    display_id as "{{ translate_label_from_seed('patientDisplayId') }}",
    first_name as "{{ translate_label_from_seed('patientFirstName') }}",
    last_name as "{{ translate_label_from_seed('patientLastName') }}",
    to_char(date_of_birth, '{{ var("date_format") }}') as "{{ translate_label_from_seed('patientDateOfBirth') }}",
    age as "{{ translate_label_from_seed('patientAge') }}",
    sex as "{{ translate_label_from_seed('patientSex') }}",
    village as "{{ translate_label_from_seed('patientVillage') }}",
    facility as "{{ translate_label_from_seed('facility') }}",
    is_selected_for_discharge as "{{ translate_label_from_seed('prescriptionSelectedForDischarge')}}",
    medication_code as "{{ translate_label_from_seed('prescriptionMedicationCode') }}",
    medication as "{{ translate_label_from_seed('prescriptionMedication') }}",
    route as "{{ translate_label_from_seed('prescriptionRoute') }}",
    quantity as "{{ translate_label_from_seed('prescriptionQuantity') }}",
    repeats as "{{ translate_label_from_seed('prescriptionRepeats') }}",
    is_ongoing as "{{ translate_label_from_seed('prescriptionIsOngoing') }}",
    is_prn as "{{ translate_label_from_seed('prescriptionIsPRN') }}",
    is_variable_dose as "{{ translate_label_from_seed('prescriptionIsVariableDose') }}",
    dose_amount as "{{ translate_label_from_seed('prescriptionDoseAmount') }}",
    units as "{{ translate_label_from_seed('prescriptionUnits') }}",
    frequency as "{{ translate_label_from_seed('prescriptionFrequency') }}"
from {{ ref('ds__encounter_prescriptions') }}
where
    case when {{ parameter('fromDate', default_value='2024-01-01', data_type='date') }} is null then true
        else datetime >= {{ parameter('fromDate', default_value='2024-01-01', data_type='date') }}
    end
    and case when {{ parameter('toDate', default_value='2024-01-31', data_type='date') }} is null then true
        else datetime <= {{ parameter('toDate', default_value='2024-01-31', data_type='date') }}
    end
    and case when {{ parameter('facilityId') }} is null then true
        else {{ parameter('facilityId') }} = facility_id
    end
order by datetime desc
