{% macro hospital_admissions_by_location_summary_report(is_sensitive=false) %}

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
    to_char(ls.month, '{{ var("yearmonth_format") }}') as "{{ translate_label('reportingMonth') }}",
    ls.facility as "{{ translate_label('facility') }}",
    ls.location_group as "{{ translate_label('locationGroup') }}",
    ls.location as "{{ translate_label('location') }}",
    coalesce(ls.admissions, 0) as "{{ translate_label('hospitalAdmissionCount') }}",
    coalesce(ls.discharges, 0) as "{{ translate_label('hospitalDischargeCount') }}",
    coalesce(ls.deaths, 0) as "{{ translate_label('hospitalDeathCount') }}",
    coalesce(ls.transfer_ins, 0) as "{{ translate_label('hospitalTransfersIntoLocationCount') }}",
    coalesce(ls.transfer_outs, 0) as "{{ translate_label('hospitalTransfersOutOfLocationCount') }}",
    coalesce(ls.avg_length_of_stay, 0) as "{{ translate_label('hospitalAverageLengthOfStay') }}",
    coalesce(ls.occupancy, 0) as "{{ translate_label('hospitalPatientDayCount') }}",
    case
        when ls.occupancy notnull and ls.capacity notnull
            then
                concat(
                    round(
                        ls.occupancy / (
                            ls.capacity * case
                                when ls.month > (current_date - '1 month'::interval)
                                    then (current_date - ls.month) + 1
                                else (ls.month + '1 month'::interval)::date - ls.month
                            end
                        ) * 100, 1
                    )::text, '%'
                )
        else 'N/A'
    end as "{{ translate_label('hospitalBedOccupancyPercent') }}"
from location_summary ls
where
    case
        when {{ parameter('locationId') }} is null then true
        else ls.location_id = {{ parameter('locationId') }}
    end
order by ls.month, ls.facility, ls.location_group, ls.location

{% endmacro %}
