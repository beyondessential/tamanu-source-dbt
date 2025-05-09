select
    registration_date as "{{ translate_string('birthRegisteredDateTime', 'Registration date') }}",
    registered_by as "{{ translate_string('birthRegisteredBy', 'Registered by') }}",
    display_id as "{{ translate_string('patientDisplayId', 'Patient ID') }}",
    first_name as "{{ translate_string('patientFirstName', 'First name') }}",
    last_name as "{{ translate_string('patientLastName', 'Last name') }}",
    date_of_birth as "{{ translate_string('patientDateOfBirth', 'Date of birth') }}",
    sex as "{{ translate_string('patientSex', 'Sex') }}",
    ethnicity as "{{ translate_string('patientEthnicity', 'Ethnicity') }}",
    nationality as "{{ translate_string('patientNationality', 'Nationality') }}",
    village as "{{ translate_string('patientVillage', 'Village') }}",
    mother as "{{ translate_string('patientMother', 'Mother') }}",
    father as "{{ translate_string('patientFather', 'Father') }}",
    birth_time as "{{ translate_string('birthTimeOfBirth', 'Time of birth') }}",
    gestational_age_estimate as "{{ translate_string('birthGestationalAgeEstimate', 'Gestational age (weeks)') }}",
    registered_birth_place as "{{ translate_string('patientPlaceOfBirth', 'Place of birth') }}",
    birth_facility as "{{ translate_string('birthFacilityName', 'Name of health facility (if selected)') }}",
    attendant_at_birth as "{{ translate_string('birthAttendantType', 'Attendant at birth') }}",
    name_of_attendant_at_birth as "{{ translate_string('birthAttendant', 'Name of attendant') }}",
    birth_delivery_type as "{{ translate_string('birthDeliveryType', 'Delivery type') }}",
    birth_type as "{{ translate_string('birthType', 'Single/Plural birth') }}",
    birth_weight as "{{ translate_string('birthWeight', 'Birth weight (kg)') }}",
    birth_length as "{{ translate_string('birthLength', 'Birth length (cm)') }}",
    apgar_score_one_minute as "{{ translate_string('birthApgarScoreOneMinute', 'Apgar score at 1 min') }}",
    apgar_score_five_minutes as "{{ translate_string('birthApgarScoreFiveMinutes', 'Apgar score at 5 min') }}",
    apgar_score_ten_minutes as "{{ translate_string('birthApgarScoreTenMinutes', 'Apgar score at 10 min') }}"
from {{ ref("ds__births") }}
where
    case
        when {{ parameter('fromDate', default_value='2024-01-01', data_type='date') }} is null then true
        else date_of_birth::date >= {{ parameter('fromDate', default_value='2024-01-01', data_type='date') }}
    end
    and
    case
        when {{ parameter('toDate', default_value='2024-01-31', data_type='date') }} is null then true
        else date_of_birth::date <= {{ parameter('toDate', default_value='2024-01-31', data_type='date') }}
    end
    and
    case
        when {{ parameter('villageId') }} is null then true
        else village_id = {{ parameter('villageId') }}
    end
    and
    case
        when {{ parameter('facilityId') }} is null then true
        else birth_facility_id = {{ parameter('facilityId') }}
    end
