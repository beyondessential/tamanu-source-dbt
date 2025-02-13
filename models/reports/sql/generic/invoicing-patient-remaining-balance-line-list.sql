select {{
    select_with_transform(
        from='translated_ds__invoicing', 
        except=[
            'patient_id',
            'invoice_id',
            'encounter_id',
            'status',
            'discharge_area_id',
            translate_string('','Area (at time of discharge)'),
            translate_string('discharge.admissionDate.label','Admission date'),
            translate_string('refData.patientFieldDefinition.fieldCategory-SocialSecurityNumber','Social security number'),
            translate_string('','Insurer'),
            translate_string('','Total invoice amount'),
            translate_string('','Total insurer amount'),
            translate_string('','Total patient discount') ,
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
