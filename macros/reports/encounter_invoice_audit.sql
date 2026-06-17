{% macro encounter_invoice_audit_report(is_sensitive=false) %}

with encounters_in_scope as materialized (
    select
        e.id as encounter_id,
        e.start_datetime,
        e.end_datetime,
        e.patient_id,
        e.department_id,
        e.clinician_id,
        e.patient_billing_type_id,
        f.id as facility_id,
        f.name as facility
    from {{ ref('encounters') }} e
    join {{ ref('locations') }} l
        on l.id = e.location_id
    join {{ ref('facilities') }} f
        on f.id = l.facility_id
        and f.is_sensitive = {{ is_sensitive }}
    where
        -- BL-001: exclude the test patient
        e.patient_id != '{{ var("test_patient") }}'
        -- BL-003: open encounters are included only when the
        -- includeOpenEncounters flag is 'yes' (the default)
        and (
            e.end_datetime is not null
            or coalesce({{ parameter('includeOpenEncounters', default_value='yes') }}, 'yes') = 'yes'
        )
        -- BL-002: restrict to encounters whose start_datetime is in range
        and case
            when {{ parameter('fromDate', default_value='2024-01-01', data_type='date') }} is null then true
            else {{ to_user_selected_timezone('e.start_datetime') }} >= {{ parameter('fromDate', default_value='2024-01-01', data_type='date') }}
        end
        and case
            when {{ parameter('toDate', default_value='2024-01-31', data_type='date') }} is null then true
            else {{ to_user_selected_timezone('e.start_datetime') }} <= {{ parameter('toDate', default_value='2024-01-31', data_type='date') }}
        end
        -- BL-004: optional facility, billing type and clinician filters
        and case
            when {{ parameter('facilityId') }} is null then true
            else f.id = {{ parameter('facilityId') }}
        end
        and case
            when {{ parameter('patientBillingTypeId') }} is null then true
            else e.patient_billing_type_id = {{ parameter('patientBillingTypeId') }}
        end
        and case
            when {{ parameter('supervisingClinicianId') }} is null then true
            else e.clinician_id = {{ parameter('supervisingClinicianId') }}
        end
),

invoice_finalised as (
    -- BL-015: most recent transition into finalised status per invoice
    select
        icl.invoice_id,
        max(icl.logged_at at time zone '{{ var("timezone") }}') as finalised_at
    from {{ ref('invoices_change_logs') }} icl
    where
        icl.status = 'finalised'
        and (icl.previous_status is null or icl.previous_status != 'finalised')
    group by icl.invoice_id
),

encounter_price_list as (
    -- BL-006: resolve the single matching price list per encounter, mirroring
    -- getIdForPatientEncounter. Matches on facility (with exclusionary
    -- logic), patient billing type, and patient age (at encounter start).
    select distinct on (eis.encounter_id)
        eis.encounter_id,
        ipl.id as invoice_price_list_id
    from encounters_in_scope eis
    join {{ ref('patients') }} p
        on p.id = eis.patient_id
    cross join {{ ref('invoice_price_lists') }} ipl
    where ipl.visibility_status = 'current'
        -- Facility: direct match, or no facility rule and this facility
        -- is not explicitly claimed by another price list
        and (
            (ipl.rules ->> 'facilityId') = eis.facility_id
            or (
                (ipl.rules ->> 'facilityId') is null
                and not exists (
                    select 1 from {{ ref('invoice_price_lists') }} other
                    where other.visibility_status = 'current'
                        and (other.rules ->> 'facilityId') = eis.facility_id
                )
            )
        )
        -- Patient billing type
        and (
            (ipl.rules ->> 'patientType') is null
            or (ipl.rules ->> 'patientType') = eis.patient_billing_type_id
        )
        -- Patient age at encounter start: exact numeric or min/max range
        and (
            (ipl.rules -> 'patientAge') is null
            or (
                jsonb_typeof(ipl.rules -> 'patientAge') = 'number'
                and date_part('year', age(eis.start_datetime, p.date_of_birth))
                = (ipl.rules ->> 'patientAge')::integer
            )
            or (
                jsonb_typeof(ipl.rules -> 'patientAge') = 'object'
                and (
                    (ipl.rules -> 'patientAge' ->> 'min') is null
                    or date_part('year', age(eis.start_datetime, p.date_of_birth))
                    >= (ipl.rules -> 'patientAge' ->> 'min')::integer
                )
                and (
                    (ipl.rules -> 'patientAge' ->> 'max') is null
                    or date_part('year', age(eis.start_datetime, p.date_of_birth))
                    <= (ipl.rules -> 'patientAge' ->> 'max')::integer
                )
            )
        )
    order by eis.encounter_id asc, ipl.code asc, ipl.id asc
),

