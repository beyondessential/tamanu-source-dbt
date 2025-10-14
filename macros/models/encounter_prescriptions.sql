{% macro encounter_prescriptions_dataset(is_sensitive=false) %}

select
    ep.encounter_id,
    ep.prescription_id,
    pr.datetime,
    p.id as patient_id,
    p.display_id,
    p.first_name,
    p.last_name,
    p.date_of_birth,
    date_part('year', age(pr.datetime, p.date_of_birth)) as age,
    p.sex,
    coalesce(pd.primary_contact_number, pd.secondary_contact_number) as contact_number,
    vil.id as village_id,
    vil.name as village,
    l.facility_id,
    f.name as facility,
    ep.is_selected_for_discharge,
    pr.medication_id,
    m.code as medication_code,
    m.name as medication,
    pr.quantity
from {{ ref("encounter_prescriptions") }} ep
join {{ ref("encounters") }} e on e.id = ep.encounter_id
join {{ ref("patients") }} p on p.id = e.patient_id
join {{ ref("prescriptions") }} pr on pr.id = ep.prescription_id
join {{ ref("locations") }} l on l.id = e.location_id
join {{ ref("facilities") }} f 
    on f.id = l.facility_id
    and f.is_sensitive = {{ is_sensitive }}
left join {{ ref('patient_additional_data') }} pd on pd.patient_id = p.id
left join {{ ref('reference_data') }} billing on billing.id = pd.patient_billing_type_id
left join {{ ref('reference_data') }} vil on vil.id = p.village_id
join {{ ref("reference_data")}} m on m.id = pr.medication_id

{% endmacro %}
