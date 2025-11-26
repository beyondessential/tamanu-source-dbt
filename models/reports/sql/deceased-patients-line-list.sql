select
    display_id as "{{ translate_label_from_seed('patientDisplayId') }}",
    first_name as "{{ translate_label_from_seed('patientFirstName') }}",
    last_name as "{{ translate_label_from_seed('patientLastName') }}",
    to_char(date_of_birth, '{{ var("date_format") }}') as "{{ translate_label_from_seed('patientDateOfBirth') }}",
    age as "{{ translate_label_from_seed('patientAge') }}",
    sex as "{{ translate_label_from_seed('patientSex') }}",
    village as "{{ translate_label_from_seed('patientVillage') }}",
    nationality as "{{ translate_label_from_seed('patientNationality') }}",
    place_of_death as "{{ translate_label_from_seed('deathPlaceOfDeath') }}",
    department as "{{ translate_label_from_seed('department') }}",
    location_group as "{{ translate_label_from_seed('locationGroup') }}",
    location as "{{ translate_label_from_seed('location') }}",
    to_char(date_of_death, '{{ var("date_format") }}') as "{{ translate_label_from_seed('patientDateOfDeath') }}",
    attending_clinician as "{{ translate_label_from_seed('deathAttendingClinician') }}",
    primary_cause_condition as "{{ translate_label_from_seed('deathPrimaryCause') }}",
    time_between_onset_and_death as "{{ translate_label_from_seed('deathTimeBetweenOnsetAndDeath') }}",
    antecedent_cause_1 as "{{ translate_label_from_seed('deathAntecedentCause1') }}",
    antecedent_cause_2 as "{{ translate_label_from_seed('deathAntecedentCause2') }}",
    other_condition_1 as "{{ translate_label_from_seed('deathOtherCondition1') }}",
    other_condition_2 as "{{ translate_label_from_seed('deathOtherCondition2') }}",
    other_condition_3 as "{{ translate_label_from_seed('deathOtherCondition3') }}",
    other_condition_4 as "{{ translate_label_from_seed('deathOtherCondition4') }}",
    had_recent_surgery as "{{ translate_label_from_seed('deathHadRecentSurgery') }}",
    to_char(last_surgery_date, '{{ var("date_format") }}') as "{{ translate_label_from_seed('deathLastSurgeryDate') }}",
    reason_for_surgery as "{{ translate_label_from_seed('deathReasonForSurgery') }}",
    manner_of_death as "{{ translate_label_from_seed('deathMannerOfDeath') }}",
    to_char(external_cause_date, '{{ var("date_format") }}') as "{{ translate_label_from_seed('deathExternalCauseDate') }}",
    external_cause_location as "{{ translate_label_from_seed('deathExternalCauseLocation') }}",
    was_pregnant as "{{ translate_label_from_seed('deathWasPregnant') }}",
    pregnancy_contributed as "{{ translate_label_from_seed('deathPregnancyContributed') }}",
    was_fetal_or_infant as "{{ translate_label_from_seed('deathWasFetalOrInfant') }}",
    was_stillborn as "{{ translate_label_from_seed('deathWasStillborn') }}",
    birth_weight as "{{ translate_label_from_seed('birthWeight') }}",
    completed_weeks_of_pregnancy as "{{ translate_label_from_seed('deathCompletedWeeksOfPregnancy') }}",
    age_of_mother as "{{ translate_label_from_seed('deathAgeOfMother') }}",
    condition_in_mother_affecting_fetus_or_newborn as "{{ translate_label_from_seed('deathConditionInMother') }}",
    death_within_day_of_birth as "{{ translate_label_from_seed('deathWithinDayOfBirth') }}",
    hours_survived_since_birth as "{{ translate_label_from_seed('deathHoursSurvivedSinceBirth') }}"
from {{ ref('ds__deaths') }}
where case
        when {{ parameter('fromDate', default_value='2024-01-01', data_type='date') }} is null
            then true
        else date_of_death >= {{ parameter('fromDate', default_value='2024-01-01', data_type='date') }}
    end
    and case
        when {{ parameter('toDate', default_value='2024-01-31', data_type='date') }} is null
            then true
        else date_of_death <= {{ parameter('toDate', default_value='2024-01-31', data_type='date') }}
    end
    and case
        when {{ parameter('causeOfDeath') }} is null
            then true
        else primary_cause_condition_id = {{ parameter('causeOfDeath') }}
    end
    and case
        when {{ parameter('mannerOfDeath') }} is null
            then true
        else manner_of_death = {{ parameter('mannerOfDeath') }}
    end
    and case
        when {{ parameter('facilityId') }} is null
            then true
        else facility_id = {{ parameter('facilityId') }}
    end
    and case
        when {{ parameter('antecedentCause') }} is null
            then true
        else antecedent_cause_1_id = {{ parameter('antecedentCause') }}
            or antecedent_cause_2_id = {{ parameter('antecedentCause') }}
    end
    and case
        when {{ parameter('otherContributingCondition') }} is null
            then true
        else other_condition_1_id = {{ parameter('otherContributingCondition') }}
            or other_condition_2_id = {{ parameter('otherContributingCondition') }}
            or other_condition_3_id = {{ parameter('otherContributingCondition') }}
            or other_condition_4_id = {{ parameter('otherContributingCondition') }}
    end
order by date_of_death
