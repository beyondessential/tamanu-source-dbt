select
    display_id as "{{ translate_label('patientDisplayId') }}",
    first_name as "{{ translate_label('patientFirstName') }}",
    last_name as "{{ translate_label('patientLastName') }}",
    to_char(date_of_birth, '{{ var("date_format") }}') as "{{ translate_label('patientDateOfBirth') }}",
    village as "{{ translate_label('patientVillage') }}",
    age as "{{ translate_label('patientAge') }}",
    sex as "{{ translate_label('patientSex') }}",
    to_char(due_date, '{{ var("date_format") }}') as "{{ translate_label('vaccinationDueDate') }}",
    vaccine_name as "{{ translate_label('vaccineName') }}",
    vaccine_schedule as "{{ translate_label('vaccineSchedule') }}",
    vaccine_status as "{{ translate_label('vaccinationStatus') }}"
from {{ ref("ds__patient_vaccinations_upcoming") }}
where
    -- BL-006: when the user selects "yes", drop patients explicitly recorded as
    -- resident in a country other than the home country and retain patients with
    -- no recorded country
    case
        when {{ parameter('excludeNonHomeCountry') }} = 'yes'
            then country_id is null or country_id = '{{ var("home_country_id") }}'
        else true
    end
    and
    -- BL-004: restrict to patients born within the supplied date range
    date_of_birth >= {{ parameter('fromDate', default_value='2024-01-01', data_type='date') }}
    and
    date_of_birth <= {{ parameter('toDate', default_value='2024-01-31', data_type='date') }}
    and
    -- BL-005: optional filters -- each applies only when the user supplies a value
    case
        when {{ parameter('status') }} is null then true
        else vaccine_status = {{ parameter('status') }}
    end
    and
    case
        when {{ parameter('category') }} is null then true
        else vaccine_category = {{ parameter('category') }}
    end
    and
    case
        when {{ parameter('vaccine') }} is null then true
        else vaccine_name = {{ parameter('vaccine') }}
    end
    and
    case
        when {{ parameter('villageId') }} is null then true
        else village_id = {{ parameter('villageId') }}
    end
-- BL-007: order by due date, then patient name and vaccine
order by due_date, last_name, first_name, vaccine_name
