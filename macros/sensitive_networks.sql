-- The sensitive facility partition. See specs/dbt-model/sensitive-facility-partition.md for the
-- BL clauses these macros implement.
--
-- A partition is `none`, the standard partition, or the code of a sensitive network listed in the
-- `sensitive_networks` var. A partitioned model's body is a macro taking the partition as
-- `network`. The standard model calls it with `network=none`, and
-- scripts/generate_sensitive_network_models.py writes one model per listed network that calls it
-- with that network's code.


-- A network's key in model names: its code lowercased, each run of other characters as `_`.
{%- macro network_key(network) -%}
    {{- return(modules.re.sub('[^a-z0-9]+', '_', network | lower) | trim('_')) -}}
{%- endmacro -%}


-- The name of `model`'s counterpart in a partition. The generator names its files the same way.
--   encounters                  sensitive_<key>_encounters
--   ds__admissions              ds__sensitive_<key>_admissions
--   admissions-line-list        sensitive-<key>-admissions-line-list
{%- macro partition_name(model, network=none) -%}
    {%- if network is none -%}
        {{- return(model) -}}
    {%- endif -%}
    {%- set key = network_key(network) -%}
    {%- if '__' in model -%}
        {%- set parts = model.split('__', 1) -%}
        {{- return(parts[0] ~ '__sensitive_' ~ key ~ '_' ~ parts[1]) -}}
    {%- elif '-' in model -%}
        {{- return('sensitive-' ~ (key | replace('_', '-')) ~ '-' ~ model) -}}
    {%- else -%}
        {{- return('sensitive_' ~ key ~ '_' ~ model) -}}
    {%- endif -%}
{%- endmacro -%}


-- BL-015: a partitioned model reads the inputs of its own partition.
{%- macro partition_ref(model, network=none) -%}
    {{- return(ref(partition_name(model, network))) -}}
{%- endmacro -%}


-- BL-001: the facilities of one partition, as a predicate on a `facilities` row. `alias` is that
-- row's table alias, with its trailing dot. A facility in a network the deployment does not list
-- matches no partition (BL-010).
{%- macro facility_in_partition(network=none, alias='') -%}
    {%- if network is none -%}
        {{ alias }}sensitive_network_id is null
    {%- else -%}
        {{ alias }}sensitive_network_id in (
            select sn.id::text
            from {{ source('tamanu', 'sensitive_networks') }} sn
            where sn.code = '{{ network }}'
                and sn.deleted_at is null
        )
    {%- endif -%}
{%- endmacro -%}


-- The sensitive networks the deployment lists, as a list of codes. The var is a list, and a
-- comma-separated string is read the same way, for tools that pass vars as text.
{%- macro listed_sensitive_networks() -%}
    {%- set listed = var('sensitive_networks', []) -%}
    {%- if listed is string -%}
        {%- set listed = listed.split(',') | map('trim') | select | list -%}
    {%- endif -%}
    {{- return(listed) -}}
{%- endmacro -%}


-- BL-014: `columns` of `model` from every partition the deployment has, as one relation.
{%- macro every_partition(model, columns) -%}
    select {{ columns | join(', ') }}
    from {{ ref(model) }}
    {%- for network in listed_sensitive_networks() %}
        union all
        select {{ columns | join(', ') }}
        from {{ partition_ref(model, network) }}
    {%- endfor -%}
{%- endmacro -%}
