{% macro hospital_admissions_candidate_encounters() %}
{#-
    The encounters a hospital admissions summary can report on, as an array of ids, for the
    predicate `<episodes>.encounter_id = any({{ hospital_admissions_candidate_encounters() }})`.
    See specs/reports/hospital-admissions-summaries.md BL-016.

    Why: the admission history intermediates number, group and `lead()` every encounter's
    history before the report sees a row, and Postgres cannot push a date range on an
    episode below those windows. It can push a predicate on `encounter_id`, the partition
    key of every window, so narrowing the encounters narrows the work. The array is an
    uncorrelated subquery, evaluated once and treated as a constant.

    Which encounters: those whose stored start and end dates, widened by the project's
    candidate window (`candidate_window_from` / `candidate_window_to`), overlap the month
    spine. The widening covers the gap between the stored dates and the timezone-converted
    dates the reports compare, which can be 26 hours apart. The start date is also admitted
    on its own, because the base model replaces an end that precedes its start with the
    start (as `encounter_summary_core` does).

    This is a pre-filter only. The reports re-apply the exact month logic to the episodes,
    so the set may be wider than needed and must never be narrower.

    The bounds are cast to `character(19)` to match the stored columns, which keeps the
    comparison on index-compatible operators.
-#}
{#- month spine: the first day of the first reporting month to the first day after the last -#}
{%- set from_bound = parameter('fromDate', default_value='2024-01-01', data_type='text') -%}
{%- set to_bound = parameter('toDate', default_value='2024-01-01', data_type='text') -%}
{%- set spine_from = "concat(left(" ~ from_bound ~ ", 7), '-01')::date" -%}
{%- set spine_to = "(concat(left(" ~ to_bound ~ ", 7), '-01')::date + interval '1 month')" -%}
{%- set candidate_from -%}
to_char({{ candidate_window_from(spine_from) }}, 'YYYY-MM-DD HH24:MI:SS')::character(19)
{%- endset -%}
{%- set candidate_to -%}
to_char({{ candidate_window_to(spine_to) }}, 'YYYY-MM-DD HH24:MI:SS')::character(19)
{%- endset -%}
array(
        select ce.id
        from {{ ref('encounters') }} ce
        where ce.start_date_iso <= {{ candidate_to }}
            and (
                ce.end_date_iso is null
                or ce.end_date_iso >= {{ candidate_from }}
                or ce.start_date_iso >= {{ candidate_from }}
            )
    )
{%- endmacro %}
