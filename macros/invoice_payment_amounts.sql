{#
    invoice_payment_amounts(payer) -- one row per invoice payment by one payer, with the flags
    every consumer needs to total it its own way.

    See specs/dbt-model/invoice_payment_amounts.md for the BL clauses this macro implements.

    Embedded rather than exposed as a model, the same way as invoice_item_amounts(), so that
    each consumer keeps invoice_payments and the payer's link table as direct refs and its unit
    tests mock them directly.

    Columns: payment_id, invoice_id, payment_date, amount, is_refund, is_reversed,
    signed_amount. No invoice-status or encounter filter -- each consumer applies its own.
#}
{% macro invoice_payment_amounts(payer) %}
    {%- if payer == 'patient' -%}
        {%- set link = 'invoice_patient_payments' -%}
    {%- elif payer == 'insurer' -%}
        {%- set link = 'invoice_insurer_payments' -%}
    {%- else -%}
        {{ exceptions.raise_compiler_error("invoice_payment_amounts: payer must be 'patient' or 'insurer', got '" ~ payer ~ "'") }}
    {%- endif %}
    select
        ipay.id as payment_id,
        ipay.invoice_id,
        -- BL-002: the payment's own date
        ipay.date as payment_date,
        -- BL-003: the stored amount, positive for a payment and for a refund alike
        ipay.amount,
        -- BL-004: a refund carries the payment it reverses
        ipay.original_payment_id is not null as is_refund,
        -- BL-005: a payment that a refund points at
        exists (
            select 1 from {{ ref('invoice_payments') }} reversal
            where reversal.original_payment_id = ipay.id
        ) as is_reversed,
        -- BL-006: negative for a refund, so a sum over dates nets refunds on the day they were made
        case
            when ipay.original_payment_id is not null then -ipay.amount
            else ipay.amount
        end as signed_amount
    from {{ ref('invoice_payments') }} ipay
    -- BL-001: a payment belongs to the payer whose link table carries it
    -- BL-007: no invoice-status, encounter or facility filter here
    where exists (
        select 1 from {{ ref(link) }} payer_link
        where payer_link.invoice_payment_id = ipay.id
    )
{% endmacro %}
