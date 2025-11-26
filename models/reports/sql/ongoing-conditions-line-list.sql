select
    display_id as "{{ translate_label_from_seed('patientDisplayId') }}",
    first_name as "{{ translate_label_from_seed('patientFirstName') }}",
    last_name as "{{ translate_label_from_seed('patientLastName') }}",
    to_char(date_of_birth, '{{ var("date_format") }}') as "{{ translate_label_from_seed('patientDateOfBirth') }}",
    age as "{{ translate_label_from_seed('patientAge') }}",
    sex as "{{ translate_label_from_seed('patientSex') }}",
    village as "{{ translate_label_from_seed('patientVillage') }}",
    condition as "{{ translate_label_from_seed('conditionOngoing') }}",
    to_char(recorded_datetime, '{{ var("datetime_format") }}') as "{{ translate_label_from_seed('conditionRecordedDate') }}",
    clinician as "{{ translate_label_from_seed('conditionRecordedBy') }}",
    to_char(date_resolved, '{{ var("date_format") }}') as "{{ translate_label_from_seed('conditionResolvedDate') }}",
    clinician_resolving as "{{ translate_label_from_seed('conditionResolvedBy') }}"
from {{ ref('ds__ongoing_conditions') }}
where case
        when {{ parameter('fromDate', default_value='2024-01-01', data_type='date') }} is null then true
        else recorded_datetime
            >= {{ parameter('fromDate', default_value='2024-01-01', data_type='date') }}
    end
    and
    case
        when {{ parameter('toDate', default_value='2024-01-31', data_type='date') }} is null then true
        else recorded_datetime
            <= {{ parameter('toDate', default_value='2024-01-31', data_type='date') }}
    end
order by recorded_datetime
