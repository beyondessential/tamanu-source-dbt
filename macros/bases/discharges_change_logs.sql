{% macro discharges_change_log_events(record_id_filter=none) %}
-- BL-013/BL-014: shared change-log extraction (see specs/reports/audit-discharge-line-list.md).
-- Two callers: the base model (unfiltered) and the audit report's candidate-scoped read.
-- record_id_filter narrows WHICH discharges are included, never how much of an included
-- discharge's history is seen -- change_sequence needs each discharge's full history to stay
-- correct.
select
    c.changelog_id,
    c.discharge_id,
    c.encounter_id,
    c.logged_at,
    c.logged_at_utc,
    c.updated_by_user_id,
    c.record_data ->> 'note' as note,
    c.record_data ->> 'discharger_id' as discharger_id,
    c.record_data ->> 'disposition_id' as disposition_id,
    -- History is ordered by the UTC sort keys: local logged_at and record_updated_at repeat an
    -- hour at a DST fall-back
    row_number() over (
        partition by c.discharge_id
        order by c.logged_at_utc, c.record_updated_at_utc, c.changelog_id
    ) as change_sequence
from {{ ref('discharges_change_events') }} c
{%- if record_id_filter %}
where {{ record_id_filter }}
{%- endif %}
{% endmacro %}
