select {{
    select_with_transform(
        from='translated_ds__patients', 
        except=[
            'patient_id',
            'village_id'
        ],
        update={
            translate_string('', 'Registration date'): 'date',
            translate_string('general.localisedField.dateOfBirth.label', 'Date of birth'): 'date',
        }
    )
}}
from {{ ref("translated_ds__patients") }}
where
    case
        when{{ parameter('fromDate', default_value='2024-01-01', data_type='date') }} is null then true
        else "{{ translate_string('', 'Registration date') }}" >={{ parameter('fromDate', default_value='2024-01-01', data_type='date') }}
    end
    and
    case
        when{{ parameter('toDate', default_value='2024-01-31', data_type='date') }} is null then true
        else "{{ translate_string('', 'Registration date') }}" <={{ parameter('toDate', default_value='2024-01-31', data_type='date') }}
    end
