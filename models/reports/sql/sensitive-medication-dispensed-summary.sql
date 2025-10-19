select 
    ep.medication as "{{ translate_label('prescriptionMedication')}}",
    ep.medication_code as "{{ translate_label('prescriptionMedicationCode')}}",
    sum(ep.quantity) as "{{ translate_label('prescriptionQuantity')}}"
from {{ ref('ds__sensitive_encounter_prescriptions') }} ep
where is_selected_for_discharge = true
    and
    case
        when {{ parameter('facilityId') }} is null then true
        else ep.facility_id = {{ parameter('facilityId') }}
    end
    and
    case
        when {{ parameter('medicationId') }} is null then true
        else ep.medication_id = {{ parameter('medicationId') }}
    end 
    and
    case
        when {{ parameter('fromDate', default_value='2024-01-01', data_type='timestamp') }} is null then true
        else ep.datetime
            >= {{ parameter('fromDate', default_value='2024-01-01', data_type='timestamp') }}
    end
    and
    case
        when {{ parameter('toDate', default_value='2024-01-31', data_type='timestamp') }} is null then true
        else ep.datetime
            <= {{ parameter('toDate', default_value='2024-01-31', data_type='timestamp') }}
    end
group by ep.medication_id, ep.medication, ep.medication_code