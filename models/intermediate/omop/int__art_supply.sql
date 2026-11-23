-- int__art_supply -- one row per client per day they were supplied ART: the medications in
-- map__art_medications supplied in Tamanu, and the days of ART a WHO HIV form records as
-- dispensed.
--
-- A supply is the unit derived__episode_art assembles periods on ART from, so ART supplied
-- before a site dispensed it in Tamanu, and historical records, count alongside the ART Tamanu
-- dispenses itself.
--
-- Ephemeral, so this is inlined into its consumers and materialises nothing.
--
-- Spec: specs/dbt-model/derived__episode_art.md, BL-001..BL-007.

{% set exposure_types = var('art_supply_exposure_types') %}

with drug_exposures as (
    select * from {{ ref('clinical__drug_exposure') }}
),

visits as (
    select
        visit_occurrence_id,
        care_site_id
    from {{ ref('clinical__visit_occurrence') }}
),

sites as (
    select
        care_site_id,
        facility_id
    from {{ ref('ref__care_site_location') }}
),

art_medications as (
    select * from {{ ref('map__art_medications') }}
),

answers as (
    select * from {{ ref('int__who_dak_hiv_form_answers') }}
),

plhiv as (
    {{ who_dak_hiv_plhiv('answers') }}
),

-- BL-001, BL-002: a drug exposure of a listed medication, of a type the deployment counts as
-- ART supplied. BL-003: its quantity is its days of supply at one unit a day, dated on its start
exposure_supply as (
    select
        de.person_id::varchar as subject_id,
        de.drug_exposure_start_date as supply_date,
        floor(de.quantity) as supply_days,
        s.facility_id::varchar as facility_id,
        true as has_drug_exposure
    from drug_exposures de
    join art_medications am on am.medication_code = de.drug_source_value
    left join visits v on v.visit_occurrence_id = de.visit_occurrence_id
    left join sites s on s.care_site_id = v.care_site_id
    where de.drug_exposure_type_source_value in (
            {%- for exposure_type in exposure_types %}
                '{{ exposure_type }}'{{ "," if not loop.last }}
            {%- endfor %}
        )
),

-- BL-001, BL-004: the days of ART dispensed on a form, dated on its submission's date
form_supply as (
    select
        a.patient_id::varchar as subject_id,
        a.submitted_datetime::date as supply_date,
        floor(a.art_days_dispensed) as supply_days,
        a.facility_id::varchar as facility_id,
        false as has_drug_exposure
    from answers a
    where a.art_days_dispensed is not null
        and a.submitted_datetime is not null
),

supply as (
    select * from exposure_supply
    union all
    select * from form_supply
)

-- BL-005: a supply of under a day or over 366 days is not a supply record. BL-006: a client's
-- records on one day are one supply day covering the largest of their days, at the facility of
-- the largest drug exposure record that has one, else of the largest form record. BL-007: only for clients living with HIV
select
    s.subject_id,
    s.supply_date,
    max(s.supply_days)::int as supply_days,
    (array_agg(s.facility_id order by s.facility_id is null, s.has_drug_exposure desc, s.supply_days desc))[1] as facility_id,
    bool_or(s.has_drug_exposure) as has_drug_exposure
from supply s
join plhiv on plhiv.patient_id = s.subject_id
where s.supply_days between 1 and 366
    and s.supply_date is not null
group by s.subject_id, s.supply_date
