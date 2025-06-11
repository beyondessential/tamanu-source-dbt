with patient_with_ncd_conditions as (
	select 
		patient_id,
		string_agg(distinct
			case pc.condition_id
				when 'Diagnosis-Diabetestype1' then 'Diabetes'
				when 'Diagnosis-Diabetestype2' then 'Diabetes'
				when 'Diagnosis-Hypertension' then 'Hypertension'
				when 'Diagnosis-Cardiovasculardisease' then 'CVD'
				when 'Diagnosis-Heartfailure' then 'CCF'
				when 'Diagnosis-Hypothyroidism' then 'Hypothyroidism'
			end
		, ',') as conditions,
		array_agg(pc.condition_id::text) as condition_ids
	from {{ ref("patient_conditions") }} pc
	where pc.is_resolved = false
		and pc.condition_id in (
			'Diagnosis-Hypothyroidism', 
			'Diagnosis-Diabetestype1',
			'Diagnosis-Diabetestype2', 
			'Diagnosis-Hypertension', 
			'Diagnosis-Chronickidneydisease',
			'Diagnosis-Cardiovasculardisease', 
			'Diagnosis-Heartfailure'
		)
	group by patient_id
),
patient_lab_tests as (
	select 
		e.patient_id,
		p.display_id,
		p.first_name,
		p.last_name,
		p.date_of_birth,
		date_part('year', age(now()::date, p.date_of_birth::date)) as age,
		p.sex,
		pnc.conditions,
		coalesce(ltp.name, ltt.name) as test_name,
		lr.requested_datetime as test_date,
		case
			when lt.lab_test_type_id = 'labTestType-HbA1c' then
				case 
					when extract(year from age(now()::date, p.date_of_birth::date)) >= 65 and lt.result::numeric < 8 then 'HbA1c < 8 (if 65yo or older) every 6-12 months'
					when extract(year from age(now()::date, p.date_of_birth::date)) >= 65 and lt.result::numeric >= 8 then 'HbA1c > 8 (if 65yo or older) every 3 months'
					when extract(year from age(now()::date, p.date_of_birth::date)) < 65 and lt.result::numeric < 7 then 'HbA1c <7 if under 65yo every 6-12 months'
					when extract(year from age(now()::date, p.date_of_birth::date)) < 65 and lt.result::numeric >= 7 then 'HbA1c >7 (if under 65yo) every 3 months'
					else 'After medication Check every 3 months'
				end
			when lt.lab_test_type_id = 'labTestType-Creatinine' then
				case 
					when ((p.sex = 'male' and lt.result::numeric between 0.6 and 1.1) or 
						 (p.sex = 'female' and lt.result::numeric between 0.4 and 0.8))
						 and not ('Diagnosis-Chronickidneydisease' = ANY(pnc.condition_ids)) then 'Normal every 12 months'
					else 'If outside of normal, or CKD diagnosis, every 3 months'
				end
			when lt.lab_test_type_id = 'labTestType-Sodium' then
				case 
					when lt.result::numeric between 136 and 149 and not ('Diagnosis-Chronickidneydisease' = ANY(pnc.condition_ids)) then 'Normal every 12 months'
					else 'If outside of normal, or CKD diagnosis, every 3 months'
				end
			when lt.lab_test_type_id = 'labTestType-Potassium' then
				case 
					when lt.result::numeric between 3.8 and 5 and not ('Diagnosis-Chronickidneydisease' = ANY(pnc.condition_ids)) then 'Normal every 12 months'
					else 'If outside of normal, or CKD diagnosis, every 3 months'
				end
			when lt.lab_test_type_id = 'labTestType-Triglycerides' then 'Annually'
			when lt.lab_test_type_id = 'labTestType-TotalCholesterol' then 'Annually'
			when lt.lab_test_type_id = 'labTestType-ALT' then 'Annually'
			when lr.lab_test_panel_request_id::text = 'labTestPanel-Urinealysis' then 'Annually'
			when lt.lab_test_type_id = 'labTestType-GlucoseFasting'
				and not ('Diagnosis-Diabetestype1' = ANY(pnc.condition_ids)) 
				and not ('Diagnosis-Diabetestype2' = ANY(pnc.condition_ids)) then 'Annually (exclude patients with Diabetes)'
			when lr.lab_test_panel_request_id::text = 'labTestPanel-CBC' then 'Annually'
			when lt.lab_test_type_id = 'labTestType-TSH' then
				case 
					when lt.result::numeric between 0.4 and 4 then 'Stable (TSH 0.4-4): Yearly'
					else '2-3 months if instable/after medication change'
				end
		end as follow_up_frequency,
		case 
			when lt.lab_test_type_id = 'labTestType-HbA1c' then
				case 
					when extract(year from age(now()::date, p.date_of_birth::date)) >= 65 and lt.result::numeric < 8 then lr.requested_datetime + interval '12 months'
					when extract(year from age(now()::date, p.date_of_birth::date)) >= 65 and lt.result::numeric >= 8 then lr.requested_datetime + interval '3 months'
					when extract(year from age(now()::date, p.date_of_birth::date)) < 65 and lt.result::numeric < 7 then lr.requested_datetime + interval '12 months'
					when extract(year from age(now()::date, p.date_of_birth::date)) < 65 and lt.result::numeric >= 7 then lr.requested_datetime + interval '3 months'
					else lr.requested_datetime + interval '3 months'
				end
			when lt.lab_test_type_id = 'labTestType-Creatinine' then
				case 
					when ((p.sex = 'male' and lt.result::numeric between 0.6 and 1.1) or 
						 (p.sex = 'female' and lt.result::numeric between 0.4 and 0.8))
						 and not ('Diagnosis-Chronickidneydisease' = ANY(pnc.condition_ids)) then lr.requested_datetime + interval '12 months'
					else lr.requested_datetime + interval '3 months'
				end
			when lt.lab_test_type_id = 'labTestType-Sodium' then
				case 
					when lt.result::numeric between 136 and 149 and not ('Diagnosis-Chronickidneydisease' = ANY(pnc.condition_ids)) then lr.requested_datetime + interval '12 months'
					else lr.requested_datetime + interval '3 months'
				end
			when lt.lab_test_type_id = 'labTestType-Potassium' then
				case 
					when lt.result::numeric between 3.8 and 5 and not ('Diagnosis-Chronickidneydisease' = ANY(pnc.condition_ids)) then lr.requested_datetime + interval '12 months'
					else lr.requested_datetime + interval '3 months'
				end
			when lt.lab_test_type_id in ('labTestType-Triglycerides', 'labTestType-TotalCholesterol', 'labTestType-ALT') 
			  or lr.lab_test_panel_request_id::text in ('labTestPanel-Urinealysis', 'labTestPanel-CBC') then lr.requested_datetime + interval '12 months'
			when lt.lab_test_type_id = 'labTestType-GlucoseFasting'
				and not ('Diagnosis-Diabetestype1' = ANY(pnc.condition_ids)) 
				and not ('Diagnosis-Diabetestype2' = ANY(pnc.condition_ids)) then lr.requested_datetime + interval '12 months'
			when lt.lab_test_type_id = 'labTestType-TSH' then
				case 
					when lt.result::numeric between 0.4 and 4 then lr.requested_datetime + interval '12 months'
					else lr.requested_datetime + interval '3 months'
				end
			else lr.requested_datetime + interval '12 months'
		end as follow_up_due_date,
		row_number() over (
			partition by 
				e.patient_id, 
				coalesce(lr.lab_test_panel_request_id::text, lt.lab_test_type_id)
			order by lr.requested_datetime desc
		) as rn
	from patient_with_ncd_conditions pnc
	join {{ ref("patients") }} p on p.id = pnc.patient_id
	join {{ ref("encounters") }} e on e.patient_id = p.id
	join {{ ref("lab_requests") }} lr on lr.encounter_id = e.id
	left join {{ ref("lab_test_panel_requests") }} ltpr on ltpr.id = lr.lab_test_panel_request_id
	left join {{ ref("lab_test_panels") }} ltp on ltp.id = ltpr.lab_test_panel_id
	left join {{ ref("lab_tests") }} lt on lt.lab_request_id = lr.id
	left join {{ ref("lab_test_types") }} ltt on ltt.id = lt.lab_test_type_id
	where lt.completed_datetime is not null
		and pnc.conditions is not null
		and (lr.lab_test_panel_request_id::text in (
			'labTestPanel-Urinealysis',
			'labTestPanel-CBC'
		)
		or lt.lab_test_type_id in (
			'labTestType-HbA1c',
			'labTestType-Creatinine',
			'labTestType-Sodium',
			'labTestType-Potassium',
			'labTestType-Triglycerides',
			'labTestType-TotalCholesterol',
			'labTestType-ALT',
			'labTestType-TSH'
		))
)

select 
	plt.display_id,
	plt.first_name,
	plt.last_name,
	plt.date_of_birth,
	plt.age,
	plt.sex,
	plt.conditions,
	plt.test_name,
	plt.test_date,
	plt.follow_up_frequency,
	plt.follow_up_due_date,
	case 
		when now()::date > plt.follow_up_due_date then 'Over due'
		else 'Upcoming'
	end as follow_up_status
from patient_lab_tests plt
where plt.rn = 1