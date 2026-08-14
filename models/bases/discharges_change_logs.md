{% docs discharges_change_logs__change_sequence %}
Sequential number of this change for the discharge record. 1 is the entry that created the record, which is the moment the discharge was recorded in Tamanu.
{% enddocs %}

{% docs discharges_change_logs__changed_datetime %}
When the change was recorded on the central server, in the deployment's local time.
{% enddocs %}

{% docs discharges_change_logs__changed_by_user_id %}
The user session that made the change. Defaults to the nil UUID when no audit user was set on the session, in which case no user can be attributed.
{% enddocs %}
