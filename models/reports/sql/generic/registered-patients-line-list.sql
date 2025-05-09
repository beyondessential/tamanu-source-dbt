select
    registration_date as "{{ translate_string('patientRegistrationDate', 'Registration date') }}",
    registered_by as "{{ translate_string('patientRegisteredBy', 'Registered by') }}",
    first_name as "{{ translate_string('patientFirstName', 'First name') }}",
    middle_name as "{{ translate_string('patientMiddleName', 'Middle name') }}",
    last_name as "{{ translate_string('patientLastName', 'Last name') }}",
    cultural_name as "{{ translate_string('patientCulturalName', 'Cultural name') }}",
    display_id as "{{ translate_string('patientDisplayId', 'Patient ID') }}",
    sex as "{{ translate_string('patientSex', 'Sex') }}",
    village as "{{ translate_string('patientVillage', 'village' ) }}",
    date_of_birth as "{{ translate_string('patientDateOfBirth', 'Date of birth') }}",
    birth_certificate as "{{ translate_string('patientBirthCertificate', 'Birth certificate') }}",
    driving_license as "{{ translate_string('patientDrivingLicense', 'Driving license') }}",
    passport as "{{ translate_string('patientPassport', 'Passport') }}",
    blood_type as "{{ translate_string('patientBloodType', 'Blood type') }}",
    title as "{{ translate_string('patientTitle', 'Title') }}",
    marital_status as "{{ translate_string('patientMaritalStatus', 'Marital status') }}",
    primary_contact_number as "{{ translate_string('patientPrimaryContactNumber', 'Primary contact number') }}",   -- noqa:disable=LT05
    secondary_contact_number as "{{ translate_string('patientSecondaryContactNumber', 'Secondary contact number') }}",   -- noqa:disable=LT05
    country_of_birth as "{{ translate_string('patientCountryOfBirth', 'Country of birth') }}",
    nationality as "{{ translate_string('patientNationality', 'Nationality') }}",
    ethnicity as "{{ translate_string('patientEthnicity', 'Ethnicity') }}",
    occupation as "{{ translate_string('patientOccupation', 'Occupation') }}",
    religion as "{{ translate_string('patientReligion', 'Religion') }}",
    patient_billing_type as "{{ translate_string('patientBillingType', 'Patient billing type') }}"
from {{ ref("ds__patients") }}
where
    case
        when {{ parameter('fromDate', default_value='2024-01-01', data_type='date') }} is null then true
        else registration_date::date >= {{ parameter('fromDate', default_value='2024-01-01', data_type='date') }}
    end
    and
    case
        when {{ parameter('toDate', default_value='2024-01-31', data_type='date') }} is null then true
        else registration_date::date <= {{ parameter('toDate', default_value='2024-01-31', data_type='date') }}
    end
