select
    display_id as "{{ translate_label('patientDisplayId', 'Patient ID') }}",
    first_name as "{{ translate_label('patientFirstName', 'First name') }}",
    last_name as "{{ translate_label('patientLastName', 'Last name') }}",
    date_of_birth as "{{ translate_label('patientDateOfBirth', 'Date of birth') }}",
    age as "{{ translate_label('patientAge', 'Age') }}",
    sex as "{{ translate_label('patientSex', 'Sex') }}",
    nationality as "{{ translate_label('patientNationality', 'Nationality') }}",
    encounter_facility as "{{ translate_label('facilityName', 'Facility') }}",
    encounter_department as "{{ translate_label('departmentName', 'Department') }}",
    encounter_type as "{{ translate_label('encounterType', 'Type') }}",
    encounter_start_datetime as "{{ translate_label('encounterStartDateTime', 'Encounter start date and time') }}",
    encounter_end_datetime as "{{ translate_label('encounterEndDateTime', 'Encounter end date and time') }}",
    procedure_facility as "{{ translate_label('procedureFacility', 'Procedure facility') }}",
    procedure_area as "{{ translate_label('procedureArea', 'Procedure area') }}",
    procedure_location as "{{ translate_label('procedureLocation', 'Procedure location') }}",
    procedure_type as "{{ translate_label('procedureName', 'Procedure') }}",
    procedure_start_time as "{{ translate_label('procedureStartDateTime', 'Procedure start (date and time)') }}",
    procedure_end_time as "{{ translate_label('procedureEndDateTime', 'Procedure end (date and time)') }}",
    procedure_duration as "{{ translate_label('procedureDuration', 'Procedure duration') }}",
    procedure_clinician as "{{ translate_label('procedureClinician', 'Procedure clinician') }}",
    procedure_anaesthetist as "{{ translate_label('procedureAnaesthetist', 'Procedure anaesthetist') }}",
    procedure_assistant as "{{ translate_label('procedureAssistant', 'Procedure assistant') }}",
    is_completed as "{{ translate_label('procedureIsCompleted', 'Procedure marked as completed') }}"
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
