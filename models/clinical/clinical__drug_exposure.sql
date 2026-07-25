-- clinical__drug_exposure -- OMOP-lite DRUG_EXPOSURE domain. One row per drug exposure,
-- unioning three standard sources: medication prescriptions (BL-006), vaccine
-- administrations with status = 'GIVEN' (BL-007), and pharmacy dispenses (BL-008). Drug
-- identity retained as source value; FK graph wired from the encounter (BL-002);
-- *_concept_id (RxNorm/CVX) deferred to the future vocab__ layer (BL-003). Sources only
-- from bases/ (D10). Deployment-specific drug sources are added by per-deployment override
-- (see spec). See spec for BL-001..BL-008.

with prescriptions as (
    select * from {{ ref('prescriptions') }}
),

encounter_prescriptions as (
    select * from {{ ref('encounter_prescriptions') }}
),

reference_data as (
    select * from {{ ref('reference_data') }}
),

vaccine_administrations as (
    select * from {{ ref('vaccine_administrations') }}
),

vaccine_schedules as (
    select * from {{ ref('vaccine_schedules') }}
),

medication_dispenses as (
    select * from {{ ref('medication_dispenses') }}
),

pharmacy_order_prescriptions as (
    select * from {{ ref('pharmacy_order_prescriptions') }}
),

pharmacy_orders as (
    select * from {{ ref('pharmacy_orders') }}
),

encounters as (
    select * from {{ ref('encounters') }}
),

-- prescription branch: every prescription, joined to its encounter and drug (BL-006)
prescription_exposures as (
    select
        p.id::varchar as drug_exposure_id,
        e.patient_id::varchar as person_id,
        coalesce(p.start_datetime, p.datetime)::date as drug_exposure_start_date,
        coalesce(p.start_datetime, p.datetime) as drug_exposure_start_datetime,
        p.end_datetime as drug_exposure_end_datetime,
        'prescription' as drug_exposure_type_source_value,  -- provenance / union discriminator (BL-005)
        p.quantity::numeric as quantity,
        p.repeats as refills,
        p.route as route_source_value,
        -- exposure still occurred even when discontinued; keep the row, record why it stopped (BL-006)
        case when p.is_discontinued then p.discontinuing_reason end as stop_reason,
        p.prescriber_id::varchar as provider_id,
        ep.encounter_id::varchar as visit_occurrence_id,
        rd.code as drug_source_value,
        rd.name as drug_source_name
    from prescriptions p
    join encounter_prescriptions ep on ep.prescription_id = p.id
    join encounters e on e.id = ep.encounter_id
    left join reference_data rd on rd.id = p.medication_id
),

-- vaccination branch: GIVEN administrations only (BL-007). RECORDED_IN_ERROR (a deleted
-- GIVEN) and HISTORICAL (a hidden shadow of a separate GIVEN row) are excluded so a real
-- exposure isn't double-counted; NOT_GIVEN belongs in clinical__observation, not here
vaccination_exposures as (
    select
        av.id::varchar as drug_exposure_id,
        e.patient_id::varchar as person_id,
        av.datetime::date as drug_exposure_start_date,
        av.datetime as drug_exposure_start_datetime,
        av.datetime as drug_exposure_end_datetime,  -- point event: end equals start (BL-004)
        'vaccination' as drug_exposure_type_source_value,
        null::numeric as quantity,
        null::integer as refills,
        av.injection_site as route_source_value,
        null::varchar as stop_reason,
        -- recorded_by_id (a real user FK) preferred; given_by is free text (may name a
        -- non-Tamanu-user) and is only a fallback when no recording user was captured.
        -- provider_id's FK test is scoped off vaccination rows for this reason (BL-002)
        coalesce(av.recorded_by_id, av.given_by)::varchar as provider_id,
        av.encounter_id::varchar as visit_occurrence_id,
        rd.code as drug_source_value,
        av.vaccine_name as drug_source_name
    from vaccine_administrations av
    join encounters e on e.id = av.encounter_id
    left join vaccine_schedules vs on vs.id = av.scheduled_vaccine_id
    left join reference_data rd on rd.id = vs.vaccine_id
    where av.status = 'GIVEN'
),

-- dispense branch: physical hand-over of stock; drug identity comes from the originating
-- prescription, since a dispense carries no medication_id of its own (BL-008)
dispense_exposures as (
    select
        md.id::varchar as drug_exposure_id,
        e.patient_id::varchar as person_id,
        md.dispensed_at::date as drug_exposure_start_date,
        md.dispensed_at as drug_exposure_start_datetime,
        md.dispensed_at as drug_exposure_end_datetime,  -- point event: end equals start (BL-004)
        'dispense' as drug_exposure_type_source_value,
        md.quantity::numeric as quantity,
        null::integer as refills,
        p.route as route_source_value,
        null::varchar as stop_reason,
        md.dispensed_by_user_id::varchar as provider_id,
        po.encounter_id::varchar as visit_occurrence_id,
        rd.code as drug_source_value,
        rd.name as drug_source_name
    from medication_dispenses md
    join pharmacy_order_prescriptions pop on pop.id = md.pharmacy_order_prescription_id
    join pharmacy_orders po on po.id = pop.pharmacy_order_id
    join encounters e on e.id = po.encounter_id
    -- left join: the prescription only supplies route + drug identity, so a dispense whose
    -- prescription row is soft-deleted should still appear (with NULL drug) rather than vanish
    left join prescriptions p on p.id = pop.prescription_id
    left join reference_data rd on rd.id = p.medication_id
)

-- columns listed explicitly per branch so reordering one branch can't silently mis-map
select
    drug_exposure_id,
    person_id,
    drug_exposure_start_date,
    drug_exposure_start_datetime,
    drug_exposure_end_datetime,
    drug_exposure_type_source_value,
    quantity,
    refills,
    route_source_value,
    stop_reason,
    provider_id,
    visit_occurrence_id,
    drug_source_value,
    drug_source_name
from prescription_exposures

union all

select
    drug_exposure_id,
    person_id,
    drug_exposure_start_date,
    drug_exposure_start_datetime,
    drug_exposure_end_datetime,
    drug_exposure_type_source_value,
    quantity,
    refills,
    route_source_value,
    stop_reason,
    provider_id,
    visit_occurrence_id,
    drug_source_value,
    drug_source_name
from vaccination_exposures

union all

select
    drug_exposure_id,
    person_id,
    drug_exposure_start_date,
    drug_exposure_start_datetime,
    drug_exposure_end_datetime,
    drug_exposure_type_source_value,
    quantity,
    refills,
    route_source_value,
    stop_reason,
    provider_id,
    visit_occurrence_id,
    drug_source_value,
    drug_source_name
from dispense_exposures
