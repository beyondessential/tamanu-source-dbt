select
    {{ dbt_utils.star(
            from=ref('ds__births_translated'), 
            except=[
                'village_id', 
                'birth_facility_id', 
                'patient_id'
            ]
        ) 
    }}
from {{ ref("ds__births_translated") }}
where
    case
        when{{ parameter('fromDate', default_value='2024-01-01', data_type='date') }} is null then true
        else to_date(
                "{{ translate_string('general.localisedField.dateOfBirth.label', 'Date of birth') }}",
                'YYYY-MM-DD'
            )
            >={{ parameter('fromDate', default_value='2024-01-01', data_type='date') }}
    end
    and
    case
        when{{ parameter('toDate', default_value='2024-01-31', data_type='date') }} is null then true
        else to_date(
                "{{ translate_string('general.localisedField.dateOfBirth.label', 'Date of birth') }}",
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
        else birth_facility_id ={{ parameter('facilityId') }}
    end
