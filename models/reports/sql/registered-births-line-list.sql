select
    to_char(registration_date, '{{ var("date_format") }}') as "{{ translate_label_from_seed('birthRegisteredDateTime') }}",
    registered_by as "{{ translate_label_from_seed('birthRegisteredBy') }}",
    display_id as "{{ translate_label_from_seed('patientDisplayId') }}",
    first_name as "{{ translate_label_from_seed('patientFirstName') }}",
    last_name as "{{ translate_label_from_seed('patientLastName') }}",
    to_char(date_of_birth, '{{ var("date_format") }}') as "{{ translate_label_from_seed('patientDateOfBirth') }}",
    sex as "{{ translate_label_from_seed('patientSex') }}",
    ethnicity as "{{ translate_label_from_seed('patientEthnicity') }}",
    nationality as "{{ translate_label_from_seed('patientNationality') }}",
    village as "{{ translate_label_from_seed('patientVillage') }}",
    mother as "{{ translate_label_from_seed('patientMother') }}",
    father as "{{ translate_label_from_seed('patientFather') }}",
    to_char(birth_time, '{{ var("time_format") }}') as "{{ translate_label_from_seed('birthTimeOfBirth') }}",
    gestational_age_estimate as "{{ translate_label_from_seed('birthGestationalAgeEstimate') }}",
    registered_birth_place as "{{ translate_label_from_seed('patientPlaceOfBirth') }}",
    birth_facility as "{{ translate_label_from_seed('birthFacility') }}",
    attendant_at_birth as "{{ translate_label_from_seed('birthAttendantType') }}",
    name_of_attendant_at_birth as "{{ translate_label_from_seed('birthAttendant') }}",
    birth_delivery_type as "{{ translate_label_from_seed('birthDeliveryType') }}",
    birth_type as "{{ translate_label_from_seed('birthType') }}",
    birth_weight as "{{ translate_label_from_seed('birthWeight') }}",
    birth_length as "{{ translate_label_from_seed('birthLength') }}",
    apgar_score_one_minute as "{{ translate_label_from_seed('birthApgarScoreOneMinute') }}",
    apgar_score_five_minutes as "{{ translate_label_from_seed('birthApgarScoreFiveMinutes') }}",
    apgar_score_ten_minutes as "{{ translate_label_from_seed('birthApgarScoreTenMinutes') }}"
from {{ ref("ds__births") }}
where
    case
        when {{ parameter('fromDate', default_value='2024-01-01', data_type='date') }} is null then true
        else date_of_birth >= {{ parameter('fromDate', default_value='2024-01-01', data_type='date') }}
    end
    and
    case
        when {{ parameter('toDate', default_value='2024-01-31', data_type='date') }} is null then true
        else date_of_birth <= {{ parameter('toDate', default_value='2024-01-31', data_type='date') }}
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
order by date_of_birth, birth_time
