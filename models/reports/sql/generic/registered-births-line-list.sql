select
    to_char(registration_date, '{{ var("date_format") }}') as "{{ translate_string('', 'Registration date') }}",
    registered_by as "{{ translate_string('', 'Registered by') }}",
    display_id as "{{ translate_string('general.localisedField.displayId.label', 'Patient ID') }}",
    first_name as "{{ translate_string('general.localisedField.firstName.label', 'First name') }}",
    last_name as "{{ translate_string('general.localisedField.lastName.label', 'Last name') }}",
    to_char(date_of_birth, '{{ var("date_format") }}') as "{{ translate_string('general.localisedField.dateOfBirth.label', 'Date of birth') }}",
    sex as "{{ translate_string('general.localisedField.sex.label', 'Sex') }}",
    ethnicity as "{{ translate_string('general.localisedField.ethnicityId.label', 'Ethnicity') }}",
    nationality as "{{ translate_string('general.localisedField.nationalityId.label', 'Nationality') }}",
    village as "{{ translate_string('general.localisedField.villageId.label', 'Village') }}",
    mother as "{{ translate_string('general.localisedField.motherId.label', 'Mother') }}",
    father as "{{ translate_string('general.localisedField.fatherId.label', 'Father') }}",
    birth_time as "{{ translate_string('general.localisedField.timeOfBirth.label', 'Time of birth') }}",
    gestational_age_estimate as "{{ translate_string('general.localisedField.gestationalAgeEstimate.label', 'Gestational age (weeks)') }}",
    registered_birth_place as "{{ translate_string('general.localisedField.registeredBirthPlace.label', 'Place of birth') }}",
    birth_facility as "{{ translate_string('general.localisedField.birthFacilityId.label', 'Name of health facility (if selected)') }}",
    attendant_at_birth as "{{ translate_string('general.localisedField.attendantAtBirth.label', 'Attendant at birth') }}",
    name_of_attendant_at_birth as "{{ translate_string('general.localisedField.nameOfAttendantAtBirth.label', 'Name of attendant') }}",
    birth_delivery_type as "{{ translate_string('general.localisedField.birthDeliveryType.label', 'Delivery type') }}",
    birth_type as "{{ translate_string('general.localisedField.birthType.label', 'Single/Plural birth') }}",
    birth_weight as "{{ translate_string('general.localisedField.birthWeight.label', 'Birth weight (kg)') }}",
    birth_length as "{{ translate_string('general.localisedField.birthLength.label', 'Birth length (cm)') }}",
    apgar_score_one_minute as "{{ translate_string('general.localisedField.apgarScoreOneMinute.label', 'Apgar score at 1 min') }}",
    apgar_score_five_minutes as "{{ translate_string('general.localisedField.apgarScoreFiveMinutes.label', 'Apgar score at 5 min') }}",
    apgar_score_ten_minutes as "{{ translate_string('general.localisedField.apgarScoreTenMinutes.label', 'Apgar score at 10 min') }}"
from {{ ref("ds__births") }}
where
    case
        when {{ parameter('fromDate', default_value='2024-01-01', data_type='date') }} is null then true
        else date_of_birth::date
            >= {{ parameter('fromDate', default_value='2024-01-01', data_type='date') }}
    end
    and
    case
        when {{ parameter('toDate', default_value='2024-01-31', data_type='date') }} is null then true
        else date_of_birth::date
            <= {{ parameter('toDate', default_value='2024-01-31', data_type='date') }}
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
