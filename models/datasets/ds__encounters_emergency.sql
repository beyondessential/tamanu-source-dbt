select
    t.id as triage_id,
    t.arrival_datetime,
    t.triage_datetime,
    t.closed_datetime,
    t.score,
    p.id as patient_id,
    p.display_id,
    p.first_name,
    p.last_name,
    p.date_of_birth,
    p.sex,
    p.village_id,
    p.village,
    e.id as encounter_id,
    e.encounter_type,
    arrival_mode.name as arrival_mode,
    chief_complaint.name as chief_complaint,
    secondary_complaint.name as secondary_complaint,
    clinician.display_name as clinician,
    t.clinician_id,
    f.id as facility_id,
    f.name as facility
from {{ ref("triages") }} t
left join {{ ref("encounters") }} e on e.id = t.encounter_id
left join {{ ref("ds__patients") }} p on p.patient_id = e.patient_id
left join {{ ref("facilities") }} f on f.id = e.facility_id
left join {{ ref("reference_data") }} arrival_mode on arrival_mode.id = t.arrival_mode_id and arrival_mode.type = 'triageArrivalMode'
left join {{ ref("reference_data") }} chief_complaint on chief_complaint.id = t.chief_complaint_id and chief_complaint.type = 'triageChiefComplaint'
left join {{ ref("reference_data") }} secondary_complaint on secondary_complaint.id = t.secondary_complaint_id and secondary_complaint.type = 'triageSecondaryComplaint'
left join {{ ref("users") }} clinician on clinician.id = t.clinician_id
