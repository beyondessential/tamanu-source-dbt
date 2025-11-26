select
    to_char(registration_date, '{{ var("date_format") }}') as "{{ translate_label_from_seed('patientRegistrationDate') }}",
    registered_by as "{{ translate_label_from_seed('patientRegisteredBy') }}",
    first_name as "{{ translate_label_from_seed('patientFirstName') }}",
    middle_name as "{{ translate_label_from_seed('patientMiddleName') }}",
    last_name as "{{ translate_label_from_seed('patientLastName') }}",
    cultural_name as "{{ translate_label_from_seed('patientCulturalName') }}",
    display_id as "{{ translate_label_from_seed('patientDisplayId') }}",
    sex as "{{ translate_label_from_seed('patientSex') }}",
    village as "{{ translate_label_from_seed('patientVillage') }}",
    to_char(date_of_birth, '{{ var("date_format") }}') as "{{ translate_label_from_seed('patientDateOfBirth') }}",
    birth_certificate as "{{ translate_label_from_seed('patientBirthCertificate') }}",
    driving_license as "{{ translate_label_from_seed('patientDrivingLicense') }}",
    passport as "{{ translate_label_from_seed('patientPassport') }}",
    blood_type as "{{ translate_label_from_seed('patientBloodType') }}",
    title as "{{ translate_label_from_seed('patientTitle') }}",
    marital_status as "{{ translate_label_from_seed('patientMaritalStatus') }}",
    primary_contact_number as "{{ translate_label_from_seed('patientPrimaryContactNumber') }}",   -- noqa:disable=LT05
    secondary_contact_number as "{{ translate_label_from_seed('patientSecondaryContactNumber') }}",   -- noqa:disable=LT05
    country_of_birth as "{{ translate_label_from_seed('patientCountryOfBirth') }}",
    nationality as "{{ translate_label_from_seed('patientNationality') }}",
    ethnicity as "{{ translate_label_from_seed('patientEthnicity') }}",
    occupation as "{{ translate_label_from_seed('patientOccupation') }}",
    religion as "{{ translate_label_from_seed('patientReligion') }}",
    patient_billing_type as "{{ translate_label_from_seed('patientBillingType') }}"
from {{ ref("ds__patients") }}
where
    case
        when {{ parameter('fromDate', default_value='2024-01-01', data_type='date') }} is null then true
        else registration_date >= {{ parameter('fromDate', default_value='2024-01-01', data_type='date') }}
    end
    and
    case
        when {{ parameter('toDate', default_value='2024-01-31', data_type='date') }} is null then true
        else registration_date <= {{ parameter('toDate', default_value='2024-01-31', data_type='date') }}
    end
order by registration_date
