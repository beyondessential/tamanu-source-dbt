with reporting_months as (
    select month::date
    from generate_series(
        concat(left( {{ parameter('fromDate', default_value='2024-01-01', data_type='text') }}, 7), '-01')::date,
        concat(left( {{ parameter('toDate', default_value='2024-01-01', data_type='text') }}, 7), '-01')::date,
        '1 month'::interval
    ) month
),

area_capacity as (
    select
        l.location_group_id,
        sum(l.max_occupancy::numeric) as capacity
    from {{ ref('locations') }} l
    group by l.location_group_id
),

area_summary as (
    select
        rm.month,
        alh.facility_id,
        alh.facility,
        alh.location_group_id,
        alh.location_group,
        lg.capacity,
        sum(
            case when alh.end_datetime::date = alh.start_datetime::date then 1 else
                    (least(
                        coalesce(alh.end_datetime, current_date)::date,
                        (rm.month + '1 month'::interval)::date
                    ) - greatest(alh.start_datetime::date, rm.month))
            end
        )::numeric as occupancy,
        count(*) filter (where alh.admission and alh.start_datetime::date between rm.month and (rm.month + '1 month'::interval - '1 day'::interval)) as admissions,
        count(*) filter (where alh.discharge and alh.start_datetime::date between rm.month and (rm.month + '1 month'::interval - '1 day'::interval)) as discharges,
        count(*) filter (where alh.death and alh.start_datetime::date between rm.month and (rm.month + '1 month'::interval - '1 day'::interval)) as deaths,
        count(*) filter (where alh.transfer_in and alh.start_datetime::date between rm.month and (rm.month + '1 month'::interval - '1 day'::interval)) as transfer_ins,
        count(*) filter (where alh.transfer_out and alh.start_datetime::date between rm.month and (rm.month + '1 month'::interval - '1 day'::interval)) as transfer_outs,
        round(avg(alh.length_of_stay) filter (where alh.end_datetime::date between rm.month and (rm.month + '1 month'::interval - '1 day'::interval)), 1) as avg_length_of_stay
    from reporting_months rm
    join {{ ref('int__admission_history_location') }} alh
        on alh.start_datetime::date <= (rm.month + '1 month'::interval - '1 day'::interval)
        and (alh.end_datetime::date is null or alh.end_datetime::date >= rm.month)
    join area_capacity lg on lg.location_group_id = alh.location_group_id
    where rm.month <= current_date
    group by
        rm.month,
        alh.facility_id,
        alh.facility,
        alh.location_group_id,
        alh.location_group,
        lg.capacity
)

select
    to_char(lg.month, '{{ var("monthyear_format") }}') as "{{ translate_string('reportMonth', 'Month') }}",
    lg.facility as "{{ translate_string('facilityName', 'Facility') }}",
    lg.location_group as "{{ translate_string('locationGroupName', 'Area') }}",
    coalesce(lg.admissions, 0) as "{{ translate_string('admissionCount', 'Number of admissions') }}",
    coalesce(lg.discharges, 0) as "{{ translate_string('dischargeCount', 'Number of discharges') }}",
    coalesce(lg.deaths, 0) as "{{ translate_string('deathCount', 'Number of deaths') }}",
    coalesce(lg.transfer_ins, 0) as "{{ translate_string('transfersIntoLocationCount', 'Number of transfers into location') }}",
    coalesce(lg.transfer_outs, 0) as "{{ translate_string('transfersOutOfLocationCount', 'Number of transfers out of location') }}",
    coalesce(lg.avg_length_of_stay, 0) as "{{ translate_string('averageLengthOfStay', 'Average length of stay') }}",
    coalesce(lg.occupancy, 0) as "{{ translate_string('patientDayCount', 'Number of patient days') }}",
    case
        when lg.occupancy notnull and lg.capacity notnull then
            concat(
                round(
                    lg.occupancy / (
                        lg.capacity * case
                            when lg.month > (current_date - '1 month'::interval)
                                then (current_date - lg.month) + 1
                            else (lg.month + '1 month'::interval)::date - lg.month
                        end
                    ) * 100, 1
                )::text, '%'
            )
        else 'N/A'
    end as "{{ translate_string('bedOccupancyPercent', 'Bed occupancy (%)') }}"
from area_summary lg
where
    case
        when {{ parameter('locationGroupId') }} is null then true
        else lg.location_group::text = {{ parameter('locationGroupId') }}
    end
order by lg.month, lg.facility, lg.location_group
