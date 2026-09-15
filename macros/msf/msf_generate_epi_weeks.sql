{% macro msf_generate_epi_weeks(start_dow, from_year, label_infix='W', pad=2) %}
{#
    Epidemiological-week lookup relation: one row per epi week.

    Generalises the MSF Syria int__epi_dates_{sat,sun}_start models onto a
    single start-day parameter. Week rule (all variants): the first epi week
    of a year is the week containing 4 January (i.e. the first week with at
    least 4 days in January), weeks run 7 days from `start_dow`. With
    start_dow=1 (Monday) this is exactly ISO 8601 numbering.

    Parameters:
    - start_dow: Postgres day-of-week the epi week starts on
        (0=Sunday, 1=Monday, ... 6=Saturday)
    - from_year: first epi year to generate (int). Generation runs through
      current year + 1 so trailing-window reports never fall off the end.
    - label_infix: string between year and week number in epi_yearweek
        ('W' -> 2026W01; 'SunW' -> 2026SunW01 as used by MSF Syria)
    - pad: zero-padding width for the week number in epi_yearweek. DHIS2's
      canonical weekly period format is unpadded (2026W1); check what the
      target dataset expects before relying on the label as the DHIS2 period.
      week_number is also exposed so consumers can format their own label.

    Columns: epi_year, week_number, week_start, week_end, epi_yearweek.
    Consumers join on `date between week_start and week_end`.

    Usage (deployment repo, ephemeral model):
        {{ msf_generate_epi_weeks(start_dow=1, from_year=2026) }}
#}
with epi_years as (
    select
        year,
        to_date(year::text || '-01-04', 'YYYY-MM-DD') as jan4,
        to_date((year + 1)::text || '-01-04', 'YYYY-MM-DD') as next_jan4
    from generate_series({{ from_year }}, extract(year from {{ get_current_date() }})::int + 1) as year
),

year_bounds as (
    select
        year as epi_year,
        (jan4
            - ((extract(dow from jan4)::int - {{ start_dow }} + 7) % 7) * interval '1 day'
        )::date as epi_date_from,
        (next_jan4
            - ((extract(dow from next_jan4)::int - {{ start_dow }} + 7) % 7) * interval '1 day'
            - interval '1 day'
        )::date as epi_date_to
    from epi_years
)

select
    yb.epi_year,
    row_number() over (partition by yb.epi_year order by week_start) as week_number,
    week_start::date as week_start,
    least((week_start + interval '6 days')::date, yb.epi_date_to) as week_end,
    yb.epi_year::text || '{{ label_infix }}' || lpad(
        (row_number() over (partition by yb.epi_year order by week_start))::text,
        {{ pad }},
        '0'
    ) as epi_yearweek
from year_bounds yb
cross join lateral generate_series(
    yb.epi_date_from,
    yb.epi_date_to,
    '1 week'::interval
) week_start
{% endmacro %}
