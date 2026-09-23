{#
    The clinical__visit_detail segment a point-in-time event falls in: the latest segment
    that had already started by the event's own timestamp.

    clinical__procedure_occurrence resolves this once for procedures and imaging requests and
    emits it as visit_detail_id (its BL-005), so those metrics read it off an FK. An order that
    is not in the clinical layer -- a lab request, and the referrals and appointments that will
    follow -- has no such FK, so it resolves the segment itself. This macro is that derivation,
    factored out rather than hand-copied, which is the duplication MAUI-6844 removed from four
    metric models in the first place.

    The rule matches clinical__procedure_occurrence BL-005 exactly, including the clamp to the
    earliest segment for an event that predates every segment -- an event genuinely belongs to
    its own encounter, so a segment recorded as starting after it (a data-timing artifact, not a
    real ordering issue) should not leave it unattributed. The join carries no timestamp
    condition: the order by picks the as-of segment where one qualifies and falls back to the
    earliest otherwise. Every encounter has at least one segment (clinical__visit_detail BL-005),
    so the join itself cannot drop a row.

    The tie-breaks are split by direction on purpose: among segments sharing a start datetime,
    the as-of branch wants the last of them and the clamp branch the first, matching the
    (start_datetime, visit_detail_id) order clinical__visit_detail chains its own segments by.
    One shared direction would be right for only one of the two.

    Returns one row per event: the event key and its visit_detail_id. Join
    clinical__visit_detail on that to read the segment's concept, department or care site.

    Usage:
        active_segment as (
            {{ visit_detail__as_of('ordered_tests', 'lab_test_id', 'requested_datetime', 'encounter_id') }}
        ),
#}
{% macro visit_detail__as_of(events, event_key, event_datetime, visit_occurrence_key='visit_occurrence_id') %}
select distinct on (o.{{ event_key }})
    o.{{ event_key }},
    vd.visit_detail_id
from {{ events }} o
join {{ ref('clinical__visit_detail') }} vd
    on vd.visit_occurrence_id = o.{{ visit_occurrence_key }}
order by
    o.{{ event_key }},
    (vd.visit_detail_start_datetime <= o.{{ event_datetime }}) desc,
    case when vd.visit_detail_start_datetime <= o.{{ event_datetime }}
            then vd.visit_detail_start_datetime
    end desc,
    case when vd.visit_detail_start_datetime > o.{{ event_datetime }}
            then vd.visit_detail_start_datetime
    end asc,
    case when vd.visit_detail_start_datetime <= o.{{ event_datetime }}
            then vd.visit_detail_id
    end desc,
    case when vd.visit_detail_start_datetime > o.{{ event_datetime }}
            then vd.visit_detail_id
    end asc
{% endmacro %}