item_resolved_price as materialized (
    -- BL-007 and BL-008: mirrors getInvoiceItemPrice and
    -- getInvoiceItemTotalDiscountedPrice. Resolves unit price then applies
    -- item-level discount (percentage or flat amount) to produce the
    -- discounted line total.
    select
        ii.id as invoice_item_id,
        ii.invoice_id,
        ii.product_id,
        ii.date,
        ii.product_name_final,
        ii.quantity,
        ip.category,
        ip.insurable,
        coalesce(
            ii.price_final,
            ii.manual_entry_price,
            ipli.price,
            0
        ) as price,
        case
            when iid.type = 'percentage'
                then coalesce(ii.price_final, ii.manual_entry_price, ipli.price, 0)
                    * ii.quantity * (1 - coalesce(iid.amount, 0))
            when iid.type = 'amount'
                then greatest(
                        coalesce(ii.price_final, ii.manual_entry_price, ipli.price, 0)
                        * ii.quantity - coalesce(iid.amount, 0),
                        0
                    )
            else coalesce(ii.price_final, ii.manual_entry_price, ipli.price, 0) * ii.quantity
        end as discounted_total
    from encounters_in_scope eis
    join {{ ref('invoices') }} i
        on i.encounter_id = eis.encounter_id
    join {{ ref('invoice_items') }} ii
        on ii.invoice_id = i.id
    left join {{ ref('invoice_products') }} ip
        on ip.id = ii.product_id
    left join encounter_price_list epl
        on epl.encounter_id = eis.encounter_id
    left join {{ ref('invoice_price_list_items') }} ipli
        on ipli.invoice_price_list_id = epl.invoice_price_list_id
        and ipli.invoice_product_id = ii.product_id
        and ipli.is_hidden = false
    -- Tamanu enforces one discount per item (application logic, no DB
    -- unique constraint); distinct on guards against unexpected duplicates.
    left join (
        select distinct on (invoice_item_id)
            invoice_item_id,
            amount,
            type
        from {{ ref('invoice_item_discounts') }}
        order by invoice_item_id
    ) iid on iid.invoice_item_id = ii.id
),

invoice_items_agg as (
    select
        irp.invoice_id,
        string_agg(
            irp.product_name_final, ', '
            order by irp.date
        ) filter (where irp.category is null) as products_no_category,
        sum(irp.discounted_total) as item_total
    from item_resolved_price irp
    group by irp.invoice_id
),

invoice_payments_agg as (
    -- BL-012: refunds are stored as positive amounts with
    -- original_payment_id set; negate them so sum gives the net patient
    -- payment total.
    select
        ipay.invoice_id,
        sum(
            case when ipay.original_payment_id is not null then -ipay.amount else ipay.amount end
        ) filter (where ipp.id is not null) as patient_payment
    from {{ ref('invoice_payments') }} ipay
    left join {{ ref('invoice_patient_payments') }} ipp
        on ipp.invoice_payment_id = ipay.id
    group by ipay.invoice_id
),

item_coverage as (
    -- BL-010: mirrors getInvoiceItemCoveragePercentage. Finalised insurance
    -- records (frozen at finalisation) take precedence over live plan
    -- coverage (used for in-progress invoices).
    select
        irp.invoice_item_id,
        coalesce(
            -- Finalised: snapshotted coverage, immune to plan changes
            fc.total_pct,
            -- Live: current plan coverage for in-progress invoices
            pc.total_pct,
            0
        ) as total_pct
    from item_resolved_price irp
    left join (
        select
            invoice_item_id,
            sum(coverage_value_final) as total_pct
        from {{ ref('invoice_item_finalised_insurances') }}
        group by invoice_item_id
    ) fc on fc.invoice_item_id = irp.invoice_item_id
    left join (
        select
            ii.id as invoice_item_id,
            sum(coalesce(iipi.coverage_value, iip.default_coverage, 0)) as total_pct
        from {{ ref('invoice_items') }} ii
        join {{ ref('invoices') }} i
            on i.id = ii.invoice_id
        join encounters_in_scope eis
            on eis.encounter_id = i.encounter_id
        join {{ ref('invoice_products') }} ip
            on ip.id = ii.product_id
            and ip.insurable = true
        join {{ ref('invoices_invoice_insurance_plans') }} iiip
            on iiip.invoice_id = ii.invoice_id
        join {{ ref('invoice_insurance_plans') }} iip
            on iip.id = iiip.invoice_insurance_plan_id
        left join {{ ref('invoice_insurance_plan_items') }} iipi
            on iipi.invoice_insurance_plan_id = iiip.invoice_insurance_plan_id
            and iipi.invoice_product_id = ii.product_id
        group by ii.id
    ) pc on pc.invoice_item_id = irp.invoice_item_id
    where irp.insurable = true
),

insurance_coverage_agg as (
    -- BL-010: per-invoice insurance coverage. Applies coverage percentage to
    -- each insurable item's discounted price, capping per-item coverage
    -- at the discounted total to handle combined percentages over 100%.
    select
        irp.invoice_id,
        round(sum(least(
            irp.discounted_total * ic.total_pct / 100,
            irp.discounted_total
        )), 2) as insurance_coverage
    from item_resolved_price irp
    join item_coverage ic
        on ic.invoice_item_id = irp.invoice_item_id
    where irp.discounted_total > 0
    group by irp.invoice_id
),

