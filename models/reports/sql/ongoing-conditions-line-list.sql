select
    display_id as "{{ translate_label('patientDisplayId') }}",
    first_name as "{{ translate_label('patientFirstName') }}",
    last_name as "{{ translate_label('patientLastName') }}",
    date_of_birth as "{{ translate_label('patientDateOfBirth') }}",
    age as "{{ translate_label('patientAge') }}",
    sex as "{{ translate_label('patientSex') }}",
    village as "{{ translate_label('patientVillage') }}",
    condition as "{{ translate_label('conditionOngoing') }}",
    recorded_datetime as "{{ translate_label('conditionRecordedDate') }}",
    clinician as "{{ translate_label('conditionRecordedBy') }}",
    date_resolved as "{{ translate_label('conditionResolvedDate') }}",
    clinician_resolving as "{{ translate_label('conditionResolvedBy') }}"
from {{ ref('ds__ongoing_conditions') }}
where case
        when {{ parameter('fromDate', default_value='2024-01-01', data_type='date') }} is null then true
        else recorded_datetime::date
            >= {{ parameter('fromDate', default_value='2024-01-01', data_type='date') }}
    end
    and
    case
        when {{ parameter('toDate', default_value='2024-01-31', data_type='date') }} is null then true
        else recorded_datetime::date
            <= {{ parameter('toDate', default_value='2024-01-31', data_type='date') }}
    end
order by recorded_datetime