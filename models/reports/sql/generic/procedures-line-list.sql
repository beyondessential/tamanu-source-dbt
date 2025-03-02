select
    display_id as "{{ translate_string('general.localisedField.displayId.label', 'Patient ID') }}",
    first_name as "{{ translate_string('general.localisedField.firstName.label', 'First name') }}",
    last_name as "{{ translate_string('general.localisedField.lastName.label', 'Last name') }}",
    to_char(date_of_birth, '{{ var("date_format") }}') as "{{ translate_string('general.localisedField.dateOfBirth.label', 'Date of birth') }}",
    age as "{{ translate_string('general.localisedField.Age', 'Age') }}",
    sex as "{{ translate_string('general.localisedField.sex.label', 'Sex') }}",
    nationality as "{{ translate_string('general.localisedField.nationalityId.label','Nationality') }}",
    encounter_facility as "{{ translate_string('', 'Encounter facility') }}",
    encounter_department as "{{ translate_string('', 'Encounter department') }}",
    encounter_type as "{{ translate_string('', 'Encounter type') }}",
    to_char(encounter_start_datetime, '{{ var("datetime_format") }}') as "{{ translate_string('', 'Encounter start date') }}",
    to_char(encounter_end_datetime, '{{ var("datetime_format") }}') as "{{ translate_string('', 'Encounter end date') }}",
    procedure_facility as "{{ translate_string('', 'Procedure facility') }}",
    procedure_area as "{{ translate_string('', 'Procedure area') }}",
    procedure_location as "{{ translate_string('', 'Procedure location') }}",
    procedure_type as "{{ translate_string('procedure.table.column.name', 'Procedure') }}",
    to_char(procdure_start_time, '{{ var("datetime_format") }}') as "{{ translate_string('', 'Procedure start (date and time)') }}",
    to_char(procedure_end_time, '{{ var("datetime_format") }}') as "{{ translate_string('', 'Procedure end (date and time)') }}",
    procedure_duration as "{{ translate_string('', 'Procedure duration') }}",
    procedure_clinician as "{{ translate_string('general.localisedField.clinician.label', 'Procedure Clinician') }}",
    procedure_anaesthetist as "{{ translate_string('', 'Procedure Anaesthetist') }}",
    procdeure_assistant as "{{ translate_string('', 'Procedure Assistant') }}",
    is_completed as "{{ translate_string('', 'Procedure marked as completed') }}"
from {{ ref('ds__procedures') }}
where case
        when {{ parameter('facilityId') }} is null then true
        else procedure_facility_id ={{ parameter('facilityId') }}
    end
    and
    case
        when {{ parameter('departmentId') }} is null then true
        else encounter_department_id ={{ parameter('departmentId') }}
    end
    and
    case
        when {{ parameter('locationGroupId') }} is null then true
        else procedure_area_id ={{ parameter('locationGroupId') }}
    end
    and
    case
        when {{ parameter('locationId') }} is null then true
        else procedure_location_id ={{ parameter('locationId') }}
    end
    and
    case
        when {{ parameter('clinicianId') }} is null then true
        else procedure_clinician_id ={{ parameter('clinicianId') }}
    end
