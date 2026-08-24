-- int__who_dak_hiv_key_populations -- one row per DAK HIV client per key population they are
-- recorded as belonging to (BL-022).
--
-- Annex C asks for a key population disaggregation on most of its indicators, and the DAK
-- collects it as a MultiSelect (HIV.B.DE50 on the HTS visit, HIV.E.DE114 on the PMTCT pathway):
-- a client can be a sex worker and a person who injects drugs at once. That is why this is a
-- bridge rather than a column on the counts -- a column would force one value per client, and
-- the honest alternative, one row per pair, would double a client in two groups inside a metric
-- that is supposed to count people.
--
-- Both elements are read, and a client's populations are the union of what either recorded:
-- reading one alone would drop a client seen only on the other pathway from every disaggregated
-- count, which is worse than counting a population twice (a set, so it cannot).
--
-- The membership is a standing attribute of the client rather than of a visit, so the latest
-- answer for each element wins: a client re-interviewed and recorded differently is counted as
-- they are now.
--
-- Ephemeral, so this is inlined into its consumer and materialises nothing.
--
-- Spec: specs/dbt-model/metric__who_dak_hiv_indicators.md, BL-022.

with answers as (
    select * from {{ ref('int__who_dak_hiv_form_answers') }}
),

recorded as (
    select
        patient_id,
        submitted_datetime,
        'hts' as source_element,
        key_population_hts_json as value
    from answers
    where key_population_hts_json is not null
    union all
    select
        patient_id,
        submitted_datetime,
        'pmtct',
        key_population_pmtct_json
    from answers
    where key_population_pmtct_json is not null
),

-- the most recent answer per element, so a re-interview on one pathway does not discard what the
-- other recorded
latest as (
    select distinct on (patient_id, source_element)
        patient_id,
        source_element,
        value
    from recorded
    order by patient_id asc, source_element asc, submitted_datetime desc
)

-- distinct, because the two elements share most of their option list and a client recorded as a
-- sex worker on both pathways is one client in one population
select distinct
    l.patient_id,
    trim(both '"' from trim(population)) as key_population
from latest l
-- a MultiSelect body is a JSON array of the selected labels. Split on the comma between
-- elements, which holds because no DAK key population label contains one -- checked against
-- Annex A's option list. A label that gained a comma would split in two here, so this is worth
-- re-checking when the annexe is revised.
cross join
    lateral unnest(
        string_to_array(trim(both '[]' from l.value), ',')
    ) population
where nullif(trim(both '"' from trim(population)), '') is not null
