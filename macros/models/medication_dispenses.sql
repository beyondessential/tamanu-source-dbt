{% macro medication_dispenses_dataset(is_sensitive=false) %}

select
    md.id,
    md.quantity,
    md.dispensed_at,
    po.facility_id,
    f.name as facility,
    pr.medication_id,
    m.code as medication_code,
    m.name as medication
from {{ ref('medication_dispenses') }} md
join {{ ref('pharmacy_order_prescriptions') }} pop
    on pop.id = md.pharmacy_order_prescription_id
join {{ ref('pharmacy_orders') }} po
    on po.id = pop.pharmacy_order_id
-- prescription_id is not null on all pharmacy_order_prescriptions rows (enforced by source not_null test)
-- ongoing_prescription_id is the nullable supplementary reference and is not used for the medication lookup
join {{ ref('prescriptions') }} pr
    on pr.id = pop.prescription_id
join {{ ref('reference_data') }} m
    on m.id = pr.medication_id
join {{ ref('facilities') }} f
    on f.id = po.facility_id
    and f.is_sensitive = {{ is_sensitive }}

{% endmacro %}
