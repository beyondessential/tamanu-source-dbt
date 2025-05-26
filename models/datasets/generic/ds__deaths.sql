with contributing_death_causes as (
    select
        cdc.patient_death_data_id,
        array_agg(cdc.condition_id order by cdc.created_at) as other_conditions
    from {{ ref("contributing_death_causes") }} cdc
    group by cdc.patient_death_data_id
),

encounters_with_death as (
    select distinct on (e.patient_id)
        e.patient_id,
        e.start_date,
        e.end_date,
        e.location_id,
        e.department_id,
        e.clinician_id
    from {{ ref("encounters") }} e
    join {{ ref("patients") }} p 
        on p.id = e.patient_id
        and p.date_of_death between e.start_datetime and e.end_datetime
    order by e.patient_id, e.end_datetime desc
)

select
    p.id as patient_id,
    p.display_id,
    p.first_name,
    p.last_name,
    p.date_of_birth,
    date_part('year', age(pdi.date_of_death::date, pdi.date_of_birth::date)) as age,
    p.sex,
    village.id as village_id,
    village.name as village,
    nationality.id as nationality_id,
    nationality.name as nationality,
    coalesce(
        case when pdi.outside_health_facility then 'Died outside health facility' else f.name end,
        'Unknown'
    ) as place_of_death,
    department.id as department_id,
    department.name as department,
    location_group.id as location_group_id,
    location_group.name as location_group,
    location.id as location_id,
    location.name as location,
    p.date_of_death,
    clinician.id as attending_clinician_id,
    clinician.display_name as attending_clinician,
    primary_condition.id as primary_cause_condition_id,
    primary_condition.name as primary_cause_condition,
    case
        when pdd.primary_cause_time_after_onset is null or pdd.primary_cause_time_after_onset = 0 
            then '0 minutes'
        when mod(pdd.primary_cause_time_after_onset, (60 * 24 * 365)) = 0 
            then concat(pdd.primary_cause_time_after_onset / (60 * 24 * 365), ' years')
        when mod(pdd.primary_cause_time_after_onset, (60 * 24 * 30)) = 0 
            then concat(pdd.primary_cause_time_after_onset / (60 * 24 * 30), ' months')
        when mod(pdd.primary_cause_time_after_onset, (60 * 24 * 7)) = 0 
            then concat(pdd.primary_cause_time_after_onset / (60 * 24 * 7), ' weeks')
        when mod(pdd.primary_cause_time_after_onset, (60 * 24)) = 0 
            then concat(pdd.primary_cause_time_after_onset / (60 * 24), ' days')
        when mod(pdd.primary_cause_time_after_onset, 60) = 0 
            then concat(pdd.primary_cause_time_after_onset / 60, ' hours')
        else concat(pdd.primary_cause_time_after_onset, ' minutes')
    end as time_between_onset_and_death,
    antecedent_condition_1.id as antecedent_cause_1_id,
    antecedent_condition_1.name as antecedent_cause_1,
    antecedent_condition_2.id as antecedent_cause_2_id,
    antecedent_condition_2.name as antecedent_cause_2,
    other_condition_1.id as other_condition_1_id,
    other_condition_1.name as other_condition_1,
    other_condition_2.id as other_condition_2_id,
    other_condition_2.name as other_condition_2,
    other_condition_3.id as other_condition_3_id,
    other_condition_3.name as other_condition_3,
    other_condition_4.id as other_condition_4_id,
    other_condition_4.name as other_condition_4,
    initcap(pdd.had_recent_surgery) as had_recent_surgery,
    pdd.last_surgery_date,
    surgery_reason.id as reason_for_surgery_id,
    surgery_reason.name as reason_for_surgery,
    pdd.manner as manner_of_death,
    pdd.external_cause_date,
    pdd.external_cause_location,
    initcap(pdd.was_pregnant) as was_pregnant,
    pdd.pregnancy_contributed,
    case
        when pdd.was_fetal_or_infant then 'Yes'
        else 'No'
    end as was_fetal_or_infant,
    initcap(pdd.was_stillborn) as was_stillborn,
    pdd.birth_weight,
    pdd.carrier_pregnancy_weeks as completed_weeks_of_pregnancy,
    pdi.carrier_age as age_of_mother,
    carrier_condition.name as condition_in_mother_affecting_fetus_or_newborn,
    case
        when pdd.within_day_of_birth then 'Yes'
        else 'No'
    end as death_within_day_of_birth,
    pdi.hours_survived_since_birth
from {{ ref("patient_death_data") }} pdd
join {{ ref("patients") }} p 
    on p.id = pdd.patient_id
left join {{ ref("patient_additional_data") }} pd 
    on pd.patient_id = p.id
left join {{ ref("reference_data") }} village 
    on village.id = p.village_id
left join {{ ref("reference_data") }} nationality 
    on nationality.id = pd.nationality_id
left join {{ ref("reference_data") }} primary_condition 
    on primary_condition.id = pdd.primary_cause_condition_id
left join {{ ref("reference_data") }} antecedent_condition_1 
    on antecedent_condition_1.id = pdd.antecedent_cause1_condition_id
left join {{ ref("reference_data") }} antecedent_condition_2 
    on antecedent_condition_2.id = pdd.antecedent_cause2_condition_id
left join contributing_death_causes cdc 
    on cdc.patient_death_data_id = pdd.id
left join {{ ref("reference_data") }} other_condition_1 
    on other_condition_1.id = cdc.other_conditions[1]
left join {{ ref("reference_data") }} other_condition_2 
    on other_condition_2.id = cdc.other_conditions[2]
left join {{ ref("reference_data") }} other_condition_3 
    on other_condition_3.id = cdc.other_conditions[3]
left join {{ ref("reference_data") }} other_condition_4 
    on other_condition_4.id = cdc.other_conditions[4]
left join {{ ref("reference_data") }} surgery_reason 
    on surgery_reason.id = pdd.last_surgery_reason_id
left join {{ ref("reference_data") }} carrier_condition 
    on carrier_condition.id = pdd.carrier_existing_condition_id
left join encounters_with_death ewd 
    on ewd.patient_id = p.id
left join {{ ref("departments") }} department 
    on department.id = ewd.department_id
left join {{ ref("locations") }} location 
    on location.id = ewd.location_id
left join {{ ref("location_groups") }} location_group 
    on location_group.id = location.location_group_id
left join {{ ref("users") }} clinician 
    on clinician.id = pdd.recorded_by_id
order by pdd.date_of_death
