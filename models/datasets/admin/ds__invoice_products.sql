select
    ip.id,
    ip.name,
    ip.insurable,
    ip.category,
    ip.source_record_id,
    ip.visibility_status,
    ipli.invoice_price_list_id,
    ipli.price,
    iipi.invoice_insurance_plan_id,
    iipi.coverage_value
from {{ ref('invoice_products') }} ip
left join {{ ref('invoice_price_list_items') }} ipli
    on ipli.invoice_product_id = ip.id
left join {{ ref('invoice_insurance_plan_items') }} iipi
    on iipi.invoice_product_id = ip.id
