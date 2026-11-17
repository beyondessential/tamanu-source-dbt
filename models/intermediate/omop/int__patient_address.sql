-- int__patient_address -- one row per patient: the location the patient is grouped under, as the
-- location_id key that ref__location and clinical__person share, with the place ids that location
-- carries. Here a patient's location is their village. A deployment that groups patients by other
-- places replaces this model and keeps its columns.
-- See specs/dbt-model/ref__location.md for the BL clauses this model implements.
-- BL-001: reads the reference_data, reference_data_relations and patients bases only

with recursive places as (
    select
        id,
        code,
        type as level
    from {{ ref('reference_data') }}
    -- BL-003: every address level is kept, so a settlement between a village and its
    -- subdivision keeps the chain connected
    where type in ('village', 'settlement', 'subdivision', 'division', 'country')
),

-- BL-003: only links whose both ends are places, so the walk stays inside the address hierarchy
relations as (
    select
        r.reference_data_id as child_id,
        r.reference_data_parent_id as parent_id
    from {{ ref('reference_data_relations') }} r
    inner join places c on c.id = r.reference_data_id
    inner join places par on par.id = r.reference_data_parent_id
),

-- BL-003: each village paired with itself and every ancestor. reference_data_relations has no
-- acyclicity constraint, so the depth guard bounds a cyclic walk (the hierarchy is at most 5 deep)
ancestry (village_id, ancestor_id, depth) as (
    select
        id::text,
        id::text,
        0
    from places
    where level = 'village'
    union all
    select
        a.village_id,
        r.parent_id::text,
        a.depth + 1
    from ancestry a
    inner join relations r on r.child_id = a.ancestor_id
    where a.depth < 10
),

-- BL-004: a village's subdivision, division and country are its ancestors at those levels
village_levels as (
    select
        a.village_id,
        max(case when p.level = 'subdivision' then p.id end) as subdivision_id,
        max(case when p.level = 'division' then p.id end) as division_id,
        max(case when p.level = 'country' then p.id end) as country_id
    from ancestry a
    inner join places p on p.id = a.ancestor_id
    group by a.village_id
)

select
    p.id as patient_id,
    -- BL-002: the patient's location is their village, keyed by its id and coded by its code
    p.village_id as location_id,
    v.code as location_source_value,
    p.village_id,
    vl.subdivision_id,
    vl.division_id,
    vl.country_id
from {{ ref('patients') }} p
left join places v on v.id = p.village_id and v.level = 'village'
left join village_levels vl on vl.village_id = p.village_id
