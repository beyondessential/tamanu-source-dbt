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
            end, ','
        ) as conditions,
        bool_or(pc.condition_id = 'Diagnosis-Chronickidneydisease') as has_ckd,
        bool_or(pc.condition_id in ('Diagnosis-Diabetestype1', 'Diagnosis-Diabetestype2')) as has_diabetes
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
lab_test_results as (
    select 
        p.display_id,
        p.first_name,
        p.last_name,
        p.date_of_birth,
        date_part('year', age(now()::date, p.date_of_birth::date)) as age,
        p.sex,
        pca.conditions,
        pca.has_ckd,
        pca.has_diabetes,
        lr.requested_datetime,
        coalesce(ltp.name, ltt.name) as test_name,
        coalesce(lr.lab_test_panel_request_id::text, lt.lab_test_type_id) as test_id,
        lt.result::numeric,
        case 
            when coalesce(lr.lab_test_panel_request_id::text, lt.lab_test_type_id) = 'labTestType-Creatinine'
                then (p.sex = 'male' and lt.result::numeric between 0.6 and 1.1) or 
                     (p.sex = 'female' and lt.result::numeric between 0.4 and 0.8)
            when coalesce(lr.lab_test_panel_request_id::text, lt.lab_test_type_id) = 'labTestType-Sodium'
                then lt.result::numeric between 136 and 149
            when coalesce(lr.lab_test_panel_request_id::text, lt.lab_test_type_id) = 'labTestType-Potassium'
                then lt.result::numeric between 3.8 and 5
            when coalesce(lr.lab_test_panel_request_id::text, lt.lab_test_type_id) = 'labTestType-TSH'
                then lt.result::numeric between 0.4 and 4
            else false
        end as is_normal,
        row_number() over (
            partition by p.id, coalesce(lr.lab_test_panel_request_id::text, lt.lab_test_type_id)
            order by lr.requested_datetime desc
        ) as rn     
    from patient_with_ncd_conditions pca
    join {{ ref("patients") }} p on p.id = pca.patient_id
    join {{ ref("encounters") }} e on e.patient_id = p.id
    join {{ ref("lab_requests") }} lr on lr.encounter_id = e.id
    left join {{ ref("lab_test_panel_requests") }} ltpr on ltpr.id = lr.lab_test_panel_request_id
    left join {{ ref("lab_test_panels") }} ltp on ltp.id = ltpr.lab_test_panel_id
    left join {{ ref("lab_tests") }} lt on lt.lab_request_id = lr.id
    left join {{ ref("lab_test_types") }} ltt on ltt.id = lt.lab_test_type_id
    where lt.completed_datetime is not null
        and pca.conditions is not null
        and (
            lr.lab_test_panel_request_id::text in ('labTestPanel-Urinealysis', 'labTestPanel-CBC')
            or lt.lab_test_type_id in (
                'labTestType-HbA1c', 
                'labTestType-Creatinine', 
                'labTestType-Sodium', 
                'labTestType-Potassium',
                'labTestType-Triglycerides', 
                'labTestType-TotalCholesterol', 
                'labTestType-ALT', 
                'labTestType-TSH',
                'labTestType-GlucoseFasting'
            )
        )
),
lab_test_follow_ups as (
    select 
        *,
        case test_id
            when 'labTestType-HbA1c' then
                case 
                    when (age >= 65 and result < 8) or (age < 65 and result < 7) then 12 
                    else 3 
                end
            when 'labTestType-Creatinine' then
                case when is_normal and not has_ckd then 12 else 3 end
            when 'labTestType-Sodium' then
                case when is_normal and not has_ckd then 12 else 3 end
            when 'labTestType-Potassium' then
                case when is_normal and not has_ckd then 12 else 3 end
            when 'labTestType-TSH' then
                case when is_normal then 12 else 3 end
            when 'labTestType-GlucoseFasting' then
                case when not has_diabetes then 12 else null end
            when 'labTestType-Triglycerides' then 12
            when 'labTestType-TotalCholesterol' then 12
            when 'labTestType-ALT' then 12
            when 'labTestPanel-Urinealysis' then 12
            when 'labTestPanel-CBC' then 12
            else 12
        end as follow_up_months,
        case test_id
            when 'labTestType-HbA1c' then
                case 
                    when age >= 65 and result < 8 then 'HbA1c < 8 (if 65yo or older) every 6-12 months'
                    when age >= 65 and result >= 8 then 'HbA1c > 8 (if 65yo or older) every 3 months'
                    when age < 65 and result < 7 then 'HbA1c <7 if under 65yo every 6-12 months'
                    when age < 65 and result >= 7 then 'HbA1c >7 (if under 65yo) every 3 months'
                    else 'After medication Check every 3 months'
                end
            when 'labTestType-Creatinine' then
                case 
                    when is_normal and not has_ckd then 'Normal every 12 months'
                    else 'If outside of normal, or CKD diagnosis, every 3 months' 
                end
            when 'labTestType-Sodium' then
                case 
                    when is_normal and not has_ckd then 'Normal every 12 months'
                    else 'If outside of normal, or CKD diagnosis, every 3 months' 
                end
            when 'labTestType-Potassium' then
                case 
                    when is_normal and not has_ckd then 'Normal every 12 months'
                    else 'If outside of normal, or CKD diagnosis, every 3 months' 
                end
            when 'labTestType-TSH' then
                case 
                    when is_normal then 'Stable (TSH 0.4-4): Yearly'
                    else '2-3 months if instable/after medication change' 
                end
            when 'labTestType-GlucoseFasting' then
                case 
                    when not has_diabetes then 'Annually (exclude patients with Diabetes)' 
                    else null 
                end
            else 'Annually'
        end as follow_up_frequency
    from lab_test_results
    where rn = 1
)

select 
    display_id,
    first_name,
    last_name,
    date_of_birth,
    age,
    sex,
    conditions,
    test_name,
    requested_datetime,
    follow_up_frequency,
    requested_datetime + (follow_up_months || ' months')::interval as follow_up_due_date,
    case 
        when follow_up_months is not null 
            and current_date > requested_datetime + (follow_up_months || ' months')::interval 
            then 'Over due'
        else 'Upcoming' 
    end as follow_up_status
from lab_test_follow_ups
where follow_up_frequency is not null