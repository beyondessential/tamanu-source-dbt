select
    display_id as "{{ translate_string('patientDisplayId', 'Patient ID') }}",
    first_name as "{{ translate_string('patientFirstName', 'First name') }}",
    last_name as "{{ translate_string('patientLastName', 'Last name') }}",
    date_of_birth as "{{ translate_string('patientDateOfBirth', 'Date of birth') }}",
    age as "{{ translate_string('patientAge', 'Age') }}",
    sex as "{{ translate_string('patientSex', 'Sex') }}",
    village as "{{ translate_string('patientVillage', 'Village') }}",
    condition as "{{ translate_string('conditionOngoing', 'Ongoing condition') }}",
    recorded_datetime as "{{ translate_string('conditionRecordedDate', 'Date recorded') }}",
    clinician as "{{ translate_string('conditionRecordedBy', 'Clinician') }}",
    date_resolved as "{{ translate_string('conditionResolvedDate', 'Date resolved') }}",
    clinician_resolving as "{{ translate_string('conditionResolvedBy', 'Clinician confirming resolution') }}"
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
