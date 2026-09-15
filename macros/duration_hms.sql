{#
Formats the interval between two timestamps as total hours:minutes:seconds
(e.g. 53:28:00), or NULL when either end is missing or the interval is negative.

`to_char(interval, 'HH24:MI:SS')` wraps at 24 hours, so a stay longer than a day
would render incorrectly -- the total-hours component is built by hand instead.

Note: macros/reports/encounter_summary.sql carries a near-identical expression
inline for its own triage waiting-time column. It differs only in rendering a
zero-length interval as blank rather than 00:00:00, so it is left alone here
rather than switched over as a silent behaviour change.
#}
{%- macro duration_hms(start_field, end_field) -%}
case
    when {{ start_field }} is not null and {{ end_field }} is not null and {{ end_field }} >= {{ start_field }}
        then concat(
            lpad((
                extract(day from ({{ end_field }} - {{ start_field }})) * 24
                + extract(hour from ({{ end_field }} - {{ start_field }}))
            )::text, 2, '0'), ':',
            lpad(extract(minute from ({{ end_field }} - {{ start_field }}))::text, 2, '0'), ':',
            lpad((extract(second from ({{ end_field }} - {{ start_field }}))::int)::text, 2, '0')
        )
end
{%- endmacro -%}
