select
    display_id as "{{ translate_label_from_seed('patientDisplayId') }}",
    first_name as "{{ translate_label_from_seed('patientFirstName') }}",
    last_name as "{{ translate_label_from_seed('patientLastName') }}",
    to_char(date_of_birth, '{{ var("date_format") }}') as "{{ translate_label_from_seed('patientDateOfBirth') }}",
    sex as "{{ translate_label_from_seed('patientSex') }}",
    village as "{{ translate_label_from_seed('patientVillage') }}",
    facility as "{{ translate_label_from_seed('facility') }}",
    count(*) as "{{ translate_label_from_seed('triageRecordCount') }}"
from {{ ref('ds__encounters_emergency') }}
where case
        when {{ parameter('patientId') }} is null then true
        else patient_id = {{ parameter('patientId') }}
    end
    and
    case
        when {{ parameter('fromDate', default_value='2025-01-01', data_type='date') }} is null then true
        else triage_datetime >= {{ parameter('fromDate', default_value='2025-01-01', data_type='date') }}
    end
    and
    case
        when {{ parameter('toDate', default_value='2025-01-31', data_type='date') }} is null then true
        else triage_datetime <= {{ parameter('toDate', default_value='2025-01-31', data_type='date') }}
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
