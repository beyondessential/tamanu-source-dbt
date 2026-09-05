{% macro hospital_admissions_by_area_summary_report(is_sensitive=false) %}

{#- BL-012 (specs/reports/hospital-admissions-summaries.md): the partition is
    carried by the intermediate, so this macro's only sensitivity-related job is
    picking which one to read. -#}
{% set episodes = 'int__sensitive_admission_history_location' if is_sensitive else 'int__admission_history_location' %}

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
    -- BL-013: an ungrouped location contributes no area capacity. Without this guard the
    -- CTE also builds a null-keyed group -- unreachable through the join below, but a trap:
    -- matching it with `is not distinct from` would sum every facility's ungrouped
    -- locations into one capacity and attribute it to each facility's null-area row.
    where l.location_group_id notnull
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
            -- BL-007: floored at one patient day. AIHW defines a patient day as "a day,
            -- or part of a day, that a patient is admitted", and allocates a same-day
            -- admission one bed day, so one is the minimum an episode can contribute.
            -- `<=` rather than `=` also covers a malformed episode (DV-003), whose
            -- end precedes its start and which would otherwise subtract days from the
            -- month's total. Matches the floor BL-005 already applies to length_of_stay.
            case when {{ to_user_selected_timezone('alh.end_datetime') }}::date <= {{ to_user_selected_timezone('alh.start_datetime') }}::date then 1 else
                    (least(
                        coalesce({{ to_user_selected_timezone('alh.end_datetime') }}, current_date)::date,
                        (rm.month + '1 month'::interval)::date
                    ) - greatest({{ to_user_selected_timezone('alh.start_datetime') }}::date, rm.month))
            end
        )::numeric as occupancy,
        count(*) filter (where alh.admission and {{ to_user_selected_timezone('alh.start_datetime') }}::date between rm.month and (rm.month + '1 month'::interval - '1 day'::interval)) as admissions,
        -- BL-006: discharge, death and transfer_out are events at the END of an episode,
        -- so they belong to the month the episode ended -- matching the definitions
        -- shipped with these reports. admission and transfer_in happen at the start and
        -- are counted there. An episode's end is the next episode's start, so a move now
        -- lands in one month as both a transfer out and a transfer in.
        count(*) filter (where alh.discharge and {{ to_user_selected_timezone('alh.end_datetime') }}::date between rm.month and (rm.month + '1 month'::interval - '1 day'::interval)) as discharges,
        count(*) filter (where alh.death and {{ to_user_selected_timezone('alh.end_datetime') }}::date between rm.month and (rm.month + '1 month'::interval - '1 day'::interval)) as deaths,
        count(*) filter (where alh.transfer_in and {{ to_user_selected_timezone('alh.start_datetime') }}::date between rm.month and (rm.month + '1 month'::interval - '1 day'::interval)) as transfer_ins,
        count(*) filter (where alh.transfer_out and {{ to_user_selected_timezone('alh.end_datetime') }}::date between rm.month and (rm.month + '1 month'::interval - '1 day'::interval)) as transfer_outs,
        round(avg(alh.length_of_stay) filter (where {{ to_user_selected_timezone('alh.end_datetime') }}::date between rm.month and (rm.month + '1 month'::interval - '1 day'::interval)), 1) as avg_length_of_stay
    from reporting_months rm
    join {{ ref(episodes) }} alh
        on {{ to_user_selected_timezone('alh.start_datetime') }}::date <= (rm.month + '1 month'::interval - '1 day'::interval)
        and ({{ to_user_selected_timezone('alh.end_datetime') }}::date is null or {{ to_user_selected_timezone('alh.end_datetime') }}::date >= rm.month)
    -- BL-013: left join, because `null = null` is false -- an ungrouped episode would
    -- otherwise survive the intermediate and be dropped here instead. Such a row has no
    -- area capacity to divide by, so its bed occupancy reports N/A per BL-008.
    left join area_capacity lg on lg.location_group_id = alh.location_group_id
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
    to_char(lg.month, '{{ var("yearmonth_format") }}') as "{{ translate_label('reportingMonth') }}",
    lg.facility as "{{ translate_label('facility') }}",
    lg.location_group as "{{ translate_label('locationGroup') }}",
    coalesce(lg.admissions, 0) as "{{ translate_label('hospitalAdmissionCount') }}",
    coalesce(lg.discharges, 0) as "{{ translate_label('hospitalDischargeCount') }}",
    coalesce(lg.deaths, 0) as "{{ translate_label('hospitalDeathCount') }}",
    coalesce(lg.transfer_ins, 0) as "{{ translate_label('hospitalTransfersIntoLocationCount') }}",
    coalesce(lg.transfer_outs, 0) as "{{ translate_label('hospitalTransfersOutOfLocationCount') }}",
    coalesce(lg.avg_length_of_stay, 0) as "{{ translate_label('hospitalAverageLengthOfStay') }}",
    coalesce(lg.occupancy, 0) as "{{ translate_label('hospitalPatientDayCount') }}",
    case
        when lg.occupancy notnull and lg.capacity notnull
            then
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
    end as "{{ translate_label('hospitalBedOccupancyPercent') }}"
from area_summary lg
where
    case
        when {{ parameter('locationGroupId') }} is null then true
        else lg.location_group_id = {{ parameter('locationGroupId') }}
    end
order by lg.month, lg.facility, lg.location_group

{% endmacro %}
