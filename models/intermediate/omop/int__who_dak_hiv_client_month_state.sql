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
-- Where a client has been supplied ART, whether they are on ART at a month end is read from the
-- periods on ART their supply makes (derived__episode_art), not from what a form last said: a
-- client who stops collecting ART is lost to follow-up once their supply has run out for longer
-- than the allowance, and is on ART again from their next supply (BL-048). A client with no
-- supply recorded keeps the state their forms give them until their site's supply records can be
-- expected to show them (BL-049), and a client recorded as transferred out or dead is not on ART
-- (BL-056).
--
-- Only complete months are emitted, so a partial current month cannot read as a fall in the
-- caseload (BL-020).
--
-- Ephemeral, so this is inlined into its consumer and materialises nothing.
--
-- Spec: specs/dbt-model/metric__who_dak_hiv_indicators.md, BL-018..BL-021, BL-047..BL-057, BL-061
-- and BL-062.
-- The numbers BL-047 onward are that spec's.

with answers as (
    select * from {{ ref('int__who_dak_hiv_form_answers') }}
),

-- BL-048: the periods on ART that clients' supply makes
episodes as (
    select * from {{ ref('derived__episode_art') }}
),

supply as (
    select * from {{ ref('int__art_supply') }}
),

-- the date of each client's first period on ART, so a month end is tested against one row per client
first_supply as (
    select
        subject_id,
        min(episode_start_date) as first_supply_date
    from episodes
    group by subject_id
),

-- BL-049: the date a client with no supply recorded lapses to lost to follow-up
lapses as (
    select * from {{ ref('int__who_dak_hiv_art_lapse') }}
),

-- BL-055: each recorded treatment outcome, from a form or from the client's registry status
-- (BL-061), dated on the day it was recorded
outcomes as (
    select
        patient_id,
        response_id,
        submitted_datetime,
        submitted_datetime::date as outcome_date,
        hiv_treatment_outcome
    from answers
    where hiv_treatment_outcome is not null
        and submitted_datetime is not null

    union all

    select
        patient_id,
        response_id,
        submitted_datetime,
        submitted_datetime::date as outcome_date,
        hiv_treatment_outcome
    from {{ ref('int__who_dak_hiv_registry_outcomes') }}
),

-- BL-052: the days a client becomes lost to follow-up: the day after a closed period's last day
-- on ART, or the day after the lapse date of a client with no supply recorded by then
ltfu_candidates as (
    select
        e.subject_id as patient_id,
        e.last_day_on_art + 1 as ltfu_date,
        e.episode_start_date as since_date
    from episodes e
    where e.closure_reason is not null

    union all

    select
        l.patient_id,
        l.lapse_date + 1 as ltfu_date,
        l.art_start_date as since_date
    from lapses l
    where not exists (
            select 1
            from episodes e
            where e.subject_id = l.patient_id
                and e.episode_start_date <= l.lapse_date
        )
),

