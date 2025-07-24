select
    ed.display_id as "{{ translate_label('patientDisplayId') }}",
    ed.patient_name as "{{ translate_label('patientName') }}",
    ed.age as "{{ translate_label('patientAge') }}",
    concat_ws(', ', ed.location_group, ed.location) as "{{ translate_label('location') }}",
    ed.diets as "{{ translate_label('encounterDiet') }}"
from {{ ref('ds__encounter_diets') }} ed
where
    case
        when {{ parameter('locationGroupId') }} is null then true
        else ed.location_group_id = {{ parameter('locationGroupId') }}
    end
    and
    case
        when {{ parameter('fromDate', default_value='2024-01-01', data_type='date') }} is null then true
        else ed.start_datetime
            >= {{ parameter('fromDate', default_value='2024-01-01', data_type='date') }}
    end
    and
    case
        when {{ parameter('toDate', default_value='2024-01-31', data_type='date') }} is null then true
        else ed.start_datetime
            <= {{ parameter('toDate', default_value='2024-01-31', data_type='date') }}
    end
order by ed.location_group, ed.location, ed.patient_name
