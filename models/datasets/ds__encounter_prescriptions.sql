select
    ep.encounter_id,
    ep.prescription_id,
    p.datetime,
    e.patient_id,
    l.facility_id,
    ep.is_selected_for_discharge,
    p.medication_id,
    m.name as medication,
    p.quantity
from {{ ref("encounter_prescriptions") }} ep
join {{ ref("encounters")}} e on e.id = ep.encounter_id
join {{ ref("prescriptions")}} p on p.id = ep.prescription_id
join {{ ref("locations")}} l on l.id = e.location_id
join {{ ref("reference_data")}} m on m.id = p.medication_id