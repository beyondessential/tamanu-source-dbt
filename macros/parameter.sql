{%- macro parameter(parameter_name, default_value, data_type='text') -%}
    {%- if flags.WHICH == 'compile' %}
        :{{ parameter_name }}
    {%- else -%}
        {%- set param_value = var(parameter_name, default_value) -%}
        {%- if param_value is defined and param_value is iterable and param_value is not string -%}
            {#- A list var stands for a multi-select: each value renders as a literal, comma separated,
                the way Tamanu expands a selection, and an empty list renders nothing. -#}
            {%- for value in param_value -%}
                '{{ value }}'{% if data_type is not none %}::{{ data_type }}{% endif %}{{ ', ' if not loop.last }}
            {%- endfor -%}
        {%- elif data_type is none -%}
            nullif('{{ param_value }}', '')
        {%- else -%}
            nullif('{{ param_value }}', '')::{{ data_type }}
        {%- endif -%}
    {%- endif -%}
{%- endmacro %}

{%- macro multi_select_filter(text_expression, parameter_name) -%}
    {#- Filter for a multi-select report parameter: nothing selected keeps every row, otherwise a
        row is kept when text_expression equals any selected value. text_expression is a SQL
        expression of type text, for example `status_id::text`.

        Tamanu expands a selection into a comma-separated list of literals and an empty
        selection, which the form sends as [], into nothing. The list therefore goes through an
        array constructor: array[]::text[] is valid where coalesce() and in () are not, and a
        scalar comparison fails once several values expand to 'a','b'.

        Declare the parameter as a multi-select in the report config; see
        documentations/tamanu-report-configuration-schema.md. -#}
    {%- set selection = parameter(parameter_name) | trim -%}
    (cardinality(array_remove(array[{{ selection }}]::text[], null)) = 0 or {{ text_expression }} = any(array[{{ selection }}]::text[]))
{%- endmacro %}

{%- macro date_param_bound(parameter_name, default_value) -%}
    {#- parameter() compiles to an untyped placeholder, so a caller doing interval
        arithmetic on the result needs the explicit cast -- without it `:toDate + interval`
        reaches interval parsing and errors. -#}
    ({{ parameter(parameter_name, default_value=default_value, data_type='date') | trim }})::date
{%- endmacro %}

{%- macro candidate_window_from(from_bound) -%}
    {#- BL: a candidate-scoping report's early-filter window, widened below the exact date
        range it will re-apply exactly. The candidate compares deployment-local time while the
        report's final WHERE compares the viewer's selected timezone, which can sit up to 26
        hours apart (UTC-12 to UTC+14), so a value right at the boundary under one timezone can
        fall outside it under the other. ±2/+3 days is this project's standing margin for that
        offset -- see specs/reports/audit-patient-identity-change.md (tamanu-dbt-samoa) BL-017,
        the pattern this follows. -#}
    {{ from_bound }} - interval '2 days'
{%- endmacro %}

{%- macro candidate_window_to(to_bound) -%}
    {{ to_bound }} + interval '3 days'
{%- endmacro %}