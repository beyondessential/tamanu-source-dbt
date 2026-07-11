{% macro dhis_datavalue_union(metric_configs, org_level='clinic') %}
{#
    DHIS2 datavalue presentation join over metric__ views.

    Emits the standard 6-column DHIS2 datavalue shape (dataelement, period,
    orgunit, categoryoptioncombo, attributeoptioncombo, value) as a UNION ALL
    over one or more metric__ views in the D5 wide format (metric_id,
    period_start, value_numeric, facility_id, + disaggregation columns).
    All semantic logic belongs upstream in the metric layer; this macro is
    presentation only — a generalisation of MSF Syria's
    dhis_ncd_indicator_union onto the metric architecture.

    metric_configs: list of dicts, one per metric__ view:
    - metric_model (required): metric__ view name. Must expose metric_id,
      period_start, value_numeric, and the facility/disaggregation columns
      referenced below.
    - de_map (required): data-element mapping model with columns
      (id, indicator); joined on indicator = metric_id.
    - coc_map (optional): category-option-combo mapping model. When present,
      coc_join_columns (list of column names shared by the COC map and the
      metric view) is required. When absent the report is undisaggregated
      and categoryoptioncombo falls back to var('dhis_attributeoptioncombo')
      — the DHIS2 default COC.
    - period_expr (optional): SQL over alias `m` producing the DHIS2 period
      string. Defaults to the monthly format
      to_char(m.period_start, var('yearmonth_format')). Weekly reports pass
      their own expression (e.g. an epi_yearweek column carried on the
      metric view or joined from generate_epi_weeks output).
    - value_expr (optional): defaults to m.value_numeric.
    - facility_column (optional): defaults to facility_id.

    org_level: dhis_org_level filter on map__dhis_orgunit (deployment repos
    register one org-unit row per reporting granularity).

    Usage (deployment repo report SQL):
        {{ dhis_datavalue_union([
            {'metric_model': 'metric__mental_health_sessions',
             'de_map': 'map__dhis_de_mental_health'},
            ...
        ]) }}
#}
{% for config in metric_configs %}
select
    de.id as dataelement,
    {{ config.get('period_expr', "to_char(m.period_start, '" ~ var('yearmonth_format') ~ "')") }} as period,
    ou.dhis_org_unit_id as orgunit,
    {% if config.get('coc_map') -%}
    coc.id as categoryoptioncombo,
    {%- else -%}
    '{{ var("dhis_attributeoptioncombo") }}' as categoryoptioncombo,
    {%- endif %}
    '{{ var("dhis_attributeoptioncombo") }}' as attributeoptioncombo,
    {{ config.get('value_expr', 'm.value_numeric') }} as value
from {{ ref(config.metric_model) }} m
join {{ ref(config.de_map) }} de
    on de.indicator = m.metric_id
{% if config.get('coc_map') -%}
join {{ ref(config.coc_map) }} coc
    on {% for col in config.coc_join_columns -%}
    coc.{{ col }} = m.{{ col }} {%- if not loop.last %} and {% endif %}
    {%- endfor %}
{% endif -%}
join {{ ref('map__dhis_orgunit') }} ou
    on ou.tamanu_facility_id = m.{{ config.get('facility_column', 'facility_id') }}
    and ou.dhis_org_level = '{{ org_level }}'
{%- if not loop.last %}

union all

{% endif %}
{% endfor %}
{% endmacro %}
