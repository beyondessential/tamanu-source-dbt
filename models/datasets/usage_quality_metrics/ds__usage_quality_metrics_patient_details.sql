with data as (
    select
        p.id as patient_id,
        pm.id as patient_merged_id,
        coalesce(nullif(trim(p.first_name),''), nullif(trim(pm.first_name),'')) as first_name,
        coalesce(nullif(trim(p.last_name),''), nullif(trim(pm.last_name),'')) as last_name,
        coalesce(p.date_of_birth, pm.date_of_birth) as date_of_birth,
        coalesce(nullif(trim(p.village_id),''), nullif(trim(pm.village_id),'')) as village_id,
        nullif(trim(pad.nursing_zone_id),'') as nursing_zone_id,
        nullif(trim(pad.medical_area_id),'') as medical_area_id,
        nullif(trim(pad.subdivision_id),'') as subdivision_id,
        nullif(trim(pad.division_id),'') as division_id,
        nullif(trim(pad.primary_contact_number),'') as primary_contact_number,
        nullif(trim(pad.secondary_contact_number),'') as secondary_contact_number
    from {{ ref("patients") }} p
    left join {{ ref("patients_merged") }} pm
    	on pm.id = p.id
    left join {{ ref("patient_additional_data") }} pad
        on pad.patient_id = coalesce(p.id, pm.id)
)
select
	count(*) as total_patients,
	sum(case when first_name is null or last_name is null then 1 else 0 end) as total_patients_with_incomplete_name,
	sum(case when date_of_birth is null then 1 else 0 end) as total_patients_with_missing_dob,
	sum(case when date_of_birth <= '1900-01-01' or date_of_birth > now()::date then 1 else 0 end) as total_patients_with_invalid_dob,
	sum(case when coalesce(village_id, nursing_zone_id, medical_area_id, subdivision_id, division_id) is null then 1 else 0 end) as total_patients_with_missing_location,
	sum(case when coalesce(primary_contact_number, secondary_contact_number) is null then 1 else 0 end) as total_patients_with_missing_contact,
	sum(case when patient_merged_id notnull then 1 else 0 end) as total_patients_merged
from data