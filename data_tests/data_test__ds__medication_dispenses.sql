-- Cross-model invariants for ds__medication_dispenses and ds__sensitive_medication_dispenses.
-- Returns violating rows (a passing test returns none). Severity is the repo default, warn.

with dispenses as (
    select
        id,
        facility_id
    from {{ ref('ds__medication_dispenses') }}
    union all
    select
        id,
        facility_id
    from {{ ref('ds__sensitive_medication_dispenses') }}
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

prescriptions as (
    select * from {{ ref('prescriptions') }}
),

reference_data as (
    select * from {{ ref('reference_data') }}
),

-- AC-007 / BL-006: the pharmacy order names the same facility as the encounter the dataset
-- reports. A row here is a dispense whose order facility differs from its encounter's; the
-- dataset reports it, and places it in a report variant, by the encounter's facility.
ac_007_order_facility_differs as (
    select
        d.id,
        'AC-007' as failed_ac
    from dispenses d
    join medication_dispenses md
        on md.id = d.id
    join pharmacy_order_prescriptions pop
        on pop.id = md.pharmacy_order_prescription_id
    join pharmacy_orders po
        on po.id = pop.pharmacy_order_id
    where po.facility_id is distinct from d.facility_id
),

-- AC-008 / BL-006: a dispense the base keeps, whose prescription the prescriptions base keeps
-- (BL-005) and whose drug resolves (BL-002, AC-003), appears in one variant. A row here is a
-- dispense dropped from both because its encounter's location or facility does not resolve.
ac_008_encounter_facility_unresolved as (
    select
        md.id,
        'AC-008' as failed_ac
    from medication_dispenses md
    join pharmacy_order_prescriptions pop
        on pop.id = md.pharmacy_order_prescription_id
    join prescriptions pr
        on pr.id = pop.prescription_id
    join reference_data m
        on m.id = md.medication_id
    where not exists (
        select 1 from dispenses d
        where d.id = md.id
    )
)

select * from ac_007_order_facility_differs
union all
select * from ac_008_encounter_facility_unresolved
