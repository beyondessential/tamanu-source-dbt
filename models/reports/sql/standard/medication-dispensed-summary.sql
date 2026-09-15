select
    md.medication as "{{ translate_label('encounterPrescriptionMedication') }}",
    md.medication_code as "{{ translate_label('encounterPrescriptionMedicationCode') }}",
    sum(md.quantity) as "{{ translate_label('encounterPrescriptionQuantity') }}"
from {{ ref('ds__medication_dispenses') }} md
where
    case
        when {{ parameter('facilityId') }} is null then true
        else md.facility_id = {{ parameter('facilityId') }}
    end
    and
    case
        when {{ parameter('medicationId') }} is null then true
        else md.medication_id = {{ parameter('medicationId') }}
    end
    and
    {{ to_user_selected_timezone('md.dispensed_at') }}
    >= {{ parameter('fromDate', default_value='2024-01-01', data_type='timestamp') }}
    and
    {{ to_user_selected_timezone('md.dispensed_at') }}
    <= {{ parameter('toDate', default_value='2024-01-31', data_type='timestamp') }}
group by md.medication_id, md.medication, md.medication_code
