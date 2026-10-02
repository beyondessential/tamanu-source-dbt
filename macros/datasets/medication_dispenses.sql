{% macro medication_dispenses_dataset(is_sensitive=false) %}

-- BL-006: the encounter's facility, through its location, partitioned by sensitivity -- the
-- same resolution every encounter report uses, so a dispense lands in the same report variant
-- as the rest of its encounter
with encounters_in_scope as (
    {{ encounters_core(is_sensitive=is_sensitive) }}
)

select
    md.id,
    md.quantity,
    md.dispensed_at,
    eis.patient_id,
    eis.facility_id,
    eis.facility,
    -- The dispense's own drug, so a pharmacy modification at dispensing is reported (BL-001)
    md.medication_id,
    m.code as medication_code,
    m.name as medication
from {{ ref('medication_dispenses') }} md
join {{ ref('pharmacy_order_prescriptions') }} pop
    on pop.id = md.pharmacy_order_prescription_id
join {{ ref('pharmacy_orders') }} po
    on po.id = pop.pharmacy_order_id
-- BL-006
join encounters_in_scope eis
    on eis.encounter_id = po.encounter_id
-- prescription_id is not null on all pharmacy_order_prescriptions rows (enforced by source not_null test).
-- Keeps only dispenses against a prescription the prescriptions base keeps (BL-005)
join {{ ref('prescriptions') }} pr
    on pr.id = pop.prescription_id
join {{ ref('reference_data') }} m
    on m.id = md.medication_id  -- BL-002

{% endmacro %}
