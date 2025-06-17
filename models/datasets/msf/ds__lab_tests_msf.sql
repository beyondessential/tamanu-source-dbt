with base_data as (
    select
        ed.epi_year,
        floor(extract(day from (lt.date - ed.epi_date_from)) / 7) + 1 as epi_week,
        e.patient_id,
        lr.department_id,
        lr.status,
        lr.display_id as lab_request_id,
        lr.lab_test_panel_request_id,
        ltpr.lab_test_panel_id,
        case when lr.lab_test_panel_request_id is null then lt.lab_test_type_id end as lab_test_type_id,
        -- Rank 1 denotes a new patient
        rank() over (
            partition by e.patient_id
            order by ed.epi_year, floor(extract(day from (lt.date - ed.epi_date_from)) / 7)
        ) as visit_rank,
        row_number() over (
            partition by lr.lab_test_panel_request_id
            order by lt.date, lr.lab_test_panel_request_id
        ) as panel_row_num
    from {{ ref("lab_requests") }} lr
    join {{ ref("encounters") }} e on e.id = lr.encounter_id
    left join {{ ref("lab_tests") }} lt
        on lt.lab_request_id = lr.id
    left join {{ ref("lab_test_panel_requests") }} ltpr on ltpr.id = lr.lab_test_panel_request_id
    join {{ ref("int__epi_dates_msf") }} ed
        on ed.epi_date_from::date <= lt.date
        and ed.epi_date_to::date >= lt.date
)

select
    epi_year,
    epi_week,
    patient_id,
    department_id,
    status,
    lab_request_id,
    lab_test_panel_id,
    lab_test_type_id,
    visit_rank
from base_data
where panel_row_num = 1 or lab_test_panel_id is null
order by patient_id, epi_year, epi_week
