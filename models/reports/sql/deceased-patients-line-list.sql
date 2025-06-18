select
    display_id as "{{ translate_label('patientDisplayId', 'Patient ID') }}",
    first_name as "{{ translate_label('patientFirstName', 'First name') }}",
    last_name as "{{ translate_label('patientLastName', 'Last name') }}",
    date_of_birth as "{{ translate_label('patientDateOfBirth', 'Date of birth') }}",
    age as "{{ translate_label('patientAge', 'Age') }}",
    sex as "{{ translate_label('patientSex', 'Sex') }}",
    village as "{{ translate_label('patientVillage', 'Village' ) }}",
    nationality as "{{ translate_label('patientNationality', 'Nationality') }}",
    place_of_death as "{{ translate_label('deathPlaceOfDeath', 'Place of death') }}",
    department as "{{ translate_label('department', 'Department') }}",
    location_group as "{{ translate_label('locationGroup', 'Area') }}",
    location as "{{ translate_label('location', 'Location') }}",
    date_of_death as "{{ translate_label('patientDateOfDeath','Date of death') }}",
    attending_clinician as "{{ translate_label('deathAttendingClinician', 'Attending clinician') }}",
    primary_cause_condition as "{{ translate_label('deathPrimaryCause', 'Primary cause of death') }}",
    time_between_onset_and_death as "{{ translate_label('deathTimeBetweenOnsetAndDeath', 'Time between onset and death') }}",
    antecedent_cause_1 as "{{ translate_label('deathAntecedentCause1', 'Antecedent cause 1') }}",
    antecedent_cause_2 as "{{ translate_label('deathAntecedentCause2', 'Antecedent cause 2') }}",
    other_condition_1 as "{{ translate_label('deathOtherCondition1', 'Other condition 1') }}",
    other_condition_2 as "{{ translate_label('deathOtherCondition2', 'Other condition 2') }}",
    other_condition_3 as "{{ translate_label('deathOtherCondition3', 'Other condition 3') }}",
    other_condition_4 as "{{ translate_label('deathOtherCondition4', 'Other condition 4') }}",
    had_recent_surgery as "{{ translate_label('deathHadRecentSurgery', 'Had recent surgery') }}",
    last_surgery_date as "{{ translate_label('deathLastSurgeryDate', 'Last surgery date') }}",
    reason_for_surgery as "{{ translate_label('deathReasonForSurgery', 'Reason for surgery') }}",
    manner_of_death as "{{ translate_label('deathMannerOfDeath', 'Manner of death') }}",
    external_cause_date as "{{ translate_label('deathExternalCauseDate', 'External cause date') }}",
    external_cause_location as "{{ translate_label('deathExternalCauseLocation', 'External cause location') }}",
    was_pregnant as "{{ translate_label('deathWasPregnant', 'Was pregnant') }}",
    pregnancy_contributed as "{{ translate_label('deathPregnancyContributed', 'Pregnancy contributed') }}",
    was_fetal_or_infant as "{{ translate_label('deathWasFetalOrInfant', 'Was fetal or infant') }}",
    was_stillborn as "{{ translate_label('deathWasStillborn', 'Was stillborn') }}",
    birth_weight as "{{ translate_label('birthWeight', 'Birth weight (kg)') }}",
    completed_weeks_of_pregnancy as "{{ translate_label('deathCompletedWeeksOfPregnancy', 'Completed weeks of pregnancy') }}",
    age_of_mother as "{{ translate_label('deathAgeOfMother', 'Age of mother') }}",
    condition_in_mother_affecting_fetus_or_newborn as "{{ translate_label('deathConditionInMother', 'Condition in mother affecting fetus or newborn') }}",
    death_within_day_of_birth as "{{ translate_label('deathWithinDayOfBirth', 'Death within day of birth') }}",
    hours_survived_since_birth as "{{ translate_label('deathHoursSurvivedSinceBirth', 'Hours survived since birth') }}"
from {{ ref('ds__deaths') }}
where case
        when {{ parameter('fromDate', default_value='2024-01-01', data_type='date') }} is null
            then true
        else date_of_death::date >= {{ parameter('fromDate', default_value='2024-01-01', data_type='date') }}
    end
    and case
        when {{ parameter('toDate', default_value='2024-01-31', data_type='date') }} is null
            then true
        else date_of_death::date <= {{ parameter('toDate', default_value='2024-01-31', data_type='date') }}
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
