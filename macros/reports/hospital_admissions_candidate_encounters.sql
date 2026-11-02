{% macro hospital_admissions_candidate_encounters() %}
{#-
    The encounters a hospital admissions summary can report on, as an array of ids, for the
    predicate `<episodes>.encounter_id = any({{ hospital_admissions_candidate_encounters() }})`.
    See specs/reports/hospital-admissions-summaries.md BL-016.

    The admission history intermediates number, group and `lead()` every encounter's
    history before the report sees a row, and Postgres cannot push a date range on an
    episode below those windows. It can push a predicate on `encounter_id`, which is the
    partition key of every one of them, so narrowing the encounters narrows the work.
    The array is an uncorrelated subquery, which the planner evaluates once as an initial
    plan and treats as a constant.

    Row-selecting only: the reports re-apply the exact month logic on the episodes, so this
    set may be wider than needed and may never be narrower. An encounter qualifies when its
    stored start and end dates, widened by the project's candidate window (candidate_window_from
    and candidate_window_to), overlap the month spine. The widening covers the gap between those stored dates and the timezone-converted dates
    the reports compare, which can be 26 hours apart. An encounter that records its end
    before its start has its end replaced by its start in the base model, so the start
    date is admitted on its own as well, as encounter_summary_core does.

    The bounds are compared against the stored character(19) columns, cast to
    character(19) so the comparison keeps the index-compatible operators.
-#}
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
