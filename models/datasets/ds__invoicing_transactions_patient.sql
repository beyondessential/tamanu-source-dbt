select
    ip.date,
    i.id as invoice_id,
    p.id as patient_id,
    e.id as encounter_id,
    i.display_id as invoice_number,
    concat(p.first_name, ' ', p.last_name) as patient_name,
    rd_method.id as payment_method_id,
    rd_method.name as payment_method,
    ip.receipt_number,
    ip.amount,
    u.display_name as recieved_by
from {{ ref('invoice_payments') }} ip
join {{ ref('invoice_patient_payments') }} ipp on ipp.invoice_payment_id = ip.id
join {{ ref('invoices') }} i on i.id = ip.invoice_id
join {{ ref('encounters') }} e on e.id = i.encounter_id
join {{ ref('patients') }} p on p.id = e.patient_id
join {{ ref('reference_data') }} rd_method on rd_method.id = ipp.method_id
left join {{ ref('users') }} u on u.id = ip.updated_by_id
order by ip.date
