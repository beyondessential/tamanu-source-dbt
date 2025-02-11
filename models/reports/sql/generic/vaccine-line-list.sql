{% set excluded_columns = [
    'patient_id',
    'village_id',
    'facility_id',
    'department_id',
    'location_group_id',
    'location_id',
    translate_string('', 'Record modified by'),
    translate_string('', 'Record modification date')
] %}

select
    {{ dbt_utils.star(
            from=ref('ds__vaccinations_translated'), 
            except=excluded_columns
        )
    }}
from {{ ref("ds__vaccinations_translated") }}
where
    "{{ translate_string('general.localisedField.vaccinationStatus.label', 'Vaccine status') }}" in ('Given', 'Not Given')
    and
    case
        when{{ parameter('fromDate', default_value='2024-01-01', data_type='date') }} is null then true
        else to_date(
                "{{ translate_string('vaccine.dateRecorded.label', 'Vaccination date') }}",
                'YYYY-MM-DD'
            )
            >={{ parameter('fromDate', default_value='2024-01-01', data_type='date') }}
    end
    and
    case
        when{{ parameter('toDate', default_value='2024-01-31', data_type='date') }} is null then true
        else to_date(
                "{{ translate_string('vaccine.dateRecorded.label', 'Vaccination date') }}",
                'YYYY-MM-DD'
            )
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
        when{{ parameter('category') }} is null then true
        else "{{ translate_string('vaccine.vaccineName.label', 'Vaccine name') }}" ={{ parameter('vaccine') }}
    end
