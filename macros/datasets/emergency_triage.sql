{% macro emergency_triage_dataset(is_sensitive=false) %}

{%- set triage_source = 'ds__sensitive_encounters_emergency' if is_sensitive else 'ds__encounters_emergency' -%}

-- BL-001: one row per triage record, which is one emergency department presentation
-- BL-015: the sensitive variant differs only in which emergency dataset it reads
with presentations as (
    select * from {{ ref(triage_source) }}
),

-- BL-011: the department the patient was triaged in, which is where the encounter began
triage_department as (
    select distinct on (eh.encounter_id)
        eh.encounter_id,
        eh.department_id
    from {{ ref('encounter_history') }} eh
    join presentations p on p.encounter_id = eh.encounter_id
    order by eh.encounter_id asc, eh.datetime asc
),

-- BL-006: diagnoses recorded against the presentation's encounter. bases/encounter_diagnoses
-- already drops disproven and recorded-in-error certainties
encounter_diagnoses_agg as (
    select
        ed.encounter_id,
        string_agg(distinct rd.name, ', ') as diagnoses
    from {{ ref('encounter_diagnoses') }} ed
    join presentations p on p.encounter_id = ed.encounter_id
    join {{ ref('reference_data') }} rd on rd.id = ed.diagnosis_id
    group by ed.encounter_id
),

-- BL-007: medications prescribed during the presentation's encounter
encounter_medications_agg as (
    select
        ep.encounter_id,
        string_agg(distinct med.name, ', ') as medications
    from {{ ref('encounter_prescriptions') }} ep
    join presentations p on p.encounter_id = ep.encounter_id
    join {{ ref('prescriptions') }} pr on pr.id = ep.prescription_id
    join {{ ref('reference_data') }} med on med.id = pr.medication_id
    group by ep.encounter_id
),

presentation_details as (
    select
        p.triage_id,
        p.encounter_id,
        p.patient_id,
        p.display_id,
        p.first_name,
        p.last_name,
        p.sex,
        p.village_id,
        p.village,
        p.date_of_birth,
        -- BL-002: age as at the time of triage, not today
        date_part('year', age(p.triage_datetime, p.date_of_birth))::integer as age,
        p.facility_id,
        -- BL-011: fall back to the encounter's department when it has no history
        coalesce(td.department_id, e.department_id) as department_id,
        p.arrival_datetime,
        p.arrival_mode,
        p.triage_datetime,
        p.score,
        -- BL-003: the triage score is presented using Tamanu's category wording
        'Category ' || p.score as triage_category,
        p.chief_complaint,
        p.secondary_complaint,
        p.clinician_id,
        p.clinician,
        dx.diagnoses,
        rx.medications,
        -- BL-004: active care starts when the triage is closed
        p.closed_datetime as active_care_datetime,
        e.encounter_type,
        -- BL-009: OMOP visit concept 262 is 'Emergency Room and Inpatient Visit', which
        -- clinical__visit_occurrence assigns to an admission that passed through an
        -- emergency, triage or observation phase
        vo.visit_concept_id = 262 as is_admitted_from_ed,
        e.end_datetime as discharge_datetime,
        dis.disposition_id as discharge_disposition_id,
        disposition.name as discharge_disposition
    from presentations p
    join {{ ref('encounters') }} e on e.id = p.encounter_id
    left join {{ ref('clinical__visit_occurrence') }} vo on vo.visit_occurrence_id = p.encounter_id
    left join triage_department td on td.encounter_id = p.encounter_id
    left join encounter_diagnoses_agg dx on dx.encounter_id = p.encounter_id
    left join encounter_medications_agg rx on rx.encounter_id = p.encounter_id
    left join {{ ref('discharges') }} dis on dis.encounter_id = p.encounter_id
    left join {{ ref('reference_data') }} disposition on disposition.id = dis.disposition_id
),

timings as (
    select
        pd.*,
        -- BL-005: waiting time is triage to the start of active care
        -- BL-013: a time recorded before the triage is unusable, so the duration is left empty
        case
            when pd.active_care_datetime < pd.triage_datetime then null
            else extract(epoch from (pd.active_care_datetime - pd.triage_datetime))::bigint
        end as waiting_time_seconds,
        -- BL-010: total length of stay is triage to discharge
        -- BL-013: a time recorded before the triage is unusable, so the duration is left empty
        case
            when pd.discharge_datetime < pd.triage_datetime then null
            else extract(epoch from (pd.discharge_datetime - pd.triage_datetime))::bigint
        end as length_of_stay_seconds,
        -- BL-008: target waiting time by triage category, blank where the map has no entry
        {{ triage_target_minutes_case('pd.score') }} as target_wait_minutes,
        -- BL-009: admitted or discharged only. A presentation that ended in death is not a
        -- third outcome -- discharge_disposition carries that, and the two signals Tamanu
        -- offers for it (the disposition, and patients.date_of_death falling inside the
        -- encounter) do not agree well enough to derive an outcome from
        case
            when pd.is_admitted_from_ed then 'Admitted'
            when pd.discharge_datetime is not null then 'Discharged'
        end as ed_outcome
    from presentation_details pd
)

select
    t.triage_id,
    t.encounter_id,
    t.patient_id,
    t.display_id,
    t.first_name,
    t.last_name,
    t.sex,
    t.village_id,
    t.village,
    t.date_of_birth,
    t.age,
    t.facility_id,
    t.department_id,
    t.arrival_datetime,
    t.arrival_mode,
    t.triage_datetime,
    t.score,
    t.triage_category,
    t.chief_complaint,
    t.secondary_complaint,
    t.clinician_id,
    t.clinician,
    t.diagnoses,
    t.medications,
    t.active_care_datetime,
    t.waiting_time_seconds,
    t.target_wait_minutes,
    t.encounter_type,
    t.is_admitted_from_ed,
    t.ed_outcome,
    t.discharge_disposition_id,
    t.discharge_disposition,
    t.discharge_datetime,
    t.length_of_stay_seconds,
    -- BL-008: no verdict until the patient has been seen and the category has a target
    case
        when t.waiting_time_seconds is null or t.target_wait_minutes is null then null
        when t.waiting_time_seconds <= t.target_wait_minutes * 60 then 'Yes'
        else 'No'
    end as target_time_met
from timings t

{% endmacro %}
