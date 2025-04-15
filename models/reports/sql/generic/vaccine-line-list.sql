select
    display_id as "{{ translate_string('patientDisplayId', 'Patient ID') }}",
    first_name as "{{ translate_string('patientFirstName', 'First name') }}",
    last_name as "{{ translate_string('patientLastName', 'Last name') }}",
    to_char(date_of_birth, '{{ var("date_format") }}') as "{{ translate_string('patientDob', 'Date of birth') }}",
    age as "{{ translate_string('patientAge', 'Age') }}",
    sex as "{{ translate_string('patientSex', 'Sex') }}",
    village as "{{ translate_string('patientVillage', 'Village') }}",
    facility as "{{ translate_string('patientFacility', 'Facility') }}",
    department as "{{ translate_string('patientDepartment', 'Department') }}",
    location_group as "{{ translate_string('patientArea', 'Area') }}",
    location as "{{ translate_string('patientLocation', 'Location') }}",
    to_char(vaccination_date, '{{ var("date_format") }}') as "{{ translate_string('vaccinationDate', 'Vaccination date') }}",
    vaccine_category as "{{ translate_string('vaccineCategory', 'Vaccine category') }}",
    vaccine_name as "{{ translate_string('vaccineName', 'Vaccine name') }}",
    vaccine_brand as "{{ translate_string('vaccineBrand', 'If category of Other, Vaccine brand') }}",
    disease as "{{ translate_string('vaccineDisease', 'If category of Other, Disease') }}",
    vaccine_status as "{{ translate_string('vaccineStatus', 'Vaccine status') }}",
    vaccine_schedule as "{{ translate_string('vaccineSchedule', 'Schedule') }}",
    batch as "{{ translate_string('vaccineBatch', 'Batch') }}",
    given_by as "{{ translate_string('givenBy', 'Given by') }}",
    recorded_by as "{{ translate_string('recordedBy', 'Recorded by') }}",
    circumstances as "{{ translate_string('vaccineGivenElsewhereCircumstances', 'If given elsewhere, Circumstances') }}",
    given_elsewhere_by as "{{ translate_string('vaccineGivenElsewhereCountry', 'If given elsewhere, Country') }}",
    not_given_clinician as "{{ translate_string('notGivenClinician', 'If not given, Supervising clinician') }}",
    not_given_reason as "{{ translate_string('notGivenReason', 'If not given, Reason not given') }}"
from {{ ref("ds__vaccinations") }}
where
    vaccine_status in ('Given', 'Not Given')
    and
    case
        when {{ parameter('fromDate', default_value='2024-01-01', data_type='date') }} is null then true
        else vaccination_date::date
            >= {{ parameter('fromDate', default_value='2024-01-01', data_type='date') }}
    end
    and
    case
        when {{ parameter('toDate', default_value='2024-01-31', data_type='date') }} is null then true
        else vaccination_date::date
            <= {{ parameter('toDate', default_value='2024-01-31', data_type='date') }}
    end
    and
    case
        when {{ parameter('villageId') }} is null then true
        else village_id = {{ parameter('villageId') }}
    end
    and
    case
        when {{ parameter('facilityId') }} is null then true
        else facility_id = {{ parameter('facilityId') }}
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
