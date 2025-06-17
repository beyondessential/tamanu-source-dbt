with epi_years as (
    select generate_series(2021, extract(year from current_date)::int) as year
)

select
    year as epi_year,
    to_date(year::text, 'YYYY')
    + case when extract(dow from to_date(year::text, 'YYYY')) <= 1
            then concat((-1 - extract(dow from to_date(year::text, 'YYYY')))::text, 'day')::interval
        else concat((6 - extract(dow from to_date(year::text, 'YYYY')))::text, 'day')::interval
    end as epi_date_from,
    to_date((year + 1)::text, 'YYYY')
    + case when extract(dow from to_date((year + 1)::text, 'YYYY')) <= 1
            then concat((-2 - extract(dow from to_date((year + 1)::text, 'YYYY')))::text, 'day')::interval
        else concat((5 - extract(dow from to_date((year + 1)::text, 'YYYY')))::text, 'day')::interval
    end as epi_date_to
from epi_years
