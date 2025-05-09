select
    display_id as "{{ translate_string('patientDisplayId', 'Patient ID') }}",
    first_name as "{{ translate_string('patientFirstName', 'First name') }}",
    last_name as "{{ translate_string('patientLastName', 'Last name') }}",
    date_of_birth as "{{ translate_string('patientDateOfBirth', 'Date of birth') }}",
    age as "{{ translate_string('patientAge', 'Age') }}",
    sex as "{{ translate_string('patientSex', 'Sex') }}",
    nationality as "{{ translate_string('patientNationality', 'Nationality') }}",
    encounter_facility as "{{ translate_string('facilityName', Facility') }}",
    encounter_department as "{{ translate_string('departmentName', 'Department') }}",
    encounter_type as "{{ translate_string('encounterType', 'Type') }}",
    encounter_start_datetime as "{{ translate_string('encounterStartDateTime', 'Encounter start date and time') }}",
    encounter_end_datetime as "{{ translate_string('encounterEndDateTime', 'Encounter end date and time') }}",
    procedure_facility as "{{ translate_string('procedureFacility', 'Procedure facility') }}",
    procedure_area as "{{ translate_string('procedureArea', 'Procedure area') }}",
    procedure_location as "{{ translate_string('procedureLocation', 'Procedure location') }}",
    procedure_type as "{{ translate_string('procedureName', 'Procedure') }}",
    procedure_start_time as "{{ translate_string('procedureStartDateTime', 'Procedure start (date and time)') }}",
    procedure_end_time as "{{ translate_string('procedureEndDateTime', 'Procedure end (date and time)') }}",
    procedure_duration as "{{ translate_string('procedureDuration', 'Procedure duration') }}",
    procedure_clinician as "{{ translate_string('procedureClinician', 'Procedure clinician') }}",
    procedure_anaesthetist as "{{ translate_string('procedureAnaesthetist', 'Procedure anaesthetist') }}",
    procedure_assistant as "{{ translate_string('procedureAssistant', 'Procedure assistant') }}",
    is_completed as "{{ translate_string('procedureIsCompleted', 'Procedure marked as completed') }}"
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
