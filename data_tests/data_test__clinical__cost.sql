-- Singular tests for clinical__cost. One row per violation, tagged with the
-- acceptance criterion it breaks. See specs/dbt-model/clinical__cost.md.

with cost as (
    select * from {{ ref('clinical__cost') }}
),

-- AC-005: total_paid must equal paid_by_patient + paid_by_payer (BL-007).
-- Rounded to 2 dp to absorb floating-point noise.
ac_005 as (
    select
        cost_id,
        'AC-005' as failed_ac
    from cost
    where round(total_paid, 2) != round(paid_by_patient + paid_by_payer, 2)
),

-- AC-007: no invoice dropped or duplicated versus the shared arithmetic (BL-001).
ac_007 as (
    select
        cast(null as varchar) as cost_id,
        'AC-007' as failed_ac
    where (select count(*) from cost)
        != (select count(*) from {{ ref('int__encounter_invoice_amounts') }})
)

-- AC-005 and AC-007 are shape guards, not data assertions. clinical__cost defines
-- total_paid as paid_by_patient + paid_by_payer over the same expressions, and
-- selects from int__encounter_invoice_amounts with no join or filter, so both hold
-- by construction today. They exist to fail if a later edit introduces an
-- independent payment expression or a filter -- a green run here says the SQL
-- still has that shape, not that the data reconciles.
select cost_id, failed_ac from ac_005
union all
select cost_id, failed_ac from ac_007
