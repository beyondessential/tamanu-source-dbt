-- Post-hook for every model in this package (set in dbt_project.yml). Collects planner
-- statistics on a table as soon as dbt has built it, in the same transaction.
-- Autovacuum only gets to a new table within about a minute. A model that reads the table
-- before then is planned without statistics, and Postgres can pick a plan that runs for an
-- hour instead of seconds. Views hold no rows, so the hook renders nothing for them and dbt
-- skips it.
{% macro analyze_after_build() -%}
    {%- if config.get('materialized') in ('table', 'incremental') -%}
        analyze {{ this }}
    {%- endif -%}
{%- endmacro %}
