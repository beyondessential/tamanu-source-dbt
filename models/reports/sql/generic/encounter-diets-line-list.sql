select
    ed.display_id as "{{ translate_label('patientDisplayId', 'Patient ID') }}",
    ed.patient_name as "{{ translate_label('patientName', 'Patient Name') }}",
    ed.age as "{{ translate_label('patientAge', 'Age') }}",
    concat_ws(', ', ed.location_group, ed.location) as "{{ translate_label('locationName', 'Location') }}",
    ed.diets as "{{ translate_label('encounterDiet', 'Diet') }}"
from {{ ref('ds__encounter_diets') }} ed
where
    case
        when {{ parameter('locationGroupId') }} is null then true
        else ed.location_group::text = {{ parameter('locationGroupId') }}
    end
    and
    case
        when {{ parameter('fromDate', default_value='2024-01-01', data_type='timestamp') }} is null then true
        else ed.start_datetime
            >= {{ parameter('fromDate', default_value='2024-01-01', data_type='timestamp') }}
    end
    and
    case
        when {{ parameter('toDate', default_value='2024-01-31', data_type='timestamp') }} is null then true
        else ed.start_datetime
            <= {{ parameter('toDate', default_value='2024-01-31', data_type='timestamp') }}
    end
order by ed.location_group, ed.location, ed.patient_name
