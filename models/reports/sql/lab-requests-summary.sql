with reporting_dates as (
    select date::date as reporting_date
    from generate_series(
        {{ parameter('fromDate', default_value='2024-01-01', data_type='text') }}::date,
        {{ parameter('toDate', default_value='2024-01-01', data_type='text') }}::date,
        '1 day'::interval
    ) date
)

select
    to_char(rd.reporting_date, '{{ var("date_format") }}') as "{{ translate_label('reportingDate', 'Date') }}",
    lrh.facility as "{{ translate_label('facility', 'Facility') }}",
    lrh.department as "{{ translate_label('department', 'Department') }}",
    lrh.lab_test_category as "{{ translate_label('labTestCategory', 'Test category') }}",
    count(distinct case
        when rd.reporting_date = lrh.requested_date
            then lrh.request_id
    end) as "{{ translate_label('labRequestNewCount', 'Total new requests') }}",
    count(case
        when lrh.status = 'results_pending'
            then 1
    end) as "{{ translate_label('labRequestPendingCount', 'Total requests with a status of results pending') }}",
    count(case
        when lrh.status = 'published'
            then 1
    end) as "{{ translate_label('labRequestPublishedCount', 'Total requests published') }}"
from reporting_dates rd
join {{ ref('int__lab_requests_history') }} lrh
    on lrh.status_start_date <= rd.reporting_date
    and rd.reporting_date <= lrh.status_end_date
where case
        when {{ parameter('departmentId', default_value='null', data_type='text') }} is null
            then true
        else lrh.department_id::text = {{ parameter('departmentId', default_value='null', data_type='text') }}
    end
    and case
        when {{ parameter('facilityId', default_value='null', data_type='text') }} is null
            then true
        else lrh.facility_id::text = {{ parameter('facilityId', default_value='null', data_type='text') }}
    end
    and case
        when {{ parameter('labTestCategoryId', default_value='null', data_type='text') }} is null
            then true
        else lrh.lab_test_category_id::text = {{ parameter('labTestCategoryId', default_value='null', data_type='text') }}
    end
group by
    rd.reporting_date,
    lrh.facility,
    lrh.department,
    lrh.lab_test_category
having count(case
        when rd.reporting_date = lrh.requested_date
            or lrh.status in ('results_pending', 'published')
            then 1
    end) > 0
