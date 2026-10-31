{%- macro parameter(parameter_name, default_value, data_type='text') -%}
    {%- if flags.WHICH == 'compile' %}
        :{{ parameter_name }}
    {%- else -%}
        {%- set param_value = var(parameter_name, default_value) -%}
        {%- if data_type is none -%}
            nullif('{{ param_value }}', '')
        {%- else -%}
            nullif('{{ param_value }}', '')::{{ data_type }}
        {%- endif -%}
    {%- endif -%}
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