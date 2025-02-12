select {{
    select_with_transform(
        from='translated_ds__vaccinations_upcoming', 
        except=[
            'patient_id',
            'vaccine_schedules_id',
            translate_string('vaccine.category.label', 'Vaccine category')
        ],
        update={
            translate_string('', 'Vaccination due date'): 'date',
            translate_string('general.localisedField.dateOfBirth.label', 'Date of birth'): 'date'
        }
    )
}}
from {{ ref("translated_ds__vaccinations_upcoming") }}
where
    case
        when{{ parameter('fromDate', default_value='2024-01-01', data_type='date') }} is null then true
        else "{{ translate_string('general.localisedField.dateOfBirth.label', 'Date of birth') }}"
            >={{ parameter('fromDate', default_value='2024-01-01', data_type='date') }}
    end
    and
    case
        when{{ parameter('toDate', default_value='2024-01-31', data_type='date') }} is null then true
        else "{{ translate_string('general.localisedField.dateOfBirth.label', 'Date of birth') }}"
            <={{ parameter('toDate', default_value='2024-01-31', data_type='date') }}
    end
    and
    case
        when{{ parameter('status') }} is null then true
        else "{{ translate_string('general.localisedField.vaccinationStatus.label', 'Vaccine status') }}" ={{ parameter('status') }}
    end
    and
    case
        when{{ parameter('category') }} is null then true
        else "{{ translate_string('vaccine.category.label', 'Vaccine category') }}" ={{ parameter('category') }}
    end
    and
    case
        when{{ parameter('vaccine') }} is null then true
        else "{{ translate_string('vaccine.vaccineName.label', 'Vaccine name') }}" ={{ parameter('vaccine') }}
    end
