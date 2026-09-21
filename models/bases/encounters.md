{% docs encounters__start_date_iso %}
The beginning of the encounter, exactly as Tamanu stores it: ISO-9075 text of the form
`YYYY-MM-DD HH24:MI:SS`, in the deployment's local time. `start_datetime` carries the same
instant as a timestamp and is what most callers want; this column exists for a date-range
filter that needs to compare against the stored value rather than a converted one.
{% enddocs %}

{% docs encounters__end_date_iso %}
The date the encounter was discharged or ended, exactly as Tamanu stores it: ISO-9075 text
of the form `YYYY-MM-DD HH24:MI:SS`, in the deployment's local time. Null while the
encounter is open.

Not interchangeable with `end_datetime`: where an encounter records an end before its own
start, `end_datetime` reports the start instead, and this column still reports the end as
entered.
{% enddocs %}
