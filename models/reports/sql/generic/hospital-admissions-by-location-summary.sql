with reporting_months as (
    select month::date
    from generate_series(
        concat(left( {{ parameter('fromDate', default_value='2024-01-01', data_type='text') }}, 7), '-01')::date,
        concat(left( {{ parameter('toDate', default_value='2024-01-01', data_type='text') }}, 7), '-01')::date,
        '1 month'::interval
    ) month
),

location_summary as (
    select
        rm.month,
        alh.facility_id,
        alh.facility,
        alh.location_id,
        alh.location,
        alh.location_group_id,
        alh.location_group,
        l.max_occupancy as capacity,
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
    join {{ ref('int__admission_location_history') }} alh
        on alh.start_datetime::date <= (rm.month + '1 month'::interval - '1 day'::interval)
        and (alh.end_datetime::date is null or alh.end_datetime::date >= rm.month)
    join {{ ref('locations') }} l on l.id = alh.location_id
    where rm.month <= current_date
    group by
        rm.month,
        alh.facility_id,
        alh.facility,
        alh.location_id,
        alh.location,
        alh.location_group_id,
        alh.location_group,
        l.max_occupancy
)

select
    to_char(ls.month, '{{ var("monthyear_format") }}') as "{{ translate_string('', 'Month') }}",
    facility as "{{ translate_string('general.localisedField.facility.label', 'Facility') }}",
    location_group as "{{ translate_string('general.localisedField.area.label', 'Area') }}",
    location as "{{ translate_string('general.localisedField.locationId.label', 'Location') }}",
    coalesce(ls.admissions, 0) as "{{ translate_string('', 'Number of admissions') }}",
    coalesce(ls.discharges, 0) as "{{ translate_string('', 'Number of discharges') }}",
    coalesce(ls.deaths, 0) as "{{ translate_string('', 'Number of deaths') }}",
    coalesce(ls.transfer_ins, 0) as "{{ translate_string('', 'Number of transfers into location') }}",
    coalesce(ls.transfer_outs, 0) as "{{ translate_string('', 'Number of transfers out of location') }}",
    coalesce(ls.avg_length_of_stay, 0) as "{{ translate_string('', 'Average length of stay') }}",
    coalesce(ls.occupancy, 0) as "{{ translate_string('', 'Number of patient days') }}",
    case when ls.occupancy notnull and ls.capacity notnull
            then concat(round(ls.occupancy / (
                    ls.capacity
                    * case
                        when ls.month > (current_date - '1 month'::interval) then current_date - ls.month
                        else (ls.month + '1 month'::interval)::date - ls.month
                    end
                ) * 100, 1)::text, '%')
        else 'N/A'
    end as "{{ translate_string('', 'Bed occupancy (%)') }}"
from location_summary ls
where case
        when {{ parameter('locationId') }} is null then true
        else ls.location_id::text = {{ parameter('locationId') }}
    end
order by ls.month, ls.facility, ls.location_group, ls.location
