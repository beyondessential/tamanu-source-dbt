{% macro encounter_invoice_audit_report(is_sensitive=false) %}

{#-
    See specs/reports/audit-encounter-invoice.md for the BL clauses this macro implements.

    Two of that spec's clauses are realised elsewhere: its BL-001 (test patient) and BL-017
    (is_sensitive facility partition) are resolved by encounters_core(), whose own clauses
    live in specs/dbt-model/encounters_core.md. The predicates below are this report's own,
    and reference the `e` / `f` aliases that macro contracts on.
-#}
{%- set scope_filter -%}
    -- BL-003: open encounters are included only when the
    -- includeOpenEncounters flag is 'yes' (the default)
    (
        e.end_datetime is not null
        or coalesce({{ parameter('includeOpenEncounters', default_value='yes') }}, 'yes') = 'yes'
    )
    -- BL-002: restrict to encounters whose start_datetime is in range
    and {{ to_user_selected_timezone('e.start_datetime') }} >= {{ parameter('fromDate', default_value='2024-01-01', data_type='date') }}
    and {{ to_user_selected_timezone('e.start_datetime') }} <= {{ parameter('toDate', default_value='2024-01-31', data_type='date') }}
    -- BL-004: optional facility, billing type and clinician filters
    and {{ encounter_scope_common_filters() }}
{%- endset -%}

with encounters_in_scope as (
    {{ encounters_core(is_sensitive=is_sensitive, extra_predicates=scope_filter, localise_timestamps=true) }}
),

invoice_data as (
    -- BL-018: aggregate the per-invoice financials (BL-009 to BL-016, resolved
    -- in ds__encounter_invoices) to one row per encounter, excluding cancelled
    -- invoices. invoice_total is coalesced to 0 so an encounter that has a
    -- non-cancelled invoice with no items reads 0 (matching the app), while an
    -- encounter with no invoice at all stays null via the outer left join.
    select
        ei.encounter_id,
        -- carried as a raw naive-central timestamp; localised in the final
        -- select like the encounter datetimes (max before the tz shift is safe:
        -- the shift is monotonic per row)
        max(ei.invoice_finalised_datetime) as invoice_finalised_datetime,
        string_agg(
            ei.products_no_category, ', '
            order by ei.invoice_datetime, ei.invoice_id
        ) filter (where ei.products_no_category is not null) as invoice_products_no_category,
        coalesce(sum(ei.invoice_total), 0) as invoice_total,
        sum(ei.insurance_coverage) as insurance_coverage,
        sum(ei.invoice_discount) as invoice_discount,
        sum(ei.patient_payment) as patient_payment,
        -- BL-013: patient subtotal, summed from ds__encounter_invoices' own
        -- per-invoice patient_subtotal (its BL-020) rather than re-derived
        -- from the aggregated components here
        sum(ei.patient_subtotal) as patient_subtotal
    from {{ ref('ds__encounter_invoices') }} ei
    join encounters_in_scope eis
        on eis.encounter_id = ei.encounter_id
    where ei.status != 'cancelled'
    group by ei.encounter_id
)

select
    p.display_id as "{{ translate_label('patientDisplayId') }}",
    p.first_name as "{{ translate_label('patientFirstName') }}",
    p.last_name as "{{ translate_label('patientLastName') }}",
    to_char(p.date_of_birth, '{{ var("date_format") }}') as "{{ translate_label('patientDateOfBirth') }}",
    date_part('year', age(eis.start_datetime_local, p.date_of_birth)) as "{{ translate_label('patientAge') }}",
    p.sex as "{{ translate_label('patientSex') }}",
    bt.name as "{{ translate_label('patientBillingType') }}",
    to_char(eis.start_datetime_local, '{{ var("datetime_format") }}') as "{{ translate_label('encounterStartDateTime') }}",
    to_char(eis.end_datetime_local, '{{ var("datetime_format") }}') as "{{ translate_label('encounterEndDateTime') }}",
    -- BL-005: length of stay in days (minimum 1) and for in-progress
    -- encounters, days since start
    case
        when eis.end_datetime_local is null then greatest(current_date - eis.start_datetime_local::date, 1)
        when eis.end_datetime_local::date - eis.start_datetime_local::date < 1 then 1
        else eis.end_datetime_local::date - eis.start_datetime_local::date
    end as "{{ translate_label('encounterLengthOfStay') }}",
    eis.facility as "{{ translate_label('facility') }}",
    dp.name as "{{ translate_label('dischargeDepartment') }}",
    c.display_name as "{{ translate_label('encounterSupervisingClinician') }}",
    to_char({{ to_user_selected_timezone('invd.invoice_finalised_datetime') }}, '{{ var("datetime_format") }}') as "{{ translate_label('invoiceFinalisedDateTime') }}",
    -- BL-019: money columns rounded to 2dp for display, matching the app's
    -- formatDisplayPrice (the dataset carries full-precision values)
    round(invd.invoice_total, 2) as "{{ translate_label('invoiceTotal') }}",
    round(invd.insurance_coverage, 2) as "{{ translate_label('insuranceCoverage') }}",
    -- BL-013: patient subtotal
    round(invd.patient_subtotal, 2) as "{{ translate_label('invoicePatientSubtotal') }}",
    round(invd.patient_payment, 2) as "{{ translate_label('invoicePatientPayment') }}",
    -- BL-014: patient total (outstanding balance)
    round(invd.patient_subtotal - coalesce(invd.patient_payment, 0), 2) as "{{ translate_label('invoicePatientTotal') }}",
    invd.invoice_products_no_category as "{{ translate_label('invoiceProductsNoCategory') }}"
from encounters_in_scope eis
join {{ ref('patients') }} p
    on p.id = eis.patient_id
left join {{ ref('departments') }} dp
    on dp.id = eis.department_id
left join {{ ref('users') }} c
    on c.id = eis.clinician_id
left join {{ ref('reference_data') }} bt
    on bt.id = eis.patient_billing_type_id
left join invoice_data invd
    on invd.encounter_id = eis.encounter_id
where
    case
        when {{ parameter('departmentId') }} is null then true
        else dp.id = {{ parameter('departmentId') }}
    end
order by eis.start_datetime_local desc

{% endmacro %}
