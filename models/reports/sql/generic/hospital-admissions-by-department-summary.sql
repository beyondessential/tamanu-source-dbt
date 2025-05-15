with reporting_months as (
    select month::date
    from generate_series(
        concat(left( {{ parameter('fromDate', default_value='2024-01-01', data_type='text') }}, 7), '-01')::date,
        concat(left( {{ parameter('toDate', default_value='2024-01-01', data_type='text') }}, 7), '-01')::date,
        '1 month'::interval
    ) month
)

select
    to_char(rm.month, 'YYYY-MM') as "{{ translate_label('reportingMonth', 'Month') }}",
    adh.facility as "{{ translate_label('facilityName', 'Facility') }}",
    adh.department as "{{ translate_label('departmentName', 'Department') }}",
    count(*) filter (where adh.admission) as "{{ translate_label('hospitalAdmissionCount', 'Number of admissions') }}",
    count(*) filter (where adh.discharge) as "{{ translate_label('hospitalDischargeCount', 'Number of discharges') }}",
    count(*) filter (where adh.death) as "{{ translate_label('hospitalDeathCount', 'Number of deaths') }}",
    count(*) filter (where adh.transfer_in) as "{{ translate_label('hospitalTransfersIntoDepartmentCount', 'Number of transfers into department') }}",
    count(*) filter (where adh.transfer_out) as "{{ translate_label('hospitalTransfersOutOfDepartmentCount', 'Number of transfers out of department') }}",
    round(avg(adh.length_of_stay), 1) as "{{ translate_label('hospitalAverageLengthOfStay', 'Average length of stay') }}"
from reporting_months rm
left join {{ ref('int__admission_history_department') }} adh
    on adh.start_datetime::date between rm.month and (rm.month + '1 month'::interval - '1 day'::interval)
where adh.facility_id notnull
    and case
        when {{ parameter('departmentId') }} is null then true
        else adh.department_id::text = {{ parameter('departmentId') }}
    end
group by
    rm.month,
    adh.facility_id,
    adh.facility,
    adh.department_id,
    adh.department
order by rm.month, adh.facility, adh.department
