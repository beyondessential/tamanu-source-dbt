select
    display_id as "{{ translate_label('patientDisplayId') }}",
    first_name as "{{ translate_label('patientFirstName') }}",
    last_name as "{{ translate_label('patientLastName') }}",
    to_char(date_of_birth, '{{ var("date_format") }}') as "{{ translate_label('patientDateOfBirth') }}",
    age as "{{ translate_label('patientAge') }}",
    sex as "{{ translate_label('patientSex') }}",
    village as "{{ translate_label('patientVillage') }}",
    nationality as "{{ translate_label('patientNationality') }}",
    place_of_death as "{{ translate_label('deathPlaceOfDeath') }}",
    department as "{{ translate_label('department') }}",
    location_group as "{{ translate_label('locationGroup') }}",
    location as "{{ translate_label('location') }}",
    to_char(date_of_death, '{{ var("date_format") }}') as "{{ translate_label('patientDateOfDeath') }}",
    attending_clinician as "{{ translate_label('deathAttendingClinician') }}",
    primary_cause_condition as "{{ translate_label('deathPrimaryCause') }}",
    time_between_onset_and_death as "{{ translate_label('deathTimeBetweenOnsetAndDeath') }}",
    antecedent_cause_1 as "{{ translate_label('deathAntecedentCause1') }}",
    antecedent_cause_2 as "{{ translate_label('deathAntecedentCause2') }}",
    other_condition_1 as "{{ translate_label('deathOtherCondition1') }}",
    other_condition_2 as "{{ translate_label('deathOtherCondition2') }}",
    other_condition_3 as "{{ translate_label('deathOtherCondition3') }}",
    other_condition_4 as "{{ translate_label('deathOtherCondition4') }}",
    had_recent_surgery as "{{ translate_label('deathHadRecentSurgery') }}",
    to_char(last_surgery_date, '{{ var("date_format") }}') as "{{ translate_label('deathLastSurgeryDate') }}",
    reason_for_surgery as "{{ translate_label('deathReasonForSurgery') }}",
    manner_of_death as "{{ translate_label('deathMannerOfDeath') }}",
    to_char(external_cause_date, '{{ var("date_format") }}') as "{{ translate_label('deathExternalCauseDate') }}",
    external_cause_location as "{{ translate_label('deathExternalCauseLocation') }}",
    was_pregnant as "{{ translate_label('deathWasPregnant') }}",
    pregnancy_contributed as "{{ translate_label('deathPregnancyContributed') }}",
    was_fetal_or_infant as "{{ translate_label('deathWasFetalOrInfant') }}",
    was_stillborn as "{{ translate_label('deathWasStillborn') }}",
    birth_weight as "{{ translate_label('birthWeight') }}",
    completed_weeks_of_pregnancy as "{{ translate_label('deathCompletedWeeksOfPregnancy') }}",
    age_of_mother as "{{ translate_label('deathAgeOfMother') }}",
    condition_in_mother_affecting_fetus_or_newborn as "{{ translate_label('deathConditionInMother') }}",
    death_within_day_of_birth as "{{ translate_label('deathWithinDayOfBirth') }}",
    hours_survived_since_birth as "{{ translate_label('deathHoursSurvivedSinceBirth') }}"
from {{ ref('ds__deaths') }}
-- BL-001: treat the "all time" sentinel (1970-01-01) as unbounded so migrated
-- records with an unknown date of death (placeholder 1900-01-01) are not excluded
where case
        when {{ parameter('fromDate', default_value='2024-01-01', data_type='date') }}::date <= '1970-01-01'::date
            then true
        else date_of_death >= {{ parameter('fromDate', default_value='2024-01-01', data_type='date') }}
    end
    and date_of_death <= {{ parameter('toDate', default_value='2024-01-31', data_type='date') }}
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
        when {{ parameter('locationGroupId') }} is null
            then true
        else location_group_id = {{ parameter('locationGroupId') }}
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
