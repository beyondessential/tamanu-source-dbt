{#
    The date at the start of a text value that begins with an ISO date (YYYY-MM-DD), or NULL when it
    does not begin with one, the date does not exist (2026-02-30), or its year is before 1000, which
    is a mistyped year (0025) rather than a real date. Postgres has no try_cast, so the month and day
    are checked before the cast rather than letting a bad answer fail the build. The nested CASE
    makes the checks run in order.

        {{ safe_iso_date('v.contact_date_raw') }}
#}
{% macro safe_iso_date(text_expr) %}
case
    when {{ text_expr }} ~ '^[1-9][0-9]{3}-(0[1-9]|1[0-2])-(0[1-9]|[12][0-9]|3[01])' then
        case
            when substr({{ text_expr }}, 9, 2)::integer
                <= extract(day from (left({{ text_expr }}, 7) || '-01')::date + interval '1 month' - interval '1 day')
                then left({{ text_expr }}, 10)::date
        end
end
{% endmacro %}
