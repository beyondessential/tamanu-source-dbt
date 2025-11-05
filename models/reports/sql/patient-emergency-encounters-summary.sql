select
    display_id as "{{ translate_label('patientDisplayId') }}",
    first_name as "{{ translate_label('patientFirstName') }}",
    last_name as "{{ translate_label('patientLastName') }}",
    to_char(date_of_birth, '{{ var("date_format") }}') as "{{ translate_label('patientDateOfBirth') }}",
    sex as "{{ translate_label('patientSex') }}",
    village as "{{ translate_label('patientVillage') }}",
    facility as "{{ translate_label('facility') }}",
    count(*) as "{{ translate_label('triageRecordCount') }}"
from {{ ref('ds__encounters_emergency') }}
where case
        when {{ parameter('patientDisplayId') }} is null then true
        else display_id = {{ parameter('patientDisplayId') }}
    end
    and
    case
        when {{ parameter('fromDate', default_value='current_date - interval \'30 days\'', data_type='date') }} is null then true
        else arrival_datetime
            >= {{ parameter('fromDate', default_value='current_date - interval \'30 days\'', data_type='date') }}
    end
    and
    case
        when {{ parameter('toDate', default_value='current_date', data_type='date') }} is null then true
        else arrival_datetime
            <= {{ parameter('toDate', default_value='current_date', data_type='date') }}
    end
group by
    display_id,
    first_name,
    last_name,
    date_of_birth,
    sex,
    village,
    facility
order by last_name, first_name, display_id
