with active_ncd_patients as (
    select 
        patient_id,
        max(datetime) as datetime
    from (
        select 
            patient_id,
            clinical_status_id,
            datetime,
            lag(clinical_status_id) over (
                partition by patient_id 
                order by datetime
            ) as previous_status
        from {{ ref('patient_program_registrations')}}
        where program_registry_id = 'programRegistry-activeregistry'
            and registration_status = 'active'
    ) status_changes
    where clinical_status_id = 'prClinicalStatus-ncdactive'
        and (previous_status is null or previous_status != 'prClinicalStatus-ncdactive')
    group by patient_id
),

all_ncd_patients as (
    select 
        ppr.patient_id,
        coalesce(anp.datetime, ppr.datetime) as datetime,
        prcs.name as patient_status
    from {{ ref('patient_program_registrations')}} ppr
    join {{ ref('program_registry_clinical_statuses') }} prcs on prcs.id = ppr.clinical_status_id
    left join active_ncd_patients anp on anp.patient_id = ppr.patient_id
    where ppr.program_registry_id = 'programRegistry-activeregistry'
        and ppr.registration_status = 'active'
        and ppr.is_most_recent = true
),

latest_survey_data as (
    select 
        patient_id,
        max(case when data_element_id = 'pde-NCDBase008' then body end) as is_smoker,
        max(case when data_element_id = 'pde-PatientVitalsDBP' then body end) as dbp,
        max(case when data_element_id = 'pde-PatientVitalsSBP' then body end) as sbp,
        max(case when data_element_id = 'pde-PatientVitalsBMI' then body end) as bmi,
        max(case when data_element_id = 'pde-PatientVitalsHeight' then body end) as height,
        max(case when data_element_id = 'pde-PatientVitalsWeight' then body end) as weight,
        max(case when data_element_id = 'pde-PatientVitalsBSLFasting' then body end) as bsl_fasting,
        max(case when data_element_id = 'pde-PatientVitalsBSLNonfast' then body end) as bsl_nonfast,
        max(case when data_element_id = 'pde-ExiSur001' then body end) as date_of_discharge,
        max(case when data_element_id = 'pde-ExiSur002' then body end) as reason_for_discharge,
        max(case when data_element_id in (
            'pde-ExiSur003', 'pde-ExiSur004', 'pde-ExiSur005', 
            'pde-ExiSur006', 'pde-ExiSur007'
        ) then body end) as explanation_for_discharge
    from (
        select 
            e.patient_id,
            sra.data_element_id,
            sra.body,
            row_number() over (
                partition by e.patient_id, sra.data_element_id 
                order by sr.start_datetime desc
            ) as rn
        from {{ ref('survey_responses') }} sr
        join {{ ref('encounters') }} e on e.id = sr.encounter_id
        join {{ ref('survey_response_answers') }} sra on sra.response_id = sr.id
        join all_ncd_patients anp on anp.patient_id = e.patient_id
        where sra.data_element_id = any(array[
            'pde-NCDBase008', 'pde-PatientVitalsDBP', 'pde-PatientVitalsSBP',
            'pde-PatientVitalsBMI', 'pde-PatientVitalsHeight', 'pde-PatientVitalsWeight',
            'pde-PatientVitalsBSLFasting', 'pde-PatientVitalsBSLNonfast', 'pde-ExiSur001',
            'pde-ExiSur002', 'pde-ExiSur003', 'pde-ExiSur004', 'pde-ExiSur005', 
            'pde-ExiSur006', 'pde-ExiSur007'
        ])
    ) ranked_survey_data
    where rn = 1
    group by patient_id
),

encounter_history as (
    select
        patient_id,
        array_agg(start_datetime order by start_datetime asc) as encounter_dates
    from (
        select 
            e.patient_id,
            e.start_datetime,
            row_number() over (
                partition by e.patient_id 
                order by e.start_datetime desc
            ) as rn
        from {{ ref('encounters') }} e
        join all_ncd_patients anp
            on e.patient_id = anp.patient_id 
            and e.start_datetime >= anp.datetime
        where e.encounter_type = any(array['surveyResponse', 'clinic'])
    ) recent_encounters
    where rn <= 38
    group by patient_id
),

