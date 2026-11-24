-- derived__episode_art -- one row per continuous period a client is on ART, assembled from the ART
-- they were supplied (int__art_supply) and closed when the supply lapses.
--
-- A client is on ART while they hold supply, and for the lost to follow-up allowance after it
-- runs out. A supply collected within that allowance continues the period, and one collected
-- after it starts a new, numbered period, which is how a re-initiation is recorded. The WHO HIV
-- indicators read the on ART state, loss to follow-up and re-initiation from these periods.
--
-- Spec: specs/dbt-model/derived__episode_art.md, BL-008..BL-016. The grain is one row per
-- client per period.

{% set ltfu_days = var('art_ltfu_days') %}

with supply as (
    select * from {{ ref('int__art_supply') }}
),

episodes as (
    select * from {{ ref('clinical__episode') }}
),

-- BL-008: a supply runs out on its date plus its days. The latest run-out date of the client's
-- earlier supply days is the supply they already hold, so a short supply inside a long one
-- does not shorten it (BL-009)
ordered as (
    select
        s.*,
        s.supply_date + s.supply_days as run_out_date,
        max(s.supply_date + s.supply_days) over (
            partition by s.subject_id
            order by s.supply_date asc
            rows between unbounded preceding and 1 preceding
        ) as prior_run_out_date
    from supply s
),

-- BL-010: a supply day starts a new period when it is the client's first, or when it falls more
-- than the allowance after the supply they held ran out. BL-015: the allowance is art_ltfu_days
flagged as (
    select
        o.*,
        case
            when o.prior_run_out_date is null then 1
            when o.supply_date > o.prior_run_out_date + {{ ltfu_days }} then 1
            else 0
        end as starts_period
    from ordered o
),

-- BL-013: a period's number is its position by start among the client's periods
numbered as (
    select
        f.*,
        sum(f.starts_period) over (
            partition by f.subject_id
            order by f.supply_date asc
            rows between unbounded preceding and current row
        ) as episode_number
    from flagged f
),

periods as (
    select
        n.subject_id,
        n.episode_number,
        min(n.supply_date) as episode_start_date,
        max(n.run_out_date) as supply_end_date,
        count(*) as supply_count,
        (array_agg(n.facility_id order by n.supply_date asc))[1] as first_supply_facility_id,
        (array_agg(n.facility_id order by n.supply_date desc))[1] as last_supply_facility_id
    from numbered n
    group by n.subject_id, n.episode_number
),

-- BL-016: the client's enrolment in the registry the deployment names, the earliest where they
-- have more than one
enrolments as (
    select distinct on (e.person_id)
        e.person_id,
        e.episode_id
    from episodes e
    where e.program_registry_id = '{{ var('art_episode_registry_id') }}'
    order by e.person_id asc, e.episode_start_datetime asc, e.episode_id asc
),

-- BL-011: a period's last day on ART is its supply end plus the allowance
dated as (
    select
        p.*,
        p.supply_end_date + {{ ltfu_days }} as last_day_on_art
    from periods p
)

select
    'episode_art'::text as metric_id,
    null::text as variant_id,
    (d.subject_id || ':' || to_char(d.episode_start_date, 'YYYY-MM-DD'))::varchar as episode_id,
    d.subject_id::varchar as subject_id,
    null::int as episode_concept_id,
    en.episode_id::varchar as episode_parent_id,
    d.episode_number::int as episode_number,
    d.episode_start_date,
    d.supply_end_date,
    d.last_day_on_art,
    -- BL-012: a period whose last day on ART has not passed, by the deployment's local date, is
    -- open, with no end date or closure reason
    case when d.last_day_on_art < {{ get_current_date() }} then d.last_day_on_art end as episode_end_date,
    case when d.last_day_on_art < {{ get_current_date() }} then 'Lost to follow-up' end as closure_reason,
    -- BL-014: a period numbered 2 or more is a re-initiation
    d.episode_number >= 2 as is_reinitiation,
    d.first_supply_facility_id::varchar as first_supply_facility_id,
    d.last_supply_facility_id::varchar as last_supply_facility_id,
    d.supply_count::int as supply_count
from dated d
left join enrolments en on en.person_id = d.subject_id
