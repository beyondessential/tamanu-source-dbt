select
    display_id as "{{ translate_label('patientDisplayId', 'Patient ID') }}",
    first_name as "{{ translate_label('patientFirstName', 'First name') }}",
    last_name as "{{ translate_label('patientLastName', 'Last name') }}",
    date_of_birth as "{{ translate_label('patientDateOfBirth', 'Date of birth') }}",
    age as "{{ translate_label('patientAge', 'Age') }}",
    sex as "{{ translate_label('patientSex', 'Sex') }}",
    village as "{{ translate_label('patientVillage', 'Village') }}",
    condition as "{{ translate_label('conditionOngoing', 'Ongoing condition') }}",
    recorded_datetime as "{{ translate_label('conditionRecordedDate', 'Date recorded') }}",
    clinician as "{{ translate_label('conditionRecordedBy', 'Clinician') }}",
    date_resolved as "{{ translate_label('conditionResolvedDate', 'Date resolved') }}",
    clinician_resolving as "{{ translate_label('conditionResolvedBy', 'Clinician confirming resolution') }}"
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