appointment_history as (
    select
        patient_id,
        array_agg(start_datetime order by start_datetime asc) as appointment_dates
    from (
        select 
            patient_id,
            start_datetime,
            row_number() over (
                partition by patient_id
                order by start_datetime desc
            ) as rn
        from (
            select distinct
                e.patient_id,
                first_value(a.start_datetime) over (
                    partition by e.patient_id, e.start_datetime
                    order by a.start_datetime desc
                ) as start_datetime
            from {{ ref('outpatient_appointments') }} a
            join all_ncd_patients anp 
                on a.patient_id = anp.patient_id 
                and a.start_datetime >= anp.datetime
            join (
                select 
                    patient_id,
                    start_datetime,
                    lead(start_datetime) over (
                        partition by patient_id 
                        order by start_datetime
                    ) as next_encounter_datetime
                from {{ ref('encounters') }}
                where encounter_type = any(array['surveyResponse', 'clinic'])
            ) e
                on e.patient_id = a.patient_id 
                and a.start_datetime > e.start_datetime
                and (
                    a.start_datetime <= e.next_encounter_datetime
                    or e.next_encounter_datetime is null
                )
        ) last_appointments
    ) ranked_appointments
    where rn <= 38
    group by patient_id
)

select 
    p.id as patient_id,
    p.display_id,
    concat_ws(' ', nullif(p.first_name, ''), nullif(p.last_name, '')) as patient_name,
    p.cultural_name,
    concat_ws(', ',
        nullif(d.name, ''),
        nullif(s.name, ''),
        nullif(t.name, ''),
        nullif(v.name, ''),
        nullif(pd.street_village, '')
    ) as address,
    date_part('year', age(current_date, p.date_of_birth::date)) as age,
    p.sex,
    concat_ws(', ',
        nullif(pd.primary_contact_number, ''),
        nullif(pd.secondary_contact_number, '')
    ) as contact_number,
    pfv.value as current_status,
    sv.is_smoker,
    sv.weight,
    sv.height,
    sv.bmi,
    anp.datetime,
    e.name as ethnicity,
    concat_ws(' / ', nullif(sv.dbp, ''), nullif(sv.sbp, '')) as bp,
    coalesce(sv.bsl_fasting, sv.bsl_nonfast) as glu,
    {% for i in range(1, 39) %}
    case when cardinality(eh.encounter_dates) >= {{ i }} 
         then eh.encounter_dates[{{ i }}] 
    end as last_visit_{{ i }},
    case when cardinality(ah.appointment_dates) >= {{ i }} 
         then ah.appointment_dates[{{ i }}] 
    end as next_visit_{{ i }}
    {% if not loop.last %},{% endif %}
    {% endfor %},
    case when cardinality(eh.encounter_dates) > 0 
         then eh.encounter_dates[cardinality(eh.encounter_dates)] 
    end as max_visit,
    coalesce(cardinality(eh.encounter_dates), 0) as no_visits,
    case when cardinality(ah.appointment_dates) > 0 
         and ah.appointment_dates[cardinality(ah.appointment_dates)] > eh.encounter_dates[cardinality(eh.encounter_dates)]
         then current_date - ah.appointment_dates[cardinality(ah.appointment_dates)]::date 
    end as time_since_next_planned_appointment,
    sv.date_of_discharge,
    sv.reason_for_discharge,
    sv.explanation_for_discharge,
    case 
        when cardinality(ah.appointment_dates) > 0 
             and ah.appointment_dates[cardinality(ah.appointment_dates)] > eh.encounter_dates[cardinality(eh.encounter_dates)]
             then
                case 
                    when current_date - ah.appointment_dates[cardinality(ah.appointment_dates)]::date between 7 and 30 then 'Call'
                    when current_date - ah.appointment_dates[cardinality(ah.appointment_dates)]::date between 31 and 45 then 'Visit'
                    when current_date - ah.appointment_dates[cardinality(ah.appointment_dates)]::date between 46 and 60 then 'Call2'
                    when current_date - ah.appointment_dates[cardinality(ah.appointment_dates)]::date > 60 then 'Defaulter'
                end
    end as tracing_status,
    anp.patient_status
from all_ncd_patients anp
join {{ ref('patients')}} p on anp.patient_id = p.id
left join {{ ref('patient_additional_data')}} pd on pd.patient_id = p.id
left join {{ ref('reference_data')}} d on d.id = pd.division_id
left join {{ ref('reference_data')}} s on s.id = pd.subdivision_id
left join {{ ref('reference_data')}} t on t.id = pd.settlement_id
left join {{ ref('reference_data')}} v on v.id = p.village_id
left join {{ ref('reference_data')}} e on e.id = pd.ethnicity_id
left join {{ ref('patient_field_values')}} pfv 
    on pfv.patient_id = p.id 
    and pfv.definition_id = 'fieldCategory-currentstatus'
left join latest_survey_data sv on sv.patient_id = p.id
left join encounter_history eh on eh.patient_id = p.id
left join appointment_history ah on ah.patient_id = p.id