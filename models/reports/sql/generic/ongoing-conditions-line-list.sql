select
    display_id as "{{ translate_string('general.localisedField.displayId.label','Patient ID') }}",
    first_name as "{{ translate_string('general.localisedField.firstName.label','First name') }}",
    last_name as "{{ translate_string('general.localisedField.lastName.label','Last name') }}",
    to_char(date_of_birth, '{{ var("date_format") }}') as "{{ translate_string('general.localisedField.dateOfBirth.label', 'Date of birth') }}",
    age as "{{ translate_string('general.localisedField.Age', 'Age') }}",
    sex as "{{ translate_string('general.localisedField.sex.label', 'Sex') }}",
    village as "{{ translate_string('general.localisedField.villageId.label', 'Village') }}",
    condition as "{{ translate_string('conditions.conditionName.label', 'Ongoing condition') }}",
    recorded_datetime as "{{ translate_string('general.recordedDate.label', 'Date recorded') }}",
    clinician as "{{ translate_string('', 'Clinician') }}",
    date_resolved as "{{ translate_string('conditions.resolutionDate.label', 'Date resolved') }}",
    clinician_resolving as "{{ translate_string('patient.ongoingCondition.resolutionPractitionerId.label', 'Clinician confirming resolution') }}"
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