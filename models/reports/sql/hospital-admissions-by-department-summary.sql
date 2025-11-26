with reporting_months as (
    select month::date
    from generate_series(
        concat(left( {{ parameter('fromDate', default_value='2024-01-01', data_type='text') }}, 7), '-01')::date,
        concat(left( {{ parameter('toDate', default_value='2024-01-01', data_type='text') }}, 7), '-01')::date,
        '1 month'::interval
    ) month
)

select
    to_char(rm.month, '{{ var("yearmonth_format") }}') as "{{ translate_label_from_seed('reportingMonth') }}",
    adh.facility as "{{ translate_label_from_seed('facility') }}",
    adh.department as "{{ translate_label_from_seed('department') }}",
    count(*) filter (where adh.admission) as "{{ translate_label_from_seed('hospitalAdmissionCount') }}",
    count(*) filter (where adh.discharge) as "{{ translate_label_from_seed('hospitalDischargeCount') }}",
    count(*) filter (where adh.death) as "{{ translate_label_from_seed('hospitalDeathCount') }}",
    count(*) filter (where adh.transfer_in) as "{{ translate_label_from_seed('hospitalTransfersIntoDepartmentCount') }}",
    count(*) filter (where adh.transfer_out) as "{{ translate_label_from_seed('hospitalTransfersOutOfDepartmentCount') }}",
    round(avg(adh.length_of_stay), 1) as "{{ translate_label_from_seed('hospitalAverageLengthOfStay') }}"
from reporting_months rm
left join {{ ref('int__admission_history_department') }} adh
    on adh.start_datetime::date between rm.month and (rm.month + '1 month'::interval - '1 day'::interval)
where adh.facility_id notnull
    and case
        when {{ parameter('departmentId') }} is null then true
        else adh.department_id = {{ parameter('departmentId') }}
    end
group by
    rm.month,
    adh.facility_id,
    adh.facility,
    adh.department_id,
    adh.department
order by rm.month, adh.facility, adh.department
