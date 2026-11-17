-- ref__location -- OMOP LOCATION wrapper over Tamanu geographic reference data.
-- One row per village (BL-001..BL-002), denormalised with its subdivision, division,
-- and country resolved by walking reference_data_relations (BL-003..BL-004).
-- Sources only from bases/ (D10); OMOP column naming applied (D2).
-- See specs/dbt-model/ref__location.md.

with recursive places as (
    select
        id,
        code,
        name,
        type as level
    from {{ ref('reference_data') }}
    -- every level of the address hierarchy is kept so the ancestor chain above a
    -- village stays connected even where an intermediate level (e.g. settlement)
    -- sits between two emitted levels, though only villages are emitted (BL-002)
    where type in ('village', 'settlement', 'subdivision', 'division', 'country')
),

-- parent links where both ends are geographic places, so the walk stays inside
-- the address hierarchy without depending on the relation's own type (BL-002)
relations as (
    select
        r.reference_data_id as child_id,
        r.reference_data_parent_id as parent_id
    from {{ ref('reference_data_relations') }} r
    inner join places c on c.id = r.reference_data_id
    inner join places par on par.id = r.reference_data_parent_id
),

-- each village paired with itself and every ancestor (BL-003)
-- (cast to text so the anchor and recursive terms share a column type)
-- depth guard: reference_data_relations is user-maintained with no DB-level
-- acyclicity constraint, so a data cycle (A->B->A) would otherwise recurse until
-- it exhausts memory. The address hierarchy is at most 5 levels
-- (village->settlement->subdivision->division->country), so depth < 10 is ample
-- headroom while still bounding a cyclic walk.
ancestry (location_id, ancestor_id, depth) as (
    select id::text, id::text, 0 from places where level = 'village'
    union all
    select a.location_id, r.parent_id::text, a.depth + 1
    from ancestry a
    inner join relations r on r.child_id = a.ancestor_id
    where a.depth < 10
),

ancestor_levels as (
    select
        a.location_id,
        p.level as ancestor_level,
        p.name as ancestor_name
    from ancestry a
    inner join places p on p.id = a.ancestor_id
)

-- one row per village; the village name is the OMOP city, ancestor levels map onto
-- the remaining OMOP LOCATION columns where available. This CASE is the per-deployment
-- adjustment point if a deployment's level->column correspondence differs (BL-004)
select
    pl.id as location_id,
    pl.code as location_source_value,
    pl.name as city,
    max(case when al.ancestor_level = 'subdivision' then al.ancestor_name end)
        as county,
    max(case when al.ancestor_level = 'division' then al.ancestor_name end)
        as state,
    max(case when al.ancestor_level = 'country' then al.ancestor_name end)
        as country_source_value
from places pl
left join ancestor_levels al on al.location_id = pl.id
where pl.level = 'village'
group by pl.id, pl.code, pl.name