-- BL-011: Tamanu enforces one discount per invoice (application logic, no DB
-- unique constraint); distinct on guards against unexpected duplicates.
invoice_discount as (
    select distinct on (invoice_id)
        invoice_id,
        percentage
    from {{ ref('invoice_discounts') }}
    order by invoice_id
),

invoice_data as (
    select
        i.encounter_id,
        to_char(max(inf.finalised_at), '{{ var("datetime_format") }}') as invoice_finalised_datetime,
        string_agg(
            iia.products_no_category, ', '
            order by i.datetime, i.id
        ) filter (where i.status != 'cancelled' and iia.products_no_category is not null) as invoice_products_no_category,
        -- BL-009: invoice total per encounter
        sum(iia.item_total) filter (where i.status != 'cancelled') as invoice_total,
        sum(ica.insurance_coverage) filter (where i.status != 'cancelled') as insurance_coverage,
        -- BL-011: invoice-level discount, percentage applied per invoice to the
        -- patient subtotal (item total less insurance coverage), mirroring
        -- getInvoiceLevelDiscountAmount over patientSubtotal
        round(sum(
            (coalesce(iia.item_total, 0) - coalesce(ica.insurance_coverage, 0))
            * coalesce(idsc.percentage, 0)
        ) filter (where i.status != 'cancelled'), 2) as invoice_discount,
        sum(ipa.patient_payment) filter (where i.status != 'cancelled') as patient_payment
    from {{ ref('invoices') }} i
    join encounters_in_scope eis
        on eis.encounter_id = i.encounter_id
    left join invoice_finalised inf
        on inf.invoice_id = i.id
    left join invoice_items_agg iia
        on iia.invoice_id = i.id
    left join insurance_coverage_agg ica
        on ica.invoice_id = i.id
    left join invoice_payments_agg ipa
        on ipa.invoice_id = i.id
    left join invoice_discount idsc
        on idsc.invoice_id = i.id
    group by i.encounter_id
)

select
    p.display_id as "{{ translate_label('patientDisplayId') }}",
    p.first_name as "{{ translate_label('patientFirstName') }}",
    p.last_name as "{{ translate_label('patientLastName') }}",
    to_char(p.date_of_birth, '{{ var("date_format") }}') as "{{ translate_label('patientDateOfBirth') }}",
    date_part('year', age(eis.start_datetime, p.date_of_birth)) as "{{ translate_label('patientAge') }}",
    p.sex as "{{ translate_label('patientSex') }}",
    bt.name as "{{ translate_label('patientBillingType') }}",
    to_char({{ to_user_selected_timezone('eis.start_datetime') }}, '{{ var("datetime_format") }}') as "{{ translate_label('encounterStartDateTime') }}",
    to_char({{ to_user_selected_timezone('eis.end_datetime') }}, '{{ var("datetime_format") }}') as "{{ translate_label('encounterEndDateTime') }}",
    -- BL-005: length of stay in days (minimum 1); for in-progress
    -- encounters, days since start
    case
        when eis.end_datetime is null then greatest(current_date - {{ to_user_selected_timezone('eis.start_datetime') }}::date, 1)
        when {{ to_user_selected_timezone('eis.end_datetime') }}::date - {{ to_user_selected_timezone('eis.start_datetime') }}::date < 1 then 1
        else {{ to_user_selected_timezone('eis.end_datetime') }}::date - {{ to_user_selected_timezone('eis.start_datetime') }}::date
    end as "{{ translate_label('encounterLengthOfStay') }}",
    eis.facility as "{{ translate_label('facility') }}",
    dp.name as "{{ translate_label('dischargeDepartment') }}",
    c.display_name as "{{ translate_label('encounterSupervisingClinician') }}",
    invd.invoice_finalised_datetime as "{{ translate_label('invoiceFinalisedDateTime') }}",
    invd.invoice_total as "{{ translate_label('invoiceTotal') }}",
    invd.insurance_coverage as "{{ translate_label('insuranceCoverage') }}",
    -- BL-013: patient subtotal
    invd.invoice_total - coalesce(invd.insurance_coverage, 0) - coalesce(invd.invoice_discount, 0) as "{{ translate_label('invoicePatientSubtotal') }}",
    invd.patient_payment as "{{ translate_label('invoicePatientPayment') }}",
    -- BL-014: patient total (outstanding balance)
    invd.invoice_total - coalesce(invd.insurance_coverage, 0) - coalesce(invd.invoice_discount, 0) - coalesce(invd.patient_payment, 0) as "{{ translate_label('invoicePatientTotal') }}",
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
order by eis.start_datetime desc

{% endmacro %}
