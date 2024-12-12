select
    ip.id,
    ip.name,
    ip.price,
    ip.discountable,
    ip.visibility_status
from {{ source("tamanu", "invoice_products") }} ip
where ip.deleted_at is null
