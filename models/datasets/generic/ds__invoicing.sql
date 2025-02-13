with total_invoice_amount as (
    select
        ii.invoice_id,
        round(
            sum(
                case
                    when ii.product_discountable
                        then
                            ((
                                ii.product_price
                                - case
                                    when iid.type = 'percentage' then (coalesce(iid.amount, 0) * ii.product_price)
                                    when iid.type = 'amount' then coalesce(iid.amount, 0)
                                    else 0
                                end
                            ) * ii.quantity)
                    else 0
                end
            ), 2
        ) as total_discountable_amount,
        round(
            sum(
                case
                    when not ii.product_discountable
                        then
                            ((
                                ii.product_price
                                - case
                                    when iid.type = 'percentage' then (coalesce(iid.amount, 0) * ii.product_price)
                                    when iid.type = 'amount' then coalesce(iid.amount, 0)
                                    else 0
                                end
                            ) * ii.quantity)
                    else 0
                end
            ), 2
        ) as total_nondiscountable_amount
    from {{ ref("invoice_items") }} ii
    left join {{ ref("invoice_item_discounts") }} iid
        on iid.invoice_item_id = ii.id
    group by ii.invoice_id
),

total_insurer_amount as (
    select
        tia.invoice_id,
        string_agg(concat(rd_insurer.name, ' (', (ii.percentage * 100), '%)'), ', ') as insurers,
        round(sum(tia.total_discountable_amount * ii.percentage), 2) as total_discountable_covered,
        round(sum(tia.total_nondiscountable_amount * ii.percentage), 2) as total_nondiscountable_covered
    from total_invoice_amount tia
    join {{ ref("invoice_insurers") }} ii
        on ii.invoice_id = tia.invoice_id
    join {{ ref("reference_data") }} rd_insurer
        on rd_insurer.id = ii.insurer_id
    group by tia.invoice_id
),

total_patient_amount as (
    select
        tia.invoice_id,
        round(
            sum(
                (tia.total_discountable_amount - coalesce(ii.total_discountable_covered, 0))
                - (
                    (tia.total_discountable_amount - coalesce(ii.total_discountable_covered, 0))
                    * coalesce(id.percentage, 0)
                )
            ), 2
        ) as total_discountable_balance,
        round(
            sum(tia.total_nondiscountable_amount - coalesce(ii.total_nondiscountable_covered, 0)), 2
        ) as total_nondiscountable_balance,
        round(
            sum(
                (tia.total_discountable_amount - coalesce(ii.total_discountable_covered, 0))
                * coalesce(id.percentage, 0)
            ), 2
        ) as total_patient_discount
    from total_invoice_amount tia
    left join total_insurer_amount ii
        on ii.invoice_id = tia.invoice_id
    left join {{ ref("invoice_discounts") }} id
        on id.invoice_id = tia.invoice_id
    group by tia.invoice_id
),

patient_additional_fields as (
    select
        pfv.patient_id,
        max(case when pfv.definition_id = 'fieldCategory-SocialSecurityNumber' then pfv.value end) as social_security_number,
        max(
            case when pfv.definition_id = 'fieldCategory-InsurancePolicyNumber' then pfv.value end
        ) as insurance_policy_number
    from patient_field_values pfv
    group by pfv.patient_id
)

select
    i.status,
    p.display_id,
    p.id as patient_id,
    i.id as invoice_id,
    e.id as encounter_id,
    i.display_id as invoice_number,
    rd_nationality.name as nationality,
    paf.social_security_number,
    paf.insurance_policy_number,
    concat(p.first_name, ' ', p.last_name) as patient_name,
    e.end_datetime as discharge_datetime,
    e.start_datetime as admission_datetime,
    tia.insurers,
    lg.id as discharge_area_id,
    lg.name as discharge_area,
    (coalesce(ta.total_discountable_amount, 0) + coalesce(ta.total_nondiscountable_amount,0)) as total_invoice_amount,
    (tia.total_discountable_covered + tia.total_nondiscountable_covered) as total_insurer_amount,
    tpa.total_patient_discount,
    (tpa.total_nondiscountable_balance + tpa.total_discountable_balance) as total_patient_amount,
    case when p.date_of_death is not null then 'Deceased' else 'Active' end as isdeceased,
    p.date_of_death
from {{ ref("invoices") }} i
join {{ ref("encounters") }} e
    on e.id = i.encounter_id
    and e.end_datetime is not null
join {{ ref("patients") }} p
    on p.id = e.patient_id
left join {{ ref("patient_additional_data") }} pd
    on pd.patient_id = p.id
left join {{ ref("reference_data") }} rd_nationality
    on rd_nationality.id = pd.nationality_id
join {{ ref('locations')}} l on l.id = e.location_id
join {{ ref('location_groups')}} lg on lg.id = l.location_group_id
left join total_invoice_amount ta
    on ta.invoice_id = i.id
left join total_insurer_amount tia
    on tia.invoice_id = i.id
left join total_patient_amount tpa
    on tpa.invoice_id = i.id
left join patient_additional_fields paf on paf.patient_id = p.id
order by e.end_datetime
