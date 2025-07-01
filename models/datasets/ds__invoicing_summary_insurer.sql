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
                    else ii.product_price * ii.quantity
                end
            ), 2
        ) as total
    from {{ ref("invoice_items") }} ii
    left join {{ ref("invoice_item_discounts") }} iid
        on iid.invoice_item_id = ii.id
    group by ii.invoice_id
),

total_insurer_amount as (
    select
        tia.invoice_id,
        ii.insurer_id,
        round(sum(tia.total * ii.percentage), 2) as cover
    from total_invoice_amount tia
    join {{ ref("invoice_insurers") }} ii
        on ii.invoice_id = tia.invoice_id
    group by tia.invoice_id, ii.insurer_id
),

total_insurer_payments as (
    select
        ip.invoice_id,
        iip.insurer_id,
        sum(ip.amount) as total_amount_paid
    from {{ ref("invoice_payments") }} ip
    join {{ ref("invoice_insurer_payments") }} iip
        on iip.invoice_payment_id = ip.id
    group by ip.invoice_id, iip.insurer_id
),

patient_additional_fields as (
    select
        pfv.patient_id,
        max(case when pfv.definition_id = 'fieldCategory-SocialSecurityNumber' then pfv.value end) as social_security_number,
        max(
            case when pfv.definition_id = 'fieldCategory-InsurancePolicyNumber' then pfv.value end
        ) as insurance_policy_number
    from {{ ref("patient_field_values") }} pfv
    group by pfv.patient_id
)

select
    p.id as patient_id,
    p.display_id,
    i.id as invoice_id,
    e.id as encounter_id,
    i.display_id as invoice_number,
    concat(p.first_name, ' ', p.last_name) as patient_name,
    paf.social_security_number,
    paf.insurance_policy_number,
    e.start_datetime as admission_datetime,
    e.end_datetime as discharge_datetime,
    rd_insurer.id as insurer_id,
    rd_insurer.name as insurer_name,
    ta.total as total_invoice_amount,
    tia.cover as insurer_total_amount,
    coalesce(tip.total_amount_paid, 0) as insurer_payments_received,
    (tia.cover - coalesce(tip.total_amount_paid, 0)) as remaining_insurer_balance
from {{ ref("invoices") }} i
join {{ ref("encounters") }} e
    on e.id = i.encounter_id
    and e.end_datetime is not null
join {{ ref("patients") }} p
    on p.id = e.patient_id
join total_invoice_amount ta
    on ta.invoice_id = i.id
join total_insurer_amount tia
    on tia.invoice_id = i.id
left join patient_additional_fields paf
    on paf.patient_id = p.id
left join total_insurer_payments tip
    on tip.invoice_id = i.id
    and tip.insurer_id = tia.insurer_id
join {{ ref("reference_data") }} rd_insurer
    on rd_insurer.id = tia.insurer_id
where i.status = 'finalised'
    and (tia.cover - coalesce(tip.total_amount_paid, 0)) > 0
order by e.end_datetime, p.display_id
