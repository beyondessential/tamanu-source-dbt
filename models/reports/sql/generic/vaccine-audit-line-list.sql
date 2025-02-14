select 
    display_id as "{{ translate_string('general.localisedField.displayId.label', 'Patient ID') }}",
    first_name as "{{ translate_string('general.localisedField.firstName.label', 'First name') }}",
    last_name as "{{ translate_string('general.localisedField.lastName.label', 'Last name') }}",
    to_char(date_of_birth, '{{ var("date_format") }}') as "{{ translate_string('general.localisedField.dateOfBirth.label', 'Date of birth') }}",
    age as "{{ translate_string('general.localisedField.Age', 'Age') }}",
    sex as "{{ translate_string('general.localisedField.sex.label', 'Sex') }}",
    village as "{{ translate_string('general.localisedField.villageId.label', 'Village') }}",
    to_char(vaccination_date, '{{ var("date_format") }}') as "{{ translate_string('vaccine.dateRecorded.label', 'Vaccination date') }}",
    vaccine_name as "{{ translate_string('vaccine.vaccineName.label', 'Vaccine name') }}",
    vaccine_brand as "{{ translate_string('', 'If category of Other, Vaccine brand') }}",
    disease as "{{ translate_string('', 'If category of Other, Disease') }}",
    vaccine_status as "{{ translate_string('general.localisedField.vaccinationStatus.label', 'Vaccine status') }}",
    vaccine_schedule as "{{ translate_string('vaccine.schedule.label', 'Schedule') }}",
    given_by as "{{ translate_string('vaccine.givenBy.label', 'Given by') }}",
    recorded_by as "{{ translate_string('vaccine.recordedBy.label', 'Recorded by') }}",
    modified_by as "{{ translate_string('', 'Record modified by') }}",
    to_char(last_modified_datetime, '{{ var("date_format") }}') as "{{ translate_string('', 'Record modification date') }}"
from {{ ref("ds__vaccinations") }}
where
    vaccine_status in ('Recorded in error', 'Historical')
    and
    case
        when{{ parameter('fromDate', default_value='2024-01-01', data_type='date') }} is null then true
        else vaccination_date::date
            >={{ parameter('fromDate', default_value='2024-01-01', data_type='date') }}
    end
    and
    case
        when{{ parameter('toDate', default_value='2024-01-31', data_type='date') }} is null then true
        else vaccination_date::date
            <={{ parameter('toDate', default_value='2024-01-31', data_type='date') }}
    end
    and
    case
        when{{ parameter('villageId') }} is null then true
        else village_id ={{ parameter('villageId') }}
    end
    and
    case
        when{{ parameter('facilityId') }} is null then true
        else facility_id ={{ parameter('facilityId') }}
    end
    and
    case
        when{{ parameter('category') }} is null then true
        else vaccine_category ={{ parameter('category') }}
    end
    and
    case
        when{{ parameter('vaccine') }} is null then true
        else vaccine_name ={{ parameter('vaccine') }}
    end
    and
    case
        when{{ parameter('status') }} is null then true
        else vaccine_status ={{ parameter('status') }}
    end
