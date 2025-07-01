select
    registration_date as "{{ translate_label('patientRegistrationDate', 'Registration date') }}",
    registered_by as "{{ translate_label('patientRegisteredBy', 'Registered by') }}",
    first_name as "{{ translate_label('patientFirstName', 'First name') }}",
    middle_name as "{{ translate_label('patientMiddleName', 'Middle name') }}",
    last_name as "{{ translate_label('patientLastName', 'Last name') }}",
    cultural_name as "{{ translate_label('patientCulturalName', 'Cultural name') }}",
    display_id as "{{ translate_label('patientDisplayId', 'Patient ID') }}",
    sex as "{{ translate_label('patientSex', 'Sex') }}",
    village as "{{ translate_label('patientVillage', 'village' ) }}",
    date_of_birth as "{{ translate_label('patientDateOfBirth', 'Date of birth') }}",
    birth_certificate as "{{ translate_label('patientBirthCertificate', 'Birth certificate') }}",
    driving_license as "{{ translate_label('patientDrivingLicense', 'Driving license') }}",
    passport as "{{ translate_label('patientPassport', 'Passport') }}",
    blood_type as "{{ translate_label('patientBloodType', 'Blood type') }}",
    title as "{{ translate_label('patientTitle', 'Title') }}",
    marital_status as "{{ translate_label('patientMaritalStatus', 'Marital status') }}",
    primary_contact_number as "{{ translate_label('patientPrimaryContactNumber', 'Primary contact number') }}",   -- noqa:disable=LT05
    secondary_contact_number as "{{ translate_label('patientSecondaryContactNumber', 'Secondary contact number') }}",   -- noqa:disable=LT05
    country_of_birth as "{{ translate_label('patientCountryOfBirth', 'Country of birth') }}",
    nationality as "{{ translate_label('patientNationality', 'Nationality') }}",
    ethnicity as "{{ translate_label('patientEthnicity', 'Ethnicity') }}",
    occupation as "{{ translate_label('patientOccupation', 'Occupation') }}",
    religion as "{{ translate_label('patientReligion', 'Religion') }}",
    patient_billing_type as "{{ translate_label('patientBillingType', 'Billing type') }}"
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
