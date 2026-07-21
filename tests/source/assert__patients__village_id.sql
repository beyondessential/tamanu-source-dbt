{{ config(meta={'dagster': {'ref': {'name': 'patients', 'package': 'tamanu_source_dbt'}}}) }}

select rd.id
from {{ source("tamanu", "patients") }} p
left join {{ source("tamanu", "reference_data") }} rd on rd.id = p.village_id
where p.village_id is not null
    and rd.id is null
