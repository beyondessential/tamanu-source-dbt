select
    display_id as "{{ translate_string('general.localisedField.displayId.label', 'Patient ID') }}",
    first_name as "{{ translate_string('general.localisedField.firstName.label', 'First name') }}",
    last_name as "{{ translate_string('general.localisedField.lastName.label', 'Last name') }}",
    to_char(date_of_birth, '{{ var("date_format") }}') as "{{ translate_string('general.localisedField.dateOfBirth.label', 'Date of birth') }}",
    age as "{{ translate_string('general.localisedField.Age', 'Age') }}",
    sex as "{{ translate_string('general.localisedField.sex.label', 'Sex') }}",
    village as "{{ translate_string('general.localisedField.villageId.label', 'Village') }}",
    facility as "{{ translate_string('general.localisedField.facility.label', 'Facility') }}",
    department as "{{ translate_string('general.localisedField.departmentId.label', 'Department') }}",
    location_group as "{{ translate_string('general.localisedField.area.label', 'Area') }}",
    location as "{{ translate_string('general.localisedField.locationId.label', 'Location') }}",
    to_char(vaccination_date, '{{ var("date_format") }}') as "{{ translate_string('vaccine.dateRecorded.label', 'Vaccination date') }}",
    vaccine_category as "{{ translate_string('vaccine.category.label', 'Vaccine category') }}",
    vaccine_name as "{{ translate_string('vaccine.vaccineName.label', 'Vaccine name') }}",
    vaccine_brand as "{{ translate_string('', 'If category of Other, Vaccine brand') }}",
    disease as "{{ translate_string('', 'If category of Other, Disease') }}",
    vaccine_status as "{{ translate_string('general.localisedField.vaccinationStatus.label', 'Vaccine status') }}",
    vaccine_schedule as "{{ translate_string('vaccine.schedule.label', 'Schedule') }}",
    batch as "{{ translate_string('vaccine.batch.label', 'Batch') }}",
    given_by as "{{ translate_string('vaccine.givenBy.label', 'Given by') }}",
    recorded_by as "{{ translate_string('vaccine.recordedBy.label', 'Recorded by') }}",
    circumstances as "{{ translate_string('', 'If given elsewhere, Circumstances') }}",
    given_elsewhere_by as "{{ translate_string('', 'If given elsewhere, Country') }}",
    not_given_clinician as "{{ translate_string('', 'If not given, Supervising clinician') }}",
    not_given_reason as "{{ translate_string('vaccine.notGivenReason.label', 'If not given, Reason not given') }}"
from {{ ref("ds__vaccinations") }}
where
    vaccine_status in ('Given', 'Not Given')
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
        when{{ parameter('category') }} is null then true
        else vaccine_name ={{ parameter('vaccine') }}
    end
