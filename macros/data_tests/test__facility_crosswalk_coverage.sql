{#
    Two-way check of a crosswalk column of Tamanu facility ids against the facilities base model.
    Each returned row is a mismatch: a facility absent from the crosswalk, or a crosswalk entry
    that is not a facility. `ignore_ids` lists placeholder entries that are deliberately not
    facilities. Severity is set where the test is called.
#}
{% test facility_crosswalk_coverage(model, column_name, ignore_ids=[]) %}
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

union all

select
    crosswalk.facility_id,
    'crosswalk entry is not a facility' as problem
from crosswalk
left join facilities on facilities.facility_id = crosswalk.facility_id
where facilities.facility_id is null
{%- if ignore_ids %}
    and crosswalk.facility_id not in ({% for id in ignore_ids %}'{{ id }}'{{ ', ' if not loop.last }}{% endfor %})
{%- endif %}
{% endtest %}
