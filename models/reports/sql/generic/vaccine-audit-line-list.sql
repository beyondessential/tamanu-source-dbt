select {{
    select_with_transform(
        from='translated_ds__vaccinations', 
        except=[
            'patient_id',
            'village_id',
            'facility_id',
            'department_id',
            'location_group_id',
            'location_id',
            translate_string('general.localisedField.facility.label', 'Facility'),
            translate_string('general.localisedField.departmentId.label', 'Department'),
            translate_string('general.localisedField.area.label', 'Area'),
            translate_string('general.localisedField.locationId.label', 'Location'),
            translate_string('vaccine.category.label', 'Vaccine category'),
            translate_string('vaccine.batch.label', 'Batch'),
            translate_string('', 'If given elsewhere, Circumstances'),
            translate_string('', 'If given elsewhere, Country'),
            translate_string('', 'If not given, Supervising clinician'),
            translate_string('vaccine.notGivenReason.label', 'If not given, Reason not given')
        ],
        update={
            translate_string('vaccine.dateRecorded.label', 'Vaccination date'): 'date',
            translate_string('general.localisedField.dateOfBirth.label', 'Date of birth'): 'date',
            translate_string('', 'Record modification date'): 'date'
        }
    )
}}
from {{ ref("translated_ds__vaccinations") }}
where
    "{{ translate_string('general.localisedField.vaccinationStatus.label', 'Vaccine status') }}" in ('Recorded in error', 'Historical')
    and
    case
        when{{ parameter('fromDate', default_value='2024-01-01', data_type='date') }} is null then true
        else "{{ translate_string('vaccine.dateRecorded.label', 'Vaccination date') }}"
            >={{ parameter('fromDate', default_value='2024-01-01', data_type='date') }}
    end
    and
    case
        when{{ parameter('toDate', default_value='2024-01-31', data_type='date') }} is null then true
        else "{{ translate_string('vaccine.dateRecorded.label', 'Vaccination date') }}"
            <={{ parameter('toDate', default_value='2024-01-31', data_type='date') }}
    end
    and
    case
        when{{ parameter('villageId') }} is null then true
        else village_id ={{ parameter('villageId') }}
    end
    and
    case
        when{{ parameter('facilityId') }} is null then true
        else facility_id ={{ parameter('facilityId') }}
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
    and
    case
        when{{ parameter('status') }} is null then true
        else "{{ translate_string('general.localisedField.vaccinationStatus.label', 'Vaccine status') }}" ={{ parameter('status') }}
    end
