-- int__lab_test_panel_attribution -- each lab test resolved to the panel request it belongs to.
--
-- From Tamanu 2.66 a lab request holds any number of panel requests
-- (lab_test_panel_requests.lab_request_id), and each test names its own
-- (lab_tests.lab_test_panel_request_id), null for a test ordered individually.
--
-- Requests from before 2.66 were not stamped: the migration relinked each one's single panel
-- request to it, but left its tests without attribution. Tamanu reads such a request -- exactly
-- one panel request and no attributed test -- as "every test belongs to that panel"
-- (getLabRequestTestAndPanelNames, packages/utils/src/labTests.ts). This model applies the same
-- inference, so every consumer agrees with the app about which tests a panel holds.
--
-- Grain: one row per live lab test. A test type shared by two panels on one request is two
-- tests, one per panel. No facility or sensitivity scope -- callers apply their own.
--
-- A test stamped with a panel request that has since been deleted keeps that attribution, with
-- a null lab_test_panel_id: it belongs to a panel no consumer can show.

with panel_requests_by_request as (
    select
        lab_request_id,
        count(*) as panel_request_count,
        -- only read when panel_request_count = 1, so which element is moot
        (array_agg(id))[1] as single_panel_request_id
    from {{ ref('lab_test_panel_requests') }}
    where lab_request_id is not null
    group by lab_request_id
),

requests as (
    select
        lt.lab_request_id,
        bool_or(lt.lab_test_panel_request_id is not null) as has_attributed_test
    from {{ ref('lab_tests') }} lt
    group by lt.lab_request_id
),

resolved as (
    select
        lt.id as lab_test_id,
        lt.lab_request_id,
        case
            when lt.lab_test_panel_request_id is not null then 'recorded'
            when prr.panel_request_count = 1 and not r.has_attributed_test
                then 'single_panel_request'
        end as panel_attribution,
        coalesce(
            lt.lab_test_panel_request_id,
            case
                when prr.panel_request_count = 1 and not r.has_attributed_test
                    then prr.single_panel_request_id
            end
        ) as lab_test_panel_request_id
    from {{ ref('lab_tests') }} lt
    join requests r
        on r.lab_request_id = lt.lab_request_id
    left join panel_requests_by_request prr
        on prr.lab_request_id = lt.lab_request_id
)

select
    res.lab_test_id,
    res.lab_request_id,
    res.lab_test_panel_request_id,
    ltpr.lab_test_panel_id,
    -- 'recorded': the test names its panel request. 'single_panel_request': inferred from a
    -- pre-2.66 request's one panel request. Null: an individual test, not part of any panel.
    res.panel_attribution
from resolved res
left join {{ ref('lab_test_panel_requests') }} ltpr
    on ltpr.id = res.lab_test_panel_request_id
