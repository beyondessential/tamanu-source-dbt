-- Emergency Department admissions with individual diagnosis rows
-- Each diagnosis appears as a separate row with diagnosis name and ICD-10 code in separate columns
with admission_encounters as (
    select
        e.id as encounter_id,
        e.patient_id,
        e.start_datetime as admission_datetime,
        e.end_datetime as discharge_datetime,
        e.location_id,
        e.patient_billing_type_id,
        f.id as facility_id,
        f.name as facility_name,
        e.department_id
    from {{ ref('encounters') }} e
    join {{ ref('locations') }} l on l.id = e.location_id
    join {{ ref('facilities') }} f on f.id = l.facility_id
    where e.encounter_type = 'admission'
),

-- Get department history to find encounters that were in Emergency Department
department_history as (
    select distinct
        eh.encounter_id,
        d.id as department_id,
        d.name as department_name
    from {{ ref('encounter_history') }} eh
    join {{ ref('departments') }} d on d.id = eh.department_id
    where eh.encounter_type = 'admission'
),

-- Get location group (area) history
location_group_history as (
    select
        eh.encounter_id,
        string_agg(distinct lg.name, '; ' order by lg.name) as areas,
        array_agg(distinct lg.id) as area_ids
    from {{ ref('encounter_history') }} eh
    join {{ ref('locations') }} l on l.id = eh.location_id
    left join {{ ref('location_groups') }} lg on lg.id = l.location_group_id
    where eh.encounter_type = 'admission'
    group by eh.encounter_id
),

-- Get admitting clinician
admitting_clinician_cte as (
    select
        eh.encounter_id,
        u.display_name as admitting_clinician,
        u.id as admitting_clinician_id,
        row_number() over (partition by eh.encounter_id order by eh.datetime) as rn
    from {{ ref('encounter_history') }} eh
    left join {{ ref('users') }} u on u.id = eh.clinician_id
    where eh.encounter_type = 'admission'
        and (eh.change_type is null or 'encounter_type' = any(eh.change_type) or 'examiner' = any(eh.change_type))
),

admitting_clinician as (
    select
        encounter_id,
        admitting_clinician,
        admitting_clinician_id
    from admitting_clinician_cte
    where rn = 1
),

-- Get patient data
patient_data as (
    select
        ae.encounter_id,
        ae.patient_id,
        p.display_id,
        p.first_name,
        p.last_name,
        p.date_of_birth,
        initcap(p.sex::text) as sex,
        date_part('year', age(ae.admission_datetime, p.date_of_birth)) as age,
        case
            when date_part('year', age(ae.admission_datetime, p.date_of_birth)) < 1 then '<1'
            when date_part('year', age(ae.admission_datetime, p.date_of_birth)) between 1 and 4 then '1-4'
            when date_part('year', age(ae.admission_datetime, p.date_of_birth)) between 5 and 14 then '5-14'
            when date_part('year', age(ae.admission_datetime, p.date_of_birth)) between 15 and 24 then '15-24'
            when date_part('year', age(ae.admission_datetime, p.date_of_birth)) between 25 and 34 then '25-34'
            when date_part('year', age(ae.admission_datetime, p.date_of_birth)) between 35 and 44 then '35-44'
            when date_part('year', age(ae.admission_datetime, p.date_of_birth)) between 45 and 54 then '45-54'
            when date_part('year', age(ae.admission_datetime, p.date_of_birth)) between 55 and 64 then '55-64'
            when date_part('year', age(ae.admission_datetime, p.date_of_birth)) >= 65 then '65+'
        end as age_group,
        village.name as village,
        bt.name as billing_type,
        ae.admission_datetime,
        ae.discharge_datetime,
        case
            when ae.discharge_datetime is null then 'active'
            else 'discharged'
        end as admission_status,
        ae.facility_id,
        ae.facility_name
    from admission_encounters ae
    left join {{ ref('patients') }} p on p.id = ae.patient_id
    left join {{ ref('reference_data') }} village on village.id = p.village_id
    left join {{ ref('reference_data') }} bt on bt.id = ae.patient_billing_type_id
),

