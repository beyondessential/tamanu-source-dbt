select
    display_id as "{{ translate_label('patientDisplayId') }}",
    first_name as "{{ translate_label('patientFirstName') }}",
    last_name as "{{ translate_label('patientLastName') }}",
    to_char(date_of_birth, '{{ var("date_format") }}') as "{{ translate_label('patientDateOfBirth') }}",
    age as "{{ translate_label('patientAge') }}",
    sex as "{{ translate_label('patientSex') }}",
    village as "{{ translate_label('patientVillage') }}",
    condition as "{{ translate_label('conditionOngoing') }}",
    to_char({{ to_user_selected_timezone('recorded_datetime') }}, '{{ var("datetime_format") }}') as "{{ translate_label('conditionRecordedDate') }}",
    clinician as "{{ translate_label('conditionRecordedBy') }}",
    to_char(date_resolved, '{{ var("date_format") }}') as "{{ translate_label('conditionResolvedDate') }}",
    clinician_resolving as "{{ translate_label('conditionResolvedBy') }}"
from {{ ref('ds__ongoing_conditions') }}
where {{ to_user_selected_timezone('recorded_datetime') }}
    >= {{ parameter('fromDate', default_value='2024-01-01', data_type='date') }}
    and
    {{ to_user_selected_timezone('recorded_datetime') }}
    <= {{ parameter('toDate', default_value='2024-01-31', data_type='date') }}
order by recorded_datetime
