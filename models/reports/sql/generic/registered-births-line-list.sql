select
    registration_date as "{{ translate_label('birthRegisteredDateTime', 'Registration date') }}",
    registered_by as "{{ translate_label('birthRegisteredBy', 'Registered by') }}",
    display_id as "{{ translate_label('patientDisplayId', 'Patient ID') }}",
    first_name as "{{ translate_label('patientFirstName', 'First name') }}",
    last_name as "{{ translate_label('patientLastName', 'Last name') }}",
    date_of_birth as "{{ translate_label('patientDateOfBirth', 'Date of birth') }}",
    sex as "{{ translate_label('patientSex', 'Sex') }}",
    ethnicity as "{{ translate_label('patientEthnicity', 'Ethnicity') }}",
    nationality as "{{ translate_label('patientNationality', 'Nationality') }}",
    village as "{{ translate_label('patientVillage', 'Village') }}",
    mother as "{{ translate_label('patientMother', 'Mother') }}",
    father as "{{ translate_label('patientFather', 'Father') }}",
    birth_time as "{{ translate_label('birthTimeOfBirth', 'Time of birth') }}",
    gestational_age_estimate as "{{ translate_label('birthGestationalAgeEstimate', 'Gestational age (weeks)') }}",
    registered_birth_place as "{{ translate_label('patientPlaceOfBirth', 'Place of birth') }}",
    birth_facility as "{{ translate_label('birthFacilityName', 'Name of health facility (if selected)') }}",
    attendant_at_birth as "{{ translate_label('birthAttendantType', 'Attendant at birth') }}",
    name_of_attendant_at_birth as "{{ translate_label('birthAttendant', 'Name of attendant') }}",
    birth_delivery_type as "{{ translate_label('birthDeliveryType', 'Delivery type') }}",
    birth_type as "{{ translate_label('birthType', 'Single/Plural birth') }}",
    birth_weight as "{{ translate_label('birthWeight', 'Birth weight (kg)') }}",
    birth_length as "{{ translate_label('birthLength', 'Birth length (cm)') }}",
    apgar_score_one_minute as "{{ translate_label('birthApgarScoreOneMinute', 'Apgar score at 1 min') }}",
    apgar_score_five_minutes as "{{ translate_label('birthApgarScoreFiveMinutes', 'Apgar score at 5 min') }}",
    apgar_score_ten_minutes as "{{ translate_label('birthApgarScoreTenMinutes', 'Apgar score at 10 min') }}"
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
