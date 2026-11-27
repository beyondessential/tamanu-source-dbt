-- int__art_supply_periods -- each day a client was supplied ART, with the period on ART it falls
-- in. derived__episode_art collapses these into one row per period. A consumer that needs a
-- client's supply and period as they stood on a past date reads them here, filtered to the supply
-- days up to that date.
--
-- A supply collected within the lost to follow-up allowance after the supply a client already
-- held runs out continues their period, and one collected after it starts a new, numbered period.
--
-- Spec: specs/dbt-model/derived__episode_art.md, BL-008, BL-010, BL-013 to BL-015 and BL-017. The
-- grain is one row per client per supply day.

{% set ltfu_days = var('art_ltfu_days') %}

with supply as (
    select * from {{ ref('int__art_supply') }}
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

-- BL-013: a period's number is its position by start among the client's periods. BL-017: the
-- latest period start up to a supply day is its period's first supply day
numbered as (
    select
        f.*,
        sum(f.starts_period) over (
            partition by f.subject_id
            order by f.supply_date asc
            rows between unbounded preceding and current row
        ) as episode_number,
        max(case when f.starts_period = 1 then f.supply_date end) over (
            partition by f.subject_id
            order by f.supply_date asc
            rows between unbounded preceding and current row
        ) as episode_start_date
    from flagged f
)

select
    n.subject_id,
    n.supply_date,
    n.supply_days,
    n.facility_id,
    n.has_drug_exposure,
    n.run_out_date,
    n.episode_number::int as episode_number,
    n.episode_start_date,
    -- BL-014: a period numbered 2 or more is a re-initiation
    n.episode_number >= 2 as is_reinitiation
from numbered n
