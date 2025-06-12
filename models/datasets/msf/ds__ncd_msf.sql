with active_ncd_patients as (
    select 
        patient_id,
        max(datetime) as registration_datetime
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
latest_survey_data as (
    select 
        e.patient_id,
        max(case when sra.data_element_id = 'pde-NCDBase008' then sra.body end) as is_smoker,
        max(case when sra.data_element_id = 'pde-PatientVitalsDBP' then sra.body end) as dbp,
        max(case when sra.data_element_id = 'pde-PatientVitalsSBP' then sra.body end) as sbp,
        max(case when sra.data_element_id = 'pde-PatientVitalsBMI' then sra.body end) as bmi,
        max(case when sra.data_element_id = 'pde-PatientVitalsHeight' then sra.body end) as height,
        max(case when sra.data_element_id = 'pde-PatientVitalsWeight' then sra.body end) as weight,
        max(case when sra.data_element_id = 'pde-PatientVitalsBSLFasting' then sra.body end) as bsl_fasting,
        max(case when sra.data_element_id = 'pde-PatientVitalsBSLNonfast' then sra.body end) as bsl_nonfast
    from {{ ref('survey_responses') }} sr
    join {{ ref('encounters') }} e on e.id = sr.encounter_id
    join {{ ref('survey_response_answers') }} sra on sra.response_id = sr.id
    join active_ncd_patients anp on e.patient_id = anp.patient_id
    where sra.data_element_id = any(array[
        'pde-NCDBase008', 'pde-PatientVitalsDBP', 'pde-PatientVitalsSBP',
        'pde-PatientVitalsBMI', 'pde-PatientVitalsHeight', 'pde-PatientVitalsWeight',
        'pde-PatientVitalsBSLFasting', 'pde-PatientVitalsBSLNonfast'
    ])
    qualify row_number() over (
        partition by e.patient_id, sra.data_element_id 
        order by sr.start_datetime desc
    ) = 1
    group by e.patient_id
),
encounter_history as (
    select
        patient_id,
        array_agg(start_datetime order by start_datetime asc) as encounter_dates
    from (
        select 
            e.patient_id,
            e.start_datetime
        from {{ ref('encounters') }} e
        join active_ncd_patients anp 
            on e.patient_id = anp.patient_id 
            and e.start_datetime >= anp.registration_datetime
        where e.encounter_type = any(array['surveyResponse', 'clinic'])
        qualify row_number() over (
            partition by e.patient_id 
            order by e.start_datetime desc
        ) <= 38
    ) recent_encounters
    group by patient_id
),

-- Simplified appointment history
appointment_history as (
    select
        patient_id,
        array_agg(start_datetime order by start_datetime desc) as appointment_dates
    from (
        select 
            patient_id,
            start_datetime
        from {{ ref('outpatient_appointments') }} a
        join active_ncd_patients anp 
            on a.patient_id = anp.patient_id 
            and a.start_datetime >= anp.registration_datetime
        qualify row_number() over (
            partition by patient_id
            order by start_datetime desc
        ) <= 38
    ) recent_appointments
    group by patient_id
),

-- Combine reference data lookups to reduce joins
location_data as (
    select
        pd.patient_id,
        concat_ws(', ',
            nullif(d.name, ''),
            nullif(s.name, ''),
            nullif(t.name, ''),
            nullif(v.name, ''),
            nullif(pd.street_village, '')
        ) as full_address,
        concat_ws(', ',
            nullif(pd.primary_contact_number, ''),
            nullif(pd.secondary_contact_number, '')
        ) as contact_numbers,
        e.name as ethnicity
    from {{ ref('patient_additional_data')}} pd
    left join {{ ref('reference_data')}} d on d.id = pd.division_id
    left join {{ ref('reference_data')}} s on s.id = pd.subdivision_id
    left join {{ ref('reference_data')}} t on t.id = pd.settlement_id
    left join {{ ref('reference_data')}} v on v.id = pd.village_id
    left join {{ ref('reference_data')}} e on e.id = pd.ethnicity_id
)

-- Main query with optimized structure
select 
    p.id as patient_id,
    p.display_id,
    concat_ws(' ', nullif(p.first_name, ''), nullif(p.last_name, '')) as patient_name,
    p.cultural_name,
    ld.full_address as address,
    date_part('year', age(current_date, p.date_of_birth::date)) as age,
    p.sex,
    ld.contact_numbers as contact_number,
    pfv.value as current_status,
    sv.is_smoker,
    sv.weight,
    sv.height,
    sv.bmi,
    anp.registration_datetime as datetime,
    ld.ethnicity,
    case 
        when sv.dbp is not null and sv.sbp is not null 
        then concat_ws(' / ', sv.dbp, sv.sbp) 
    end as bp,
    coalesce(sv.bsl_fasting, sv.bsl_nonfast) as glu,
    
    -- Dynamic encounter columns (using array indexing for better performance)
    {% for i in range(1, 39) %}
    case when cardinality(eh.encounter_dates) >= {{ i }} 
         then eh.encounter_dates[{{ i }}] 
    end as last_visit_{{ i }}{% if not loop.last %},{% endif %}
    {% endfor %},
    
    -- Dynamic appointment columns
    {% for i in range(1, 39) %}
    case when cardinality(ah.appointment_dates) >= {{ i }} 
         then ah.appointment_dates[{{ i }}] 
    end as next_visit_{{ i }}{% if not loop.last %},{% endif %}
    {% endfor %}

from active_ncd_patients anp
join {{ ref('patients')}} p on anp.patient_id = p.id
left join location_data ld on p.id = ld.patient_id
left join {{ ref('patient_field_values')}} pfv 
    on pfv.patient_id = p.id 
    and pfv.definition_id = 'fieldCategory-currentstatus'
left join latest_survey_data sv on sv.patient_id = p.id
left join encounter_history eh on eh.patient_id = p.id
left join appointment_history ah on ah.patient_id = p.id