select ed.epi_year,
	floor(extract(day from (lt.date - ed.epi_date_from)) / 7) as epi_week,
	e.patient_id,
	lr.department_id,
	lr.status,
	lt.lab_request_id,
	ltpr.lab_test_panel_id, 
	lt.lab_test_type_id,
	-- Rank 1 denotes a new patient
	rank() over (
		partition by patient_id 
		order by epi_year, floor(extract(day from (lt.date - ed.epi_date_from)) / 7)
	) as visit_rank
from {{ ref("lab_requests") }} lr
join {{ ref("encounters") }} e on e.id = lr.encounter_id
left join {{ ref("lab_tests") }} lt
	on lt.lab_request_id = lr.id
left join {{ ref("lab_test_panel_requests") }} ltpr on ltpr.id = lr.lab_test_panel_request_id
join {{ ref("int__epi_dates_msf") }} ed
	on ed.epi_date_from::date <= lt.date
	and ed.epi_date_to::date >= lt.date
order by patient_id, epi_year, epi_week