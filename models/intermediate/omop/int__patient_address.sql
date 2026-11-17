-- int__patient_address -- one row per patient: the village, subdivision, division and country
-- their address resolves to, and the location_id key ref__location and clinical__person share.
-- See specs/dbt-model/ref__location.md for the BL clauses this model implements.
-- BL-001: reads the reference_data, reference_data_relations, patients and patient_additional_data bases only

with recursive places as (
    select
        id,
        type as level
    from {{ ref('reference_data') }}
    -- BL-002: every address level is kept, so a settlement between a village and its
    -- subdivision keeps the chain connected
    where type in ('village', 'settlement', 'subdivision', 'division', 'country')
),

-- BL-002: only links whose both ends are places, so the walk stays inside the address hierarchy
relations as (
    select
        r.reference_data_id as child_id,
        r.reference_data_parent_id as parent_id
    from {{ ref('reference_data_relations') }} r
    inner join places c on c.id = r.reference_data_id
    inner join places par on par.id = r.reference_data_parent_id
),

-- BL-002: each place paired with itself and every ancestor. reference_data_relations has no
-- acyclicity constraint, so the depth guard bounds a cyclic walk (the hierarchy is at most 5 deep)
ancestry (place_id, ancestor_id, depth) as (
    select
        id::text,
        id::text,
        0
    from places
    union all
    select
        a.place_id,
        r.parent_id::text,
        a.depth + 1
    from ancestry a
    inner join relations r on r.child_id = a.ancestor_id
    where a.depth < 10
),

place_levels as (
    select
        a.place_id,
        max(case when p.level = 'subdivision' then p.id end) as subdivision_id,
        max(case when p.level = 'division' then p.id end) as division_id,
        max(case when p.level = 'country' then p.id end) as country_id
    from ancestry a
    inner join places p on p.id = a.ancestor_id
    group by a.place_id
),

recorded as (
    select
        p.id as patient_id,
        -- BL-003: the patient's village
        p.village_id,
        pad.subdivision_id,
        pad.division_id
    from {{ ref('patients') }} p
    left join {{ ref('patient_additional_data') }} pad on pad.patient_id = p.id
),

with_subdivision as (
    select
        r.patient_id,
        r.village_id,
        -- BL-004: the recorded subdivision, else the village's
        coalesce(r.subdivision_id, vl.subdivision_id) as subdivision_id,
        r.division_id as recorded_division_id,
        vl.division_id as village_division_id,
        vl.country_id as village_country_id
    from recorded r
    left join place_levels vl on vl.place_id = r.village_id
),

resolved as (
    select
        ws.patient_id,
        ws.village_id,
        ws.subdivision_id,
        -- BL-005: the recorded division, else the subdivision's, else the village's
        coalesce(ws.recorded_division_id, sl.division_id, ws.village_division_id) as division_id,
        sl.country_id as subdivision_country_id,
        ws.village_country_id
    from with_subdivision ws
    left join place_levels sl on sl.place_id = ws.subdivision_id
)

select
    r.patient_id,
    r.village_id,
    r.subdivision_id,
    r.division_id,
    -- BL-006: the division's country, else the subdivision's, else the village's
    coalesce(dl.country_id, r.subdivision_country_id, r.village_country_id) as country_id,
    -- BL-007: the address key, unknown for an unresolved level, NULL with no level at all
    case
        when coalesce(r.village_id, r.subdivision_id, r.division_id) is not null
            then concat_ws(
                    '_',
                    coalesce(r.village_id, 'unknown'),
                    coalesce(r.subdivision_id, 'unknown'),
                    coalesce(r.division_id, 'unknown')
                )
    end as location_id
from resolved r
left join place_levels dl on dl.place_id = r.division_id
