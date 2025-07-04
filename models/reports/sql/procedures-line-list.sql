select
    display_id as "{{ translate_label('patientDisplayId') }}",
    first_name as "{{ translate_label('patientFirstName') }}",
    last_name as "{{ translate_label('patientLastName') }}",
    date_of_birth as "{{ translate_label('patientDateOfBirth') }}",
    age as "{{ translate_label('patientAge') }}",
    sex as "{{ translate_label('patientSex') }}",
    nationality as "{{ translate_label('patientNationality') }}",
    encounter_facility as "{{ translate_label('facility') }}",
    encounter_department as "{{ translate_label('department') }}",
    encounter_type as "{{ translate_label('encounterType') }}",
    encounter_start_datetime as "{{ translate_label('encounterStartDateTime') }}",
    encounter_end_datetime as "{{ translate_label('encounterEndDateTime') }}",
    procedure_facility as "{{ translate_label('procedureFacility') }}",
    procedure_area as "{{ translate_label('procedureLocationGroup') }}",
    procedure_location as "{{ translate_label('procedureLocation') }}",
    procedure_type as "{{ translate_label('procedure') }}",
    procedure_start_time as "{{ translate_label('procedureStartDateTime') }}",
    procedure_end_time as "{{ translate_label('procedureEndDateTime') }}",
    procedure_duration as "{{ translate_label('procedureDuration') }}",
    procedure_clinician as "{{ translate_label('procedureClinician') }}",
    procedure_anaesthetist as "{{ translate_label('procedureAnaesthetist') }}",
    procedure_assistant as "{{ translate_label('procedureAssistant') }}",
    is_completed as "{{ translate_label('procedureIsCompleted') }}"
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
