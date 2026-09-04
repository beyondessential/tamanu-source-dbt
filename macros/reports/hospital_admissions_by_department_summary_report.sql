{% macro hospital_admissions_by_department_summary_report(is_sensitive=false) %}

{#- BL-012 (specs/reports/hospital-admissions-summaries.md): the partition is
    carried by the intermediate, so this macro's only sensitivity-related job is
    picking which one to read. -#}
{% set episodes = 'int__sensitive_admission_history_department' if is_sensitive else 'int__admission_history_department' %}

with reporting_months as (
    select month::date
    from generate_series(
        concat(left( {{ parameter('fromDate', default_value='2024-01-01', data_type='text') }}, 7), '-01')::date,
        concat(left( {{ parameter('toDate', default_value='2024-01-01', data_type='text') }}, 7), '-01')::date,
        '1 month'::interval
    ) month
)

select
    to_char(rm.month, '{{ var("yearmonth_format") }}') as "{{ translate_label('reportingMonth') }}",
    adh.facility as "{{ translate_label('facility') }}",
    adh.department as "{{ translate_label('department') }}",
    -- BL-006 (specs/reports/hospital-admissions-summaries.md): episodes join on overlap,
    -- so each event count filters to the episodes that started inside the month
    count(*) filter (where adh.admission and {{ to_user_selected_timezone('adh.start_datetime') }}::date between rm.month and (rm.month + '1 month'::interval - '1 day'::interval)) as "{{ translate_label('hospitalAdmissionCount') }}",
    count(*) filter (where adh.discharge and {{ to_user_selected_timezone('adh.start_datetime') }}::date between rm.month and (rm.month + '1 month'::interval - '1 day'::interval)) as "{{ translate_label('hospitalDischargeCount') }}",
    count(*) filter (where adh.death and {{ to_user_selected_timezone('adh.start_datetime') }}::date between rm.month and (rm.month + '1 month'::interval - '1 day'::interval)) as "{{ translate_label('hospitalDeathCount') }}",
    count(*) filter (where adh.transfer_in and {{ to_user_selected_timezone('adh.start_datetime') }}::date between rm.month and (rm.month + '1 month'::interval - '1 day'::interval)) as "{{ translate_label('hospitalTransfersIntoDepartmentCount') }}",
    count(*) filter (where adh.transfer_out and {{ to_user_selected_timezone('adh.start_datetime') }}::date between rm.month and (rm.month + '1 month'::interval - '1 day'::interval)) as "{{ translate_label('hospitalTransfersOutOfDepartmentCount') }}",
    -- BL-011: averaged over the episodes that ENDED in the month, matching -by-area and
    -- -by-location so the three reports' length-of-stay figures are comparable
    round(avg(adh.length_of_stay) filter (where {{ to_user_selected_timezone('adh.end_datetime') }}::date between rm.month and (rm.month + '1 month'::interval - '1 day'::interval)), 1) as "{{ translate_label('hospitalAverageLengthOfStay') }}"
from reporting_months rm
join {{ ref(episodes) }} adh
    on (
        -- the overlap window BL-011 needs: an episode reaches every month it spans, so a
        -- month can report the stays that ended in it even when none started
        {{ to_user_selected_timezone('adh.start_datetime') }}::date <= (rm.month + '1 month'::interval - '1 day'::interval)
        and ({{ to_user_selected_timezone('adh.end_datetime') }}::date is null or {{ to_user_selected_timezone('adh.end_datetime') }}::date >= rm.month)
    )
    -- DV-003: an episode whose end precedes its start spans no month at all, so overlap
    -- alone would drop it from every one. Kept in the month it started, preserving the
    -- event counts this report has always reported.
    or {{ to_user_selected_timezone('adh.start_datetime') }}::date between rm.month and (rm.month + '1 month'::interval - '1 day'::interval)
where rm.month <= current_date
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
-- BL-009: with no occupancy column, a month an episode merely spans has nothing to
-- report, so a row is kept only where an episode started or ended inside it
having count(*) filter (
    where {{ to_user_selected_timezone('adh.start_datetime') }}::date between rm.month and (rm.month + '1 month'::interval - '1 day'::interval)
        or {{ to_user_selected_timezone('adh.end_datetime') }}::date between rm.month and (rm.month + '1 month'::interval - '1 day'::interval)
) > 0
order by rm.month, adh.facility, adh.department

{% endmacro %}
