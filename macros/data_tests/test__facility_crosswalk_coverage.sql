{#
    Two-way check of a crosswalk column of Tamanu facility ids against the facilities base model.
    Each returned row is a mismatch: a facility absent from the crosswalk, or a crosswalk entry
    that is not a facility. Historical facilities are checked like any other.
    `unmapped_facility_ids` lists Tamanu facilities that are deliberately left out of the
    crosswalk. `ignore_ids` lists placeholder entries that are deliberately not facilities.
    Severity is set where the test is called.
#}
{% test facility_crosswalk_coverage(model, column_name, unmapped_facility_ids=[], ignore_ids=[]) %}
with facilities as (
    select id as facility_id
    from {{ ref('facilities') }}
),

crosswalk as (
    select distinct {{ column_name }} as facility_id
    from {{ model }}
    where {{ column_name }} is not null
)

select
    facilities.facility_id,
    'facility missing from crosswalk' as problem
from facilities
left join crosswalk on crosswalk.facility_id = facilities.facility_id
where crosswalk.facility_id is null
{%- if unmapped_facility_ids %}
    and facilities.facility_id not in ({{ _facility_crosswalk_id_list(unmapped_facility_ids) }})
{%- endif %}

union all

select
    crosswalk.facility_id,
    'crosswalk entry is not a facility' as problem
from crosswalk
left join facilities on facilities.facility_id = crosswalk.facility_id
where facilities.facility_id is null
{%- if ignore_ids %}
    and crosswalk.facility_id not in ({{ _facility_crosswalk_id_list(ignore_ids) }})
{%- endif %}
{% endtest %}

{% macro _facility_crosswalk_id_list(ids) -%}
    {%- for id in ids -%}
        '{{ id | replace("'", "''") }}'{{ ', ' if not loop.last }}
    {%- endfor -%}
{%- endmacro %}
