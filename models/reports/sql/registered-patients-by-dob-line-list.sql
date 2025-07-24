select
    to_char(registration_date, '{{ var("date_format") }}') as "{{ translate_label('patientRegistrationDate') }}",
    registered_by as "{{ translate_label('patientRegisteredBy') }}",
    first_name as "{{ translate_label('patientFirstName') }}",
    middle_name as "{{ translate_label('patientMiddleName') }}",
    last_name as "{{ translate_label('patientLastName') }}",
    cultural_name as "{{ translate_label('patientCulturalName') }}",
    display_id as "{{ translate_label('patientDisplayId') }}",
    sex as "{{ translate_label('patientSex') }}",
    village as "{{ translate_label('patientVillage') }}",
    to_char(date_of_birth, '{{ var("date_format") }}') as "{{ translate_label('patientDateOfBirth') }}",
    registration_type as "{{ translate_label('patientRegistrationType') }}",
    birth_certificate as "{{ translate_label('patientBirthCertificate') }}",
    driving_license as "{{ translate_label('patientDrivingLicense') }}",
    passport as "{{ translate_label('patientPassport') }}",
    blood_type as "{{ translate_label('patientBloodType') }}",
    title as "{{ translate_label('patientTitle') }}",
    marital_status as "{{ translate_label('patientMaritalStatus') }}",
    primary_contact_number as "{{ translate_label('patientPrimaryContactNumber') }}",   -- noqa:disable=LT05
    secondary_contact_number as "{{ translate_label('patientSecondaryContactNumber') }}",   -- noqa:disable=LT05
    country_of_birth as "{{ translate_label('patientCountryOfBirth') }}",
    nationality as "{{ translate_label('patientNationality') }}",
    ethnicity as "{{ translate_label('patientEthnicity') }}",
    occupation as "{{ translate_label('patientOccupation') }}",
    religion as "{{ translate_label('patientReligion') }}",
    patient_billing_type as "{{ translate_label('patientBillingType') }}"
from {{ ref("ds__patients") }}
where case
        when {{ parameter('fromDate', default_value='2024-01-01', data_type='date') }} is null then true
        else date_of_birth >= {{ parameter('fromDate', default_value='2024-01-01', data_type='date') }}
    end
    and
    case
        when {{ parameter('toDate', default_value='2024-01-31', data_type='date') }} is null then true
        else date_of_birth <= {{ parameter('toDate', default_value='2024-01-31', data_type='date') }}
    end
order by date_of_birth, last_name, first_name
