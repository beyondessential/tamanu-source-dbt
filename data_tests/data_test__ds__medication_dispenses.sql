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
)

select * from ac_007_order_facility_differs
