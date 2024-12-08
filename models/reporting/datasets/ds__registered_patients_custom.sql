{% set language = 'en' %}

select
    registration_date as "Registration date",  -- noqa:disable=RF05
    registered_by as "Registered by",   -- noqa:disable=RF05
    first_name as "{{ translate_string('general.localisedField.firstName.label', language) }}",
    middle_name as "{{ translate_string('general.localisedField.middleName.label', language) }}",
    last_name as "{{ translate_string('general.localisedField.lastName.label', language) }}",
    cultural_name as "{{ translate_string('general.localisedField.culturalName.label', language) }}",
    display_id as "{{ translate_string('general.localisedField.displayId.label', language) }}",
    sex as "{{ translate_string('general.sex.label', language) }}",
    village as "{{ translate_string('general.localisedField.villageId.label', language) }}",
    date_of_birth as "{{ translate_string('general.localisedField.dateOfBirth.label', language) }}",
    birth_certificate as "{{ translate_string('general.localisedField.birthCertificate.label', language) }}",
    driving_license as "{{ translate_string('general.localisedField.drivingLicense.label', language) }}",
    passport as "{{ translate_string('general.localisedField.passport.label', language) }}",
    blood_type as "{{ translate_string('general.localisedField.bloodType.label', language) }}",
    title as "{{ translate_string('general.localisedField.title.label', language) }}",
    marital_status as "{{ translate_string('general.localisedField.maritalStatus.label', language) }}",
    primary_contact_number as "{{ translate_string('general.localisedField.primaryContactNumber.label', language) }}",
    secondary_contact_number as "{{ translate_string('general.localisedField.secondaryContactNumber.label', language) }}", -- noqa:disable=LT05
    country_of_birth as "{{ translate_string('general.localisedField.countryOfBirthId.label', language) }}",
    nationality as "{{ translate_string('general.localisedField.nationalityId.label', language) }}",
    ethnicity as "{{ translate_string('general.localisedField.ethnicityId.label', language) }}",
    occupation as "{{ translate_string('general.localisedField.occupationId.label', language) }}",
    religion as "{{ translate_string('general.localisedField.religionId.label', language) }}",
    patient_billing_type as "{{ translate_string('general.localisedField.patientBillingTypeId.label', language) }}"
from {{ ref("ds__registered_patients") }}
