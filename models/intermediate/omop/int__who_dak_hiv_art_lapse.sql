-- int__who_dak_hiv_art_lapse -- one row per client recorded as starting ART at a site whose ART
-- supply is known from a date, with the date they lapse to lost to follow-up where no supply
-- of theirs is recorded.
--
-- ART supplied before a site recorded it in Tamanu is not in int__art_supply, so a client whose
-- ART start was recorded on a form has no supply to run out. They are taken to hold one supply
-- from the later of their ART start and the date their site began recording supply, and to lapse
-- once it and the lost to follow-up allowance have passed.
--
-- Ephemeral, so this is inlined into its consumers and materialises nothing.
--
-- Spec: specs/dbt-model/metric__who_dak_hiv_indicators.md, BL-049..BL-051.

with answers as (
    select * from {{ ref('int__who_dak_hiv_form_answers') }}
),

supply as (
    select * from {{ ref('int__art_supply') }}
),

-- BL-051: a client's site is the facility of the submission that recorded their ART start, the
-- latest of them where there are several, with NULL submissions last (BL-029)
start_submissions as (
    select distinct on (patient_id)
        patient_id,
        facility_id as site_facility_id,
        art_start_date
    from answers
    where art_start_date is not null
    order by patient_id asc, submitted_datetime desc nulls last, response_id asc
),

-- BL-051: a site's first ART supply in Tamanu is its earliest drug exposure supply
site_first_supply as (
    select
        facility_id,
        min(supply_date) as first_supply_date
    from supply
    where has_drug_exposure
        and facility_id is not null
    group by facility_id
),

-- BL-051: else the date the deployment gives the site
{% set configured_starts = var('art_supply_start_dates') %}
configured_starts as (
    {% if configured_starts -%}
    select
        facility_id::varchar as facility_id,
        start_date::date as start_date
    from (
        values
        {%- for facility_id, start_date in configured_starts.items() %}
            ('{{ facility_id }}', '{{ start_date }}'){{ "," if not loop.last }}
        {%- endfor %}
    ) as t (facility_id, start_date)
    {%- else -%}
        select
            null::varchar as facility_id,
            null::date as start_date
        where false
    {%- endif %}
)

-- BL-050: the later of the site's first supply and the client's ART start, plus the days a held
-- supply lasts and the lost to follow-up allowance. A site with neither date has no lapse date
select
    ss.patient_id,
    ss.site_facility_id,
    ss.art_start_date,
    greatest(coalesce(sfs.first_supply_date, cs.start_date), ss.art_start_date)
    + {{ var('art_unrecorded_supply_days') }}
    + {{ var('art_ltfu_days') }} as lapse_date
from start_submissions ss
left join site_first_supply sfs on sfs.facility_id = ss.site_facility_id
left join configured_starts cs on cs.facility_id = ss.site_facility_id
where coalesce(sfs.first_supply_date, cs.start_date) is not null
