select
    display_id as "{{ translate_label_from_seed('patientDisplayId') }}",
    first_name as "{{ translate_label_from_seed('patientFirstName') }}",
    last_name as "{{ translate_label_from_seed('patientLastName') }}",
    to_char(date_of_birth, '{{ var("date_format") }}') as "{{ translate_label_from_seed('patientDateOfBirth') }}",
    age as "{{ translate_label_from_seed('patientAge') }}",
    sex as "{{ translate_label_from_seed('patientSex') }}",
    nationality as "{{ translate_label_from_seed('patientNationality') }}",
    encounter_facility as "{{ translate_label_from_seed('facility') }}",
    encounter_department as "{{ translate_label_from_seed('department') }}",
    encounter_type as "{{ translate_label_from_seed('encounterType') }}",
    to_char(encounter_start_datetime, '{{ var("datetime_format") }}') as "{{ translate_label_from_seed('encounterStartDateTime') }}",
    to_char(encounter_end_datetime, '{{ var("datetime_format") }}') as "{{ translate_label_from_seed('encounterEndDateTime') }}",
    procedure_facility as "{{ translate_label_from_seed('procedureFacility') }}",
    procedure_area as "{{ translate_label_from_seed('procedureLocationGroup') }}",
    procedure_location as "{{ translate_label_from_seed('procedureLocation') }}",
    procedure_type as "{{ translate_label_from_seed('procedure') }}",
    to_char(procedure_date, '{{ var("date_format") }}') as "{{ translate_label_from_seed('procedureDate') }}",
    to_char(procedure_start_time, '{{ var("time_format") }}') as "{{ translate_label_from_seed('procedureStartDateTime') }}",
    to_char(procedure_end_time, '{{ var("time_format") }}') as "{{ translate_label_from_seed('procedureEndDateTime') }}",
    procedure_duration as "{{ translate_label_from_seed('procedureDuration') }}",
    procedure_clinician as "{{ translate_label_from_seed('procedureClinician') }}",
    procedure_anaesthetist as "{{ translate_label_from_seed('procedureAnaesthetist') }}",
    procedure_assistant_anaesthetist as "{{ translate_label_from_seed('procedureAssistantAnaesthetist') }}",
    is_completed as "{{ translate_label_from_seed('procedureIsCompleted') }}",
    time_in as "{{ translate_label_from_seed('procedureTimeIn') }}",
    time_out as "{{ translate_label_from_seed('procedureTimeOut') }}"
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
