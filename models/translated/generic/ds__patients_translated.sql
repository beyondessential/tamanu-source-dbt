select
    registration_date as "Registration date",
    registered_by as "Registered by",
    first_name as "{{ translate_string('general.localisedField.firstName.label', var('language'), 'First name') | trim }}",
    middle_name as "{{ translate_string('general.localisedField.middleName.label', var('language'), 'Middle name') | trim }}",
    last_name as "{{ translate_string('general.localisedField.lastName.label', var('language'), 'Last name') | trim }}",
    cultural_name as "{{ translate_string('general.localisedField.culturalName.label', var('language'), 'Cultural name') | trim }}",
    display_id as "{{ translate_string('general.localisedField.displayId.label', var('language'), 'Hospital ID') | trim }}",
    sex as "{{ translate_string('general.sex.label', var('language'), 'Sex') | trim }}",
    village as "{{ translate_string('general.localisedField.villageId.label', var('language'), 'Village') | trim }}",
    date_of_birth as "{{ translate_string('general.localisedField.dateOfBirth.label', var('language'), 'Date of birth') | trim }}",
    birth_certificate as "{{ translate_string('general.localisedField.birthCertificate.label', var('language'), 'Birth certificate') | trim }}",
    driving_license as "{{ translate_string('general.localisedField.drivingLicense.label', var('language'), 'Driving license') | trim }}",
    passport as "{{ translate_string('general.localisedField.passport.label', var('language'), 'Passport') | trim }}",
    blood_type as "{{ translate_string('general.localisedField.bloodType.label', var('language'), 'Blood type') | trim }}",
    title as "{{ translate_string('general.localisedField.title.label', var('language'), 'Title') | trim }}",
    marital_status as "{{ translate_string('general.localisedField.maritalStatus.label', var('language'), 'Marital status') | trim }}",
    primary_contact_number as "{{ translate_string('general.localisedField.primaryContactNumber.label', var('language'), 'Primary contact number') | trim }}",   -- noqa:disable=LT05
    secondary_contact_number as "{{ translate_string('general.localisedField.secondaryContactNumber.label', var('language'), 'Secondary contact number') | trim }}",   -- noqa:disable=LT05
    country_of_birth as "{{ translate_string('general.localisedField.countryOfBirthId.label', var('language'), 'Country of birth') | trim }}",
    nationality as "{{ translate_string('general.localisedField.nationalityId.label', var('language'), 'Nationality') | trim }}",
    ethnicity as "{{ translate_string('general.localisedField.ethnicityId.label', var('language'), 'Ethnicity') | trim }}",
    occupation as "{{ translate_string('general.localisedField.occupationId.label', var('language'), 'Occupation') | trim }}",
    religion as "{{ translate_string('general.localisedField.religionId.label', var('language'), 'Religion') | trim }}",
    patient_billing_type as "{{ translate_string('general.localisedField.patientBillingTypeId.label', var('language'), 'Patient billing type') | trim }}"
from {{ ref("ds__patients") }}