-- Get diagnoses with separate name and code columns
encounter_diagnoses_detail as (
    select
        ed.encounter_id,
        rd.name as diagnosis_name,
        rd.code as icd10_code,
        case when ed.is_primary then 'Primary' else 'Secondary' end as diagnosis_type,
        ed.certainty,
        ed.datetime as diagnosis_datetime,
        row_number() over (partition by ed.encounter_id order by ed.is_primary desc, ed.datetime) as diagnosis_sequence
    from admission_encounters ae
    inner join {{ ref('encounter_diagnoses') }} ed on ed.encounter_id = ae.encounter_id
    inner join {{ ref('reference_data') }} rd on rd.id = ed.diagnosis_id
    where ed.certainty not in ('disproven', 'error')
)

select
    pd.display_id as "{{ translate_label('patientDisplayId') }}",
    pd.first_name as "{{ translate_label('patientFirstName') }}",
    pd.last_name as "{{ translate_label('patientLastName') }}",
    to_char(pd.date_of_birth, '{{ var("date_format") }}') as "{{ translate_label('patientDateOfBirth') }}",
    pd.age as "{{ translate_label('patientAge') }}",
    pd.age_group as "{{ translate_label('patientAgeGroup') }}",
    pd.sex as "{{ translate_label('patientSex') }}",
    pd.village as "{{ translate_label('patientVillage') }}",
    pd.billing_type as "{{ translate_label('patientBillingType') }}",
    ac.admitting_clinician as "{{ translate_label('admittingClinician') }}",
    to_char({{ to_user_selected_timezone('pd.admission_datetime') }}, '{{ var("datetime_format") }}') as "{{ translate_label('admissionDateTime') }}",
    pd.admission_status as "{{ translate_label('admissionStatus') }}",
    to_char({{ to_user_selected_timezone('pd.discharge_datetime') }}, '{{ var("datetime_format") }}') as "{{ translate_label('dischargeDateTime') }}",
    pd.facility_name as "{{ translate_label('facility') }}",
    dh.department_name as "{{ translate_label('department') }}",
    lgh.areas as "{{ translate_label('encounterLocationGroupHistory') }}",
    edd.diagnosis_name as "{{ translate_label('diagnosisName') }}",
    edd.icd10_code as "{{ translate_label('diagnosisICD10Code') }}",
    edd.diagnosis_type as "{{ translate_label('diagnosisType') }}",
    edd.certainty as "{{ translate_label('diagnosisCertainty') }}",
    to_char({{ to_user_selected_timezone('edd.diagnosis_datetime') }}, '{{ var("datetime_format") }}') as "{{ translate_label('diagnosisDateTime') }}"
from patient_data pd
left join admitting_clinician ac on ac.encounter_id = pd.encounter_id
left join department_history dh on dh.encounter_id = pd.encounter_id
left join location_group_history lgh on lgh.encounter_id = pd.encounter_id
left join encounter_diagnoses_detail edd on edd.encounter_id = pd.encounter_id
where
    {{ to_user_selected_timezone('pd.admission_datetime') }} >= {{ parameter('fromDate', default_value='2026-01-01', data_type='date') }}
    and {{ to_user_selected_timezone('pd.admission_datetime') }} <= {{ parameter('toDate', default_value='2026-04-30', data_type='date') }}
    and case when {{ parameter('facilityId') }} is null then true
        else {{ parameter('facilityId') }} = pd.facility_id
    end
    and case when {{ parameter('departmentId') }} is null then true
        else {{ parameter('departmentId') }} = dh.department_id
    end
    and case when {{ parameter('locationGroupId') }} is null then true
        else {{ parameter('locationGroupId') }} = any(lgh.area_ids::text [])
    end
    and case when {{ parameter('patientBillingTypeId') }} is null then true
        else pd.billing_type like {{ parameter('patientBillingTypeId') }}
    end
    and case when {{ parameter('clinicianId') }} is null then true
        else ac.admitting_clinician_id = {{ parameter('clinicianId') }}
    end
    and case when coalesce({{ parameter('admissionStatus') }}) is null then true
        else pd.admission_status in ({{ parameter('admissionStatus') }})
    end
    and case when {{ parameter('diagnosisType') }} is null then true
        else edd.diagnosis_type = {{ parameter('diagnosisType') }}
    end
order by pd.admission_datetime desc, edd.diagnosis_sequence
