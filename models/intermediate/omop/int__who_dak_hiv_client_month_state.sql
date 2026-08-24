-- int__who_dak_hiv_client_month_state -- one row per DAK HIV client per complete reporting
-- month, carrying the client's last known treatment state as at the end of that month
-- (BL-018).
--
-- Several Annex C indicators are point-in-time: ART.1 counts clients on ART *at the reporting
-- period end date*, DSD.4 counts clients enrolled in a DSD model who started more than X months
-- before it. A form submission is an event, and an event-anchored count cannot answer either --
-- a client who started ART in March and was never seen again is still on ART in April as far as
-- the record says, so the state has to be carried forward from the last form that recorded it.
--
-- Carried forward per element, not per submission: a later visit that records a viral load but
-- says nothing about DSD enrolment must not blank the DSD state. Each attribute therefore takes
-- the most recent submission that actually carried a value for it (BL-019).
--
-- Carried forward is not carried forever. A recorded ART stop ends the on-ART state from the stop
-- date, whether or not the form that recorded it also answered "On ART" (BL-026) -- without that,
-- a client whose treatment stopped would stay in ART.1 indefinitely, and the cascade's headline
-- number would only ever grow.
--
-- Only complete months are emitted, so a partial current month cannot read as a fall in the
-- caseload (BL-020).
--
-- Ephemeral, so this is inlined into its consumer and materialises nothing.
--
-- Spec: specs/dbt-model/metric__who_dak_hiv_indicators.md, BL-018..BL-021.

with answers as (
    select * from {{ ref('int__who_dak_hiv_form_answers') }}
),

-- BL-020: the reporting spine, first submission month to the last complete month.
--
-- The horizon is a var so a backfill can be reproduced and a unit test can assert a fixed set of
-- months: left unset it is the last complete month, which moves with the calendar.
{% set spine_end = var('who_dak_hiv_spine_end', none) %}
bounds as (
    select
        date_trunc('month', min(submitted_datetime))::date as first_month,
        {% if spine_end -%}
        date_trunc('month', date '{{ spine_end }}')::date as last_month
        {%- else -%}
        (date_trunc('month', current_date) - interval '1 month')::date as last_month
        {%- endif %}
    from answers
),

months as (
    select
        month_start::date as month_start,
        (month_start + interval '1 month' - interval '1 day')::date as month_end
    from bounds b
    cross join lateral generate_series(b.first_month, b.last_month, interval '1 month') month_start
    where b.first_month <= b.last_month
),

-- BL-019: one row per recorded value per attribute, so each attribute can be carried forward on
-- its own timeline. Long rather than wide for that reason: a wide last-submission-wins join
-- would let a later form's silence overwrite a state it never mentioned.
state_events as (
    select
        patient_id,
        submitted_datetime,
        facility_id,
        'on_art' as attribute,
        on_art::text as value
    from answers
    where on_art is not null
    union all
    select
        patient_id,
        submitted_datetime,
        facility_id,
        'art_start_date',
        art_start_date::text
    from answers
    where art_start_date is not null
    union all
    select
        patient_id,
        submitted_datetime,
        facility_id,
        'dsd_enrolled',
        dsd_enrolled::text
    from answers
    where dsd_enrolled is not null
    union all
    select
        patient_id,
        submitted_datetime,
        facility_id,
        'dsd_start_date',
        dsd_start_date::text
    from answers
    where dsd_start_date is not null
    union all
    -- BL-026: the date treatment stopped, which ends the on-ART state rather than being one more
    -- fact beside it
    select
        patient_id,
        submitted_datetime,
        facility_id,
        'art_stopped_date',
        art_stopped_date::text
    from answers
    where art_stopped_date is not null
),

-- the latest value each attribute held at each month end
state_as_at as (
    select distinct on (m.month_start, e.patient_id, e.attribute)
        m.month_start,
        m.month_end,
        e.patient_id,
        e.attribute,
        e.value,
        e.facility_id,
        e.submitted_datetime
    from months m
    join state_events e on e.submitted_datetime < m.month_end + interval '1 day'
    order by m.month_start asc, e.patient_id asc, e.attribute asc, e.submitted_datetime desc
),

-- BL-021: the facility is the one that last said anything about the client, so a transfer moves
-- the client's counts to the receiving facility from the month the receiving facility recorded
-- them. Read from the latest submission of any attribute, not of one in particular.
latest_contact as (
    select distinct on (month_start, patient_id)
        month_start,
        patient_id,
        facility_id
    from state_as_at
    order by month_start asc, patient_id asc, submitted_datetime desc
),

pivoted as (
    select
        s.month_start,
        s.month_end,
        s.patient_id,
        max(case when s.attribute = 'on_art' then s.value end) = 'true' as on_art,
        max(case when s.attribute = 'art_start_date' then s.value end)::date as art_start_date,
        max(case when s.attribute = 'dsd_enrolled' then s.value end) = 'true' as dsd_enrolled,
        max(case when s.attribute = 'dsd_start_date' then s.value end)::date as dsd_start_date,
        max(case when s.attribute = 'art_stopped_date' then s.value end)::date as art_stopped_date
    from state_as_at s
    group by s.month_start, s.month_end, s.patient_id
)

select
    p.month_start,
    p.month_end,
    p.patient_id,
    c.facility_id,

    -- BL-026: on ART as at the month end. A stop dated on or before the month end ends the
    -- state, unless treatment restarted after it -- a client with a later ART start date is on
    -- their second course, and the old stop says nothing about it.
    --
    -- Read from the dated stop rather than from the stop form's own submission, so a stop
    -- recorded late still takes effect in the month treatment actually ended, the same rule ART.4
    -- uses for an initiation.
    coalesce(p.on_art, false)
    and not (
        p.art_stopped_date is not null
        and p.art_stopped_date <= p.month_end
        and (p.art_start_date is null or p.art_stopped_date > p.art_start_date)
    ) as on_art,

    p.on_art as on_art_recorded,
    p.art_stopped_date,
    p.art_start_date,
    p.dsd_enrolled,
    p.dsd_start_date,

    -- whole months on ART as at the month end, so the six-month rule ART.3 and ART.6 apply and
    -- the 12/24/36/48/60-month bands DSD.4 reports at are both a comparison rather than a
    -- date computation repeated per indicator
    case
        when p.art_start_date is not null then
            (extract(year from p.month_end) - extract(year from p.art_start_date)) * 12
            + (extract(month from p.month_end) - extract(month from p.art_start_date))
    end::int as months_on_art,
    case
        when p.dsd_start_date is not null then
            (extract(year from p.month_end) - extract(year from p.dsd_start_date)) * 12
            + (extract(month from p.month_end) - extract(month from p.dsd_start_date))
    end::int as months_on_dsd,

    per.gender_source_value as sex,
    {{ age_years('p.month_end', 'per') }} as age_years

from pivoted p
left join latest_contact c on c.month_start = p.month_start and c.patient_id = p.patient_id
join {{ ref('clinical__person') }} per on per.person_id = p.patient_id
