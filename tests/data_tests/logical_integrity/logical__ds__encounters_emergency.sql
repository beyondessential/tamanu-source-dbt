with base as (
    select count(*) as total_encounters
    from {{ ref('triages') }}
),

dataset as (
    select count(*) as total_encounters
    from {{ ref('ds__encounters_emergency') }}
)

select
    base.total_encounters as base_total_encounters,
    dataset.total_encounters as dataset_total_encounters
from base
join dataset on dataset.total_encounters != base.total_encounters
