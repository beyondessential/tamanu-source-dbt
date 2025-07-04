with reporting_dates as (
    select date::date as date
    from generate_series(
        {{ parameter('fromDate', default_value='2024-01-01', data_type='date') }},
        {{ parameter('toDate', default_value='2024-01-31', data_type='date') }},
        '1 day'::interval
    ) date
)

select
    rd.date as "{{ translate_label('reportingDate') }}",
    ir.facility as "{{ translate_label('facility') }}",
    ir.department as "{{ translate_label('department') }}",
    ir.imaging_type as "{{ translate_label('imagingType') }}",
    count(distinct ir.request_id) filter (where ir.requested_datetime::date = rd.date) as "{{ translate_label('imagingTotalRequests') }}",
    count(distinct ir.request_id) filter (
        where ir.requested_datetime::date <= rd.date
        and (ir.completed_datetime::date > rd.date or ir.completed_datetime is null)
    ) as "{{ translate_label('imagingPendingRequests') }}",
    count(distinct ir.request_id) filter (
        where ir.completed_datetime::date = rd.date
    ) as "{{ translate_label('imagingCompletedRequests') }}"
from reporting_dates rd
left join {{ ref('ds__imaging_requests') }} ir
    on ir.status_id not in ('cancelled', 'deleted', 'entered_in_error')
    and ir.requested_datetime::date <= rd.date
    and (ir.completed_datetime::date >= rd.date or ir.completed_datetime is null)
where ir.status_id not in ('cancelled', 'deleted', 'entered_in_error')
    and (ir.department_id is not null or ir.imaging_type is not null)
    and (
        {{ parameter('department') }} is null or ir.department_id = {{ parameter('department') }}
    )
    and (
        case
            when {{ parameter('imagingType') }} is null then true
            else ir.imaging_type_id = {{ parameter('imagingType') }}
        end
    )
group by rd.date, ir.facility, ir.facility_id, ir.department, ir.department_id, ir.imaging_type
order by rd.date, ir.facility, ir.facility_id, ir.department, ir.department_id, ir.imaging_type
