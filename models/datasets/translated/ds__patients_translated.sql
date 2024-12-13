select
    registration_date as "Registration date",  -- noqa:disable=RF05
    registered_by as "Registered by",   -- noqa:disable=RF05
    first_name as "{{ translate_string('general.localisedField.firstName.label', var('language')) }}",
    middle_name as "{{ translate_string('general.localisedField.middleName.label', var('language')) }}",
    last_name as "{{ translate_string('general.localisedField.lastName.label', var('language')) }}",
    cultural_name as "{{ translate_string('general.localisedField.culturalName.label', var('language')) }}",
    display_id as "{{ translate_string('general.localisedField.displayId.label', var('language')) }}",
    sex as "{{ translate_string('general.sex.label', var('language')) }}",
    village as "{{ translate_string('general.localisedField.villageId.label', var('language')) }}",
    date_of_birth as "{{ translate_string('general.localisedField.dateOfBirth.label', var('language')) }}",
    birth_certificate as "{{ translate_string('general.localisedField.birthCertificate.label', var('language')) }}",
    driving_license as "{{ translate_string('general.localisedField.drivingLicense.label', var('language')) }}",
    passport as "{{ translate_string('general.localisedField.passport.label', var('language')) }}",
    blood_type as "{{ translate_string('general.localisedField.bloodType.label', var('language')) }}",
    title as "{{ translate_string('general.localisedField.title.label', var('language')) }}",
    marital_status as "{{ translate_string('general.localisedField.maritalStatus.label', var('language')) }}",
    primary_contact_number as "{{ translate_string('general.localisedField.primaryContactNumber.label', var('language')) }}",   -- noqa:disable=LT05
    secondary_contact_number as "{{ translate_string('general.localisedField.secondaryContactNumber.label', var('language')) }}",   -- noqa:disable=LT05
    country_of_birth as "{{ translate_string('general.localisedField.countryOfBirthId.label', var('language')) }}",
    nationality as "{{ translate_string('general.localisedField.nationalityId.label', var('language')) }}",
    ethnicity as "{{ translate_string('general.localisedField.ethnicityId.label', var('language')) }}",
    occupation as "{{ translate_string('general.localisedField.occupationId.label', var('language')) }}",
    religion as "{{ translate_string('general.localisedField.religionId.label', var('language')) }}",
    patient_billing_type as "{{ translate_string('general.localisedField.patientBillingTypeId.label', var('language')) }}"
from {{ ref("ds__patients") }}
