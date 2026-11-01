{% docs generic__metadata %}
Metadata information extracted from the change logs
{% enddocs %}

{% docs logs__changes__logged_at_utc %}
The timestamp this change was logged, in UTC. For ordering a record's history only: the local
`logged_at` repeats an hour at a daylight-saving fall-back, so two changes inside that hour can
sort in the wrong order by it. Use `logged_at` for display and date filtering.
{% enddocs %}

{% docs logs__changes__record_updated_at_utc %}
The `updated_at` of the record when this change was logged, in UTC. For ordering a record's
history only, as a tiebreak after `logged_at_utc`. Use `record_updated_at` for display.
{% enddocs %}