-- BL-057: not a client whose ART was stopped, or who was recorded as transferred out, since the
-- period began and before they became lost to follow-up. Loss to follow-up is worked out from
-- supply, so a recorded Lost to follow-up outcome is not read
ltfu_events as (
    select c.*
    from ltfu_candidates c
    where not exists (
            select 1
            from answers a
            where a.patient_id = c.patient_id
                and a.art_stopped_date > c.since_date
                and a.art_stopped_date <= c.ltfu_date
        )
        and coalesce((
            select o.hiv_treatment_outcome
            from outcomes o
            where o.patient_id = c.patient_id
                and o.outcome_date >= c.since_date
                and o.outcome_date <= c.ltfu_date
            order by o.outcome_date desc, o.submitted_datetime desc, o.response_id desc
            limit 1
        ), '') <> 'Transferred out'
        -- BL-062: nor a client recorded as dead since the period began, however late the death was
        -- recorded, unless they started another period on ART before the death
        and not exists (
            select 1
            from outcomes o
            where o.patient_id = c.patient_id
                and o.hiv_treatment_outcome = 'Death (documented)'
                and o.outcome_date >= c.since_date
                and not exists (
                    select 1
                    from episodes e
                    where e.subject_id = c.patient_id
                        and e.episode_start_date >= c.ltfu_date
                        and e.episode_start_date <= o.outcome_date
                )
        )
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

-- a client's latest ART supply in each month, which is all the state needs of it. A supply with no
-- facility is left out: it would blank the facility of a client whose forms name one (BL-021)
monthly_supply as (
    select distinct on (subject_id, date_trunc('month', supply_date))
        subject_id,
        supply_date,
        supply_days,
        facility_id
    from supply
    where facility_id is not null
    order by subject_id asc, date_trunc('month', supply_date) asc, supply_date desc
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
        'art_start_date' as attribute,
        art_start_date::text
    from answers
    where art_start_date is not null
    union all
    select
        patient_id,
        submitted_datetime,
        facility_id,
        'dsd_enrolled' as attribute,
        dsd_enrolled::text
    from answers
    where dsd_enrolled is not null
    union all
    select
        patient_id,
        submitted_datetime,
        facility_id,
        'dsd_start_date' as attribute,
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
        'art_stopped_date' as attribute,
        art_stopped_date::text
    from answers
    where art_stopped_date is not null
    union all
    -- BL-055: a form's treatment outcome, so the submission that recorded it counts as contact
    -- (BL-021). The outcome itself is read from outcomes, which also holds the registry's (BL-061)
    select
        patient_id,
        submitted_datetime,
        facility_id,
        'hiv_treatment_outcome' as attribute,
        hiv_treatment_outcome
    from answers
    where hiv_treatment_outcome is not null
    union all
    -- BL-048, BL-021: a client's latest ART supply in each month, so a client supplied ART has a
    -- row in every month from their first supply, at the facility that supplied them
    select
        subject_id as patient_id,
        supply_date::timestamp as submitted_datetime,
        facility_id,
        'art_supply' as attribute,
        supply_days::text
    from monthly_supply
),

-- the latest value each attribute held at each month end
state_as_at as (
    select distinct on (m.month_start, e.patient_id, e.attribute)
        m.month_start,
        (m.month_start + interval '1 month' - interval '1 day')::date as month_end,
        e.patient_id,
        e.attribute,
        e.value,
        e.facility_id,
        e.submitted_datetime
    from state_events e
    cross join bounds b
    -- each event's own months, from the month it was recorded in to the last month of the spine,
    -- so the join never tests an event against months before it
    cross join
        lateral (
            select gs::date as month_start
            from generate_series(
                    greatest(b.first_month, date_trunc('month', e.submitted_datetime)::date),
                    b.last_month,
                    interval '1 month'
                ) gs
        ) m
    where b.first_month <= b.last_month
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
),

-- BL-048..BL-050, BL-056: what each client's supply, lapse date and latest recorded outcome say
-- at the month end, beside what their forms last said
with_supply as (
    select
        p.*,
        -- BL-026: on ART by the forms as at the month end. A stop dated on or before the month
        -- end ends the state, unless treatment restarted after it -- a client with a later ART
        -- start date is on their second course, and the old stop says nothing about it.
        --
        -- Read from the dated stop rather than from the stop form's own submission, so a stop
        -- recorded late still takes effect in the month treatment actually ended, the same rule
        -- ART.4 uses for an initiation.
        coalesce(p.on_art, false)
        and not (
            p.art_stopped_date is not null
            and p.art_stopped_date <= p.month_end
            and (p.art_start_date is null or p.art_stopped_date > p.art_start_date)
        ) as on_art_by_form,
        -- BL-048: the period on ART the month end falls in. At most one: a period's last day on
        -- ART is before the next period's first supply
        cov.episode_start_date as period_start_date,
        coalesce(fs.first_supply_date <= p.month_end, false) as has_supply,
        l.lapse_date,
        -- BL-056: recorded as transferred out or dead, and not supplied ART since
        case
            when lo.hiv_treatment_outcome in ('Transferred out', 'Death (documented)')
                then not exists (
                        select 1
                        from episodes e
                        where e.subject_id = p.patient_id
                            and e.episode_start_date > lo.outcome_date
                            and e.episode_start_date <= p.month_end
                    )
            else false
        end as is_out_of_care
    from pivoted p
    left join episodes cov
        on cov.subject_id = p.patient_id
        and cov.episode_start_date <= p.month_end
        and cov.last_day_on_art >= p.month_end
    left join first_supply fs on fs.subject_id = p.patient_id
    left join lapses l on l.patient_id = p.patient_id
    -- BL-055: the client's latest recorded outcome on or before the month end
    left join lateral (
        select
            o.hiv_treatment_outcome,
            o.outcome_date
        from outcomes o
        where o.patient_id = p.patient_id
            and o.outcome_date <= p.month_end
        order by o.outcome_date desc, o.submitted_datetime desc, o.response_id desc
        limit 1
    ) lo on true
)

select
    p.month_start,
    p.month_end,
    p.patient_id,
    c.facility_id,

    -- BL-048: a client supplied ART by the month end is on ART when a period on ART covers it,
    -- unless a recorded stop dated after the period began, and after any ART start the forms
    -- record, ends it (BL-026). BL-049: a client with
    -- no supply recorded keeps the state their forms give them until their lapse date.
    -- BL-056: a client recorded as transferred out or dead is not on ART
    (
        case
            when p.has_supply
                then
                    p.period_start_date is not null
                    and not (
                        p.art_stopped_date is not null
                        and p.art_stopped_date > p.period_start_date
                        and p.art_stopped_date <= p.month_end
                        and (p.art_start_date is null or p.art_stopped_date > p.art_start_date)
                    )
            else p.on_art_by_form and (p.lapse_date is null or p.month_end <= p.lapse_date)
        end
        and not p.is_out_of_care
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
    {{ age_years('p.month_end', 'per') }} as age_years,

    -- BL-052: the client became lost to follow-up in the month
    exists(
        select 1
        from ltfu_events le
        where le.patient_id = p.patient_id
            and le.ltfu_date between p.month_start and p.month_end
    ) as ltfu_in_month,
    -- BL-053: a period on ART numbered 2 or more started in the month
    exists(
        select 1
        from episodes e
        where e.subject_id = p.patient_id
            and e.is_reinitiation
            and e.episode_start_date between p.month_start and p.month_end
    ) as reinitiated_in_month

from with_supply p
left join latest_contact c on c.month_start = p.month_start and c.patient_id = p.patient_id
join {{ ref('clinical__person') }} per on per.person_id = p.patient_id
