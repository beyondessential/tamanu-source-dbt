select {{
    select_with_transform(
        from='translated_ds__invoicing', 
        except=[
            'patient_id',
            'invoice_id',
            'encounter_id',
            'status',
            'discharge_area_id',
            translate_string('discharge.admissionDate.label','Admission date'),
            translate_string('general.localisedField.displayId.label','Patient ID'),
            translate_string('refData.patientFieldDefinition.fieldCategory-SocialSecurityNumber','Social security number'),
            translate_string('general.localisedField.nationalityId.label','Nationality'),
            translate_string('','Insurer'),
            translate_string('','Remaining balance (patient)'),
            translate_string('','Deceased/Active'),
            translate_string('','Date deceased'),
        ],
        update={
            translate_string('discharge.dischargeDate.label','Discharged date'): 'date',
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
