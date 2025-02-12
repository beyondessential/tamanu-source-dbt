select
    patient_id,
    vaccine_schedules_id,
    vaccine_category as "{{ translate_string('vaccine.category.label', 'Vaccine category') }}",
    display_id as "{{ translate_string('general.localisedField.displayId.label', 'Patient ID') }}",
    first_name as "{{ translate_string('general.localisedField.firstName.label', 'First name') }}",
    last_name as "{{ translate_string('general.localisedField.lastName.label', 'Last name') }}",
    date_of_birth as "{{ translate_string('general.localisedField.dateOfBirth.label', 'Date of birth') }}",
    age as "{{ translate_string('general.localisedField.Age', 'Age') }}",
    sex as "{{ translate_string('general.localisedField.sex.label', 'Sex') }}",
    due_date as "{{ translate_string('', 'Vaccination due date') }}",
    vaccine_name as "{{ translate_string('vaccine.vaccineName.label', 'Vaccine name') }}",
    vaccine_schedule as "{{ translate_string('vaccine.schedule.label', 'Schedule') }}",
    status as "{{ translate_string('general.localisedField.vaccinationStatus.label', 'Vaccine status') }}"
from {{ ref("ds__vaccinations_upcoming") }}
