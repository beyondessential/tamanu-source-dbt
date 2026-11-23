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
--   encounters                  sn_<key>_encounters
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
        {#- a base: the short prefix keeps the longest base name within Postgres's 63 characters -#}
        {{- return('sn_' ~ key ~ '_' ~ model) -}}
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


-- BL-014: `columns` of `model`, every column unless given, from every partition the deployment
-- has, as one relation.
{%- macro every_partition(model, columns=['*']) -%}
    select {{ columns | join(', ') }}
    from {{ ref(model) }}
    {%- for network in listed_sensitive_networks() %}
        union all
        select {{ columns | join(', ') }}
        from {{ partition_ref(model, network) }}
    {%- endfor -%}
{%- endmacro -%}


-- BL-014: `model` from every partition, for a from or join clause that must stay a plain
-- relation where the deployment lists no network. Give it an alias.
{%- macro every_partition_relation(model) -%}
    {%- if listed_sensitive_networks() -%}
        ({{ every_partition(model) }})
    {%- else -%}
        {{ ref(model) }}
    {%- endif -%}
{%- endmacro -%}


-- The predicates below place a base's row in a partition by the facility its link resolves to.
-- Each takes the SQL expression holding the link. A link that is null, or resolves to no
-- facility, is standard (BL-003), and one resolving to a facility in an unlisted network is in
-- no partition (BL-010). They read the source tables, as only a base may.

-- A row linked to a facility.
{%- macro facility_id_in_partition(facility_id, network=none) -%}
    {%- if network is none -%}
        not exists (
            select 1
            from {{ source('tamanu', 'facilities') }} pf
            where pf.id = {{ facility_id }}
                and pf.sensitive_network_id is not null
        )
    {%- else -%}
        exists (
            select 1
            from {{ source('tamanu', 'facilities') }} pf
            where pf.id = {{ facility_id }}
                and {{ facility_in_partition(network, 'pf.') }}
        )
    {%- endif -%}
{%- endmacro -%}


-- A row linked to a location.
{%- macro location_id_in_partition(location_id, network=none) -%}
    {{ 'not ' if network is none }}exists (
        select 1
        from {{ source('tamanu', 'locations') }} pl
        join {{ source('tamanu', 'facilities') }} pf on pf.id = pl.facility_id
        where pl.id = {{ location_id }}
            and {{ 'pf.sensitive_network_id is not null' if network is none else facility_in_partition(network, 'pf.') }}
    )
{%- endmacro -%}


-- A row linked to a location group.
{%- macro location_group_id_in_partition(location_group_id, network=none) -%}
    {{ 'not ' if network is none }}exists (
        select 1
        from {{ source('tamanu', 'location_groups') }} plg
        join {{ source('tamanu', 'facilities') }} pf on pf.id = plg.facility_id
        where plg.id = {{ location_group_id }}
            and {{ 'pf.sensitive_network_id is not null' if network is none else facility_in_partition(network, 'pf.') }}
    )
{%- endmacro -%}


-- BL-006: a prescription takes the partition of the encounter it is prescribed in. An ongoing
-- prescription with no encounter is standard.
{%- macro prescription_id_in_partition(prescription_id, network=none) -%}
    {{ 'not ' if network is none }}exists (
        select 1
        from {{ source('tamanu', 'encounter_prescriptions') }} pep
        join {{ source('tamanu', 'encounters') }} pe on pe.id = pep.encounter_id
        join {{ source('tamanu', 'locations') }} pl on pl.id = pe.location_id
        join {{ source('tamanu', 'facilities') }} pf on pf.id = pl.facility_id
        where pep.prescription_id = {{ prescription_id }}
            and {{ 'pf.sensitive_network_id is not null' if network is none else facility_in_partition(network, 'pf.') }}
    )
{%- endmacro -%}


-- BL-007: a note on an encounter, triage, lab request or imaging request takes that encounter's
-- partition. A note on a patient or a care plan resolves to no encounter, so it is standard.
{%- macro note_in_partition(record_type, record_id, network=none) -%}
    {{ 'not ' if network is none }}exists (
        select 1
        from {{ source('tamanu', 'encounters') }} pe
        join {{ source('tamanu', 'locations') }} pl on pl.id = pe.location_id
        join {{ source('tamanu', 'facilities') }} pf on pf.id = pl.facility_id
        where pe.id = case {{ record_type }}
            when 'Encounter' then {{ record_id }}
            when 'Triage' then (
                select pt.encounter_id
                from {{ source('tamanu', 'triages') }} pt
                where pt.id = {{ record_id }}
            )
            when 'LabRequest' then (
                select plr.encounter_id
                from {{ source('tamanu', 'lab_requests') }} plr
                where plr.id = {{ record_id }}
            )
            when 'ImagingRequest' then (
                select pir.encounter_id
                from {{ source('tamanu', 'imaging_requests') }} pir
                where pir.id = {{ record_id }}
            )
        end
            and {{ 'pf.sensitive_network_id is not null' if network is none else facility_in_partition(network, 'pf.') }}
    )
{%- endmacro -%}


-- BL-004, BL-005: a row linked to an encounter takes the partition of the encounter's current
-- location. A base that already joins the encounter passes its location to
-- location_id_in_partition() instead.
{%- macro encounter_id_in_partition(encounter_id, network=none) -%}
    {{ 'not ' if network is none }}exists (
        select 1
        from {{ source('tamanu', 'encounters') }} pe
        join {{ source('tamanu', 'locations') }} pl on pl.id = pe.location_id
        join {{ source('tamanu', 'facilities') }} pf on pf.id = pl.facility_id
        where pe.id = {{ encounter_id }}
            and {{ 'pf.sensitive_network_id is not null' if network is none else facility_in_partition(network, 'pf.') }}
    )
{%- endmacro -%}
