-- int__who_dak_hiv_key_populations -- one row per DAK HIV client per key population they are
-- recorded as belonging to (BL-022).
--
-- Annex C asks for a key population disaggregation on most of its indicators, and the DAK
-- collects it as a MultiSelect (HIV.B.DE50): a client can be a sex worker and a person who
-- injects drugs at once. That is why this is a bridge rather than a column on the counts -- a
-- column would force one value per client, and the honest alternative, one row per pair, would
-- double a client in two groups inside a metric that is supposed to count people.
--
-- The membership is a standing attribute of the client rather than of a visit, so the latest
-- answer wins: a client re-interviewed and recorded differently is counted as they are now.
--
-- Ephemeral, so this is inlined into its consumer and materialises nothing.
--
-- Spec: specs/dbt-model/metric__who_dak_hiv_indicators.md, BL-022.

with answers as (
    select * from {{ ref('int__who_dak_hiv_form_answers') }}
),

-- the most recent submission that recorded anything about key population
latest as (
    select distinct on (patient_id)
        patient_id,
        key_population_json
    from answers
    where key_population_json is not null
    order by patient_id asc, submitted_datetime desc
)

select
    l.patient_id,
    trim(both '"' from trim(value)) as key_population
from latest l
-- a MultiSelect body is a JSON array of the selected labels. Parsed defensively: an answer that
-- is not valid JSON -- a single value written plainly by an older client -- still yields its one
-- label rather than dropping the client from every disaggregated count
cross join
    lateral unnest(
        string_to_array(trim(both '[]' from l.key_population_json), ',')
    ) value
where nullif(trim(both '"' from trim(value)), '') is not null
