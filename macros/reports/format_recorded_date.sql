-- Formats a date held as 'YYYY-MM-DD' text, such as a date of birth read from change history.
-- A value that is a calendar date is shown in the report's date format. Anything else is shown
-- as 'Invalid date (<recorded value>)', so the report keeps what was recorded.
-- The nested case fixes the order of evaluation: the day is only checked once the shape is
-- known to be a date, and the value is only cast once the day is known to exist.
{% macro format_recorded_date(column) -%}
    case
        when {{ column }} is null then null
        when {{ column }} !~ '^\d{4}-(0[1-9]|1[0-2])-(0[1-9]|[12]\d|3[01])$'
            then 'Invalid date (' || {{ column }} || ')'
        else
            case
                when to_char(
                        ((left({{ column }}, 7) || '-01')::date + (right({{ column }}, 2)::int - 1))::timestamp,
                        'YYYY-MM-DD'
                    ) = {{ column }}
                    then to_char({{ column }}::date::timestamp, '{{ var("date_format") }}')
                else 'Invalid date (' || {{ column }} || ')'
            end
    end
{%- endmacro %}
