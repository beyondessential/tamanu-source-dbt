with reporting_months as (
    select month::date
    from generate_series(
        concat(left( {{ parameter('fromDate', default_value='2024-01-01', data_type='text') }}, 7), '-01')::date,
        concat(left( {{ parameter('toDate', default_value='2024-01-01', data_type='text') }}, 7), '-01')::date,
        '1 month'::interval
    ) month
),

bed_occupancy as (
    select
        rm.month,
        alo.facility_id,
        alo.location_id,
        max(alo.capacity) as capacity,
        sum(alo.occupancy) as occupancy,
        round(sum(alo.occupancy) / (
            max(alo.capacity)
            * case
                when rm.month > (current_date - '1 month'::interval) then current_date - rm.month
                else (rm.month + '1 month'::interval)::date - rm.month
            end
        ) * 100, 1) as occupancy_rate
    from reporting_months rm
    join {{ ref('int__admission_location_occupancy') }} alo
        on alo.date::date between rm.month and (rm.month + '1 month'::interval - '1 day'::interval)
    group by rm.month, alo.facility_id, alo.location_id
),

location_summary as (
    select
        rm.month,
        alh.facility_id,
        alh.location_id,
        count(*) filter (where alh.admission) as admissions,
        count(*) filter (where alh.discharge) as discharges,
        count(*) filter (where alh.death) as deaths,
        count(*) filter (where alh.transfer_in) as transfer_ins,
        count(*) filter (where alh.transfer_out) as transfer_outs,
        round(avg(alh.length_of_stay), 1) as avg_length_of_stay
    from reporting_months rm
    join {{ ref('int__admission_location_history') }} alh
        on alh.date::date between rm.month and (rm.month + '1 month'::interval - '1 day'::interval)
    group by
        rm.month,
        alh.facility_id,
        alh.location_id
)

select
    to_char(rm.month, '{{ var("monthyear_format") }}') as "{{ translate_string('', 'Month') }}",
    f.name as "{{ translate_string('general.localisedField.facility.label', 'Facility') }}",
    lg.name as "{{ translate_string('general.localisedField.area.label', 'Area') }}",
    l.name as "{{ translate_string('general.localisedField.locationId.label', 'Location') }}",
    coalesce(ls.admissions, 0) as "{{ translate_string('', 'Number of admissions') }}",
    coalesce(ls.discharges, 0) as "{{ translate_string('', 'Number of discharges') }}",
    coalesce(ls.deaths, 0) as "{{ translate_string('', 'Number of deaths') }}",
    coalesce(ls.transfer_ins, 0) as "{{ translate_string('', 'Number of transfers into location') }}",
    coalesce(ls.transfer_outs, 0) as "{{ translate_string('', 'Number of transfers out of location') }}",
    coalesce(ls.avg_length_of_stay, 0) as "{{ translate_string('', 'Average length of stay') }}",
    coalesce(bo.occupancy, 0) as "{{ translate_string('', 'Number of patient days') }}",
    coalesce(bo.capacity, 0) as "{{ translate_string('', 'Number of beds') }}",
    case
        when bo.occupancy_rate notnull then concat(bo.occupancy_rate, '%') else 'N/A'
    end as "{{ translate_string('', 'Bed occupancy (%)') }}"
from reporting_months rm
left join location_summary ls
    on ls.month = rm.month
left join bed_occupancy bo
    on bo.month = rm.month
    and (bo.facility_id = ls.facility_id or ls.facility_id is null)
    and (bo.location_id = ls.location_id or ls.location_id is null)
join {{ ref('locations') }} l on l.id = coalesce(ls.location_id, bo.location_id)
join {{ ref('location_groups') }} lg on lg.id = l.location_group_id
join {{ ref('facilities') }} f on f.id = lg.facility_id
where ls.facility_id notnull or bo.facility_id notnull
    and case
        when {{ parameter('locationId') }} is null then true
        else l.id::text = {{ parameter('locationId') }}
    end
order by rm.month, ls.facility_id, l.location_group_id, ls.location_id
