select
    registration_date as "Registration date",
    registered_by as "Registered by",
    first_name as "{{ translate_string('general.localisedField.firstName.label','First name') }}",
    middle_name as "{{ translate_string('general.localisedField.middleName.label','Middle name') }}",
    last_name as "{{ translate_string('general.localisedField.lastName.label','Last name') }}",
    cultural_name as "{{ translate_string('general.localisedField.culturalName.label','Cultural name') }}",
    display_id as "{{ translate_string('general.localisedField.displayId.label','Patient ID') }}",
    sex as "{{ translate_string('general.sex.label','Sex') }}",
    village as "{{ translate_string('general.localisedField.villageId.label','Village') }}",
    date_of_birth as "{{ translate_string('general.localisedField.dateOfBirth.label','Date of birth') }}",
    birth_certificate as "{{ translate_string('general.localisedField.birthCertificate.label','Birth certificate') }}",
    driving_license as "{{ translate_string('general.localisedField.drivingLicense.label','Driving license') }}",
    passport as "{{ translate_string('general.localisedField.passport.label','Passport') }}",
    blood_type as "{{ translate_string('general.localisedField.bloodType.label','Blood type') }}",
    title as "{{ translate_string('general.localisedField.title.label','Title') }}",
    marital_status as "{{ translate_string('general.localisedField.maritalStatus.label','Marital status') }}",
    primary_contact_number as "{{ translate_string('general.localisedField.primaryContactNumber.label','Primary contact number') }}",   -- noqa:disable=LT05
    secondary_contact_number as "{{ translate_string('general.localisedField.secondaryContactNumber.label','Secondary contact number') }}",   -- noqa:disable=LT05
    country_of_birth as "{{ translate_string('general.localisedField.countryOfBirthId.label','Country of birth') }}",
    nationality as "{{ translate_string('general.localisedField.nationalityId.label','Nationality') }}",
    ethnicity as "{{ translate_string('general.localisedField.ethnicityId.label','Ethnicity') }}",
    occupation as "{{ translate_string('general.localisedField.occupationId.label','Occupation') }}",
    religion as "{{ translate_string('general.localisedField.religionId.label','Religion') }}",
    patient_billing_type as "{{ translate_string('general.localisedField.patientBillingTypeId.label','Patient billing type') }}"
from {{ ref("ds__patients") }}
