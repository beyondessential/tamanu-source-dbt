-- Singular tests for ds__encounter_invoice_items. One row per violation, tagged with the
-- acceptance criterion it breaks. See specs/dbt-model/ds__encounter_invoice_items.md.

with items as (
    select * from {{ ref('ds__encounter_invoice_items') }}
),

invoices as (
    select * from {{ ref('ds__encounter_invoices') }}
),

item_agg as (
    select
        invoice_id,
        round(sum(discounted_total), 2) as items_total,
        round(sum(insurance_coverage), 2) as items_coverage
    from items
    group by invoice_id
),

-- AC-003: per-invoice sum of line discounted_total reconciles to invoice_total (BL-001/003).
ac_003 as (
    select
        ia.invoice_id::varchar as id,
        'AC-003' as failed_ac
    from item_agg ia
    join invoices inv on inv.invoice_id = ia.invoice_id
    where ia.items_total is distinct from round(inv.invoice_total, 2)
),

-- AC-004: per-invoice sum of line insurance_coverage reconciles to invoice coverage (BL-004).
ac_004 as (
    select
        ia.invoice_id::varchar as id,
        'AC-004' as failed_ac
    from item_agg ia
    join invoices inv on inv.invoice_id = ia.invoice_id
    where coalesce(ia.items_coverage, 0) is distinct from coalesce(inv.insurance_coverage, 0)
),

-- AC-005: a line's insurance coverage never exceeds its discounted total (BL-004 cap).
ac_005 as (
    select
        invoice_item_id::varchar as id,
        'AC-005' as failed_ac
    from items
    where insurance_coverage is not null
        and insurance_coverage > discounted_total
)

select id, failed_ac from ac_003
union all
select id, failed_ac from ac_004
union all
select id, failed_ac from ac_005
