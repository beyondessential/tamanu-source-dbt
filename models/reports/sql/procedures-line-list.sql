select
    display_id as "{{ translate_label('patientDisplayId') }}",
    first_name as "{{ translate_label('patientFirstName') }}",
    last_name as "{{ translate_label('patientLastName') }}",
    to_char(date_of_birth, '{{ var("date_format") }}') as "{{ translate_label('patientDateOfBirth') }}",
    age as "{{ translate_label('patientAge') }}",
    sex as "{{ translate_label('patientSex') }}",
    nationality as "{{ translate_label('patientNationality') }}",
    encounter_facility as "{{ translate_label('facility') }}",
    encounter_department as "{{ translate_label('department') }}",
    encounter_type as "{{ translate_label('encounterType') }}",
    to_char(encounter_start_datetime, '{{ var("datetime_format") }}') as "{{ translate_label('encounterStartDateTime') }}",
    to_char(encounter_end_datetime, '{{ var("datetime_format") }}') as "{{ translate_label('encounterEndDateTime') }}",
    procedure_facility as "{{ translate_label('procedureFacility') }}",
    procedure_area as "{{ translate_label('procedureLocationGroup') }}",
    procedure_location as "{{ translate_label('procedureLocation') }}",
    procedure_type as "{{ translate_label('procedure') }}",
    to_char(procedure_date, '{{ var("date_format") }}') as "{{ translate_label('procedureDate') }}",
    to_char(procedure_start_time, '{{ var("time_format") }}') as "{{ translate_label('procedureStartDateTime') }}",
    to_char(procedure_end_time, '{{ var("time_format") }}') as "{{ translate_label('procedureEndDateTime') }}",
    procedure_duration as "{{ translate_label('procedureDuration') }}",
    procedure_clinician as "{{ translate_label('procedureClinician') }}",
    procedure_anaesthetist as "{{ translate_label('procedureAnaesthetist') }}",
    procedure_assistant_anaesthetist as "{{ translate_label('procedureAssistantAnaesthetist') }}",
    is_completed as "{{ translate_label('procedureIsCompleted') }}",
    time_in as "{{ translate_label('procedureTimeIn') }}",
    time_out as "{{ translate_label('procedureTimeOut') }}"
from {{ ref('ds__procedures') }}
where
    case
        when {{ parameter('fromDate', default_value='2024-01-01', data_type='date') }} is null then true
        else procedure_date
            >= {{ parameter('fromDate', default_value='2024-01-01', data_type='date') }}
    end
    and
    case
        when {{ parameter('toDate', default_value='2024-01-31', data_type='date') }} is null then true
        else procedure_date
            <= {{ parameter('toDate', default_value='2024-01-31', data_type='date') }}
    end
    and
    case
        when {{ parameter('facilityId') }} is null then true
        else procedure_facility_id = {{ parameter('facilityId') }}
    end
    and
    case
        when {{ parameter('departmentId') }} is null then true
        else encounter_department_id = {{ parameter('departmentId') }}
    end
    and
    case
        when {{ parameter('locationGroupId') }} is null then true
        else procedure_area_id = {{ parameter('locationGroupId') }}
    end
    and
    case
        when {{ parameter('locationId') }} is null then true
        else procedure_location_id = {{ parameter('locationId') }}
    end
    and
    case
        when {{ parameter('clinicianId') }} is null then true
        else procedure_clinician_id = {{ parameter('clinicianId') }}
    end
order by procedure_start_time
