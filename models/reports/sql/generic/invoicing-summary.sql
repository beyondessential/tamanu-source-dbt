select {{
    select_with_transform(
        from='translated_ds__invoicing', 
        except=[
            'patient_id',
            'invoice_id',
            'encounter_id',
            'status',
            'discharge_area_id',
            'discharge_area'
        ],
        update={
            translate_string('discharge.admissionDate.label','Admission date'): 'date',
            translate_string('discharge.dischargeDate.label','Discharged date'): 'date',
            translate_string('','Date deceased'): 'date',
        }
    )
}} 
from {{ ref("translated_ds__invoicing") }}
where status = 'finalised'
    and case
        when {{ parameter('fromDate', default_value='2024-01-01', data_type='date') }} is null then true
        else "{{ translate_string('discharge.dischargeDate.label','Discharged date') }}"
            >= {{ parameter('fromDate', default_value='2024-01-01', data_type='date') }}
    end
    and
    case
        when {{ parameter('toDate', default_value='2024-01-31', data_type='date') }} is null then true
        else "{{ translate_string('discharge.dischargeDate.label','Discharged date') }}"
            <= {{ parameter('toDate', default_value='2024-01-31', data_type='date') }}
    end
