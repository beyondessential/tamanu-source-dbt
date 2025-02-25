with reporting_months as (
    select month::date
    from generate_series(
        concat(left( {{ parameter('fromDate', default_value='2024-01-01', data_type='text') }}, 7), '-01')::date,
        concat(left( {{ parameter('toDate', default_value='2024-01-01', data_type='text') }}, 7), '-01')::date,
        '1 month'::interval
    ) month
)

select
    to_char(rm.month, '{{ var("monthyear_format") }}') as "{{ translate_string('', 'Month') }}",
    adh.facility as "{{ translate_string('general.localisedField.facility.label', 'Facility') }}",
    adh.department as "{{ translate_string('general.localisedField.departmentId.label', 'Department') }}",
    count(*) filter (where adh.admission) as "{{ translate_string('', 'Number of admissions') }}",
    count(*) filter (where adh.discharge) as "{{ translate_string('', 'Number of discharges') }}",
    count(*) filter (where adh.death) as "{{ translate_string('', 'Number of deaths') }}",
    count(*) filter (where adh.transfer_in) as "{{ translate_string('', 'Number of transfers into department') }}",
    count(*) filter (where adh.transfer_out) as "{{ translate_string('', 'Number of transfers out of department') }}",
    round(avg(adh.length_of_stay), 1) as "{{ translate_string('', 'Average length of stay') }}"
from reporting_months rm
left join {{ ref('int__admission_department_history') }} adh
    on adh.date::date between rm.month and (rm.month + '1 month'::interval - '1 day'::interval)
where adh.facility_id notnull
group by
    rm.month,
    adh.facility_id,
    adh.facility,
    adh.department_id,
    adh.department
