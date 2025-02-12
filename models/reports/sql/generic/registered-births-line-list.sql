select {{
    select_with_transform(
        from='translated_ds__births', 
        except=[
            'village_id', 
            'birth_facility_id', 
            'patient_id'
        ],
        update={
            translate_string('general.localisedField.dateOfBirth.label', 'Date of birth'): 'date'
        }
    )
}}
from {{ ref("translated_ds__births") }}
where
    case
        when {{ parameter('fromDate', default_value='2024-01-01', data_type='date') }} is null then true
        else "{{ translate_string('general.localisedField.dateOfBirth.label', 'Date of birth') }}"
            >= {{ parameter('fromDate', default_value='2024-01-01', data_type='date') }}
    end
    and
    case
        when {{ parameter('toDate', default_value='2024-01-31', data_type='date') }} is null then true
        else "{{ translate_string('general.localisedField.dateOfBirth.label', 'Date of birth') }}"
            <= {{ parameter('toDate', default_value='2024-01-31', data_type='date') }}
    end
    and
    case
        when {{ parameter('villageId') }} is null then true
        else village_id = {{ parameter('villageId') }}
    end
    and
    case
        when {{ parameter('facilityId') }} is null then true
        else birth_facility_id = {{ parameter('facilityId') }}
    end
