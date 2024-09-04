{% docs table__upcoming_vaccinations %}
Upcoming vaccinations lists patients and next vaccine due for a given vaccine type.

The first dose of a vaccine type is based on weeks from birth due whilst subsequent doses are based on weeks from last vaccination due.

Age limits in years and thresholds in days for scheduled status are configurable with the following defaults:

Age = 15
Status: Scheduled = 28
Status: Upcoming = 7
Status: Due = -7
Status: Overdue = -55
Status: Missed = -Infinity
{% enddocs %}

{% docs upcoming_vaccinations__id %}
Tamanu identifier for upcoming_vaccinations
{% enddocs %}

{% docs upcoming_vaccinations__email %}
Email address for user. This is used to login and receive emails.
{% enddocs %}

{% docs upcoming_vaccinations__password %}
Encrypted password for user login
{% enddocs %}

{% docs upcoming_vaccinations__display_name %}
The human readable display name for the user
{% enddocs %}

{% docs upcoming_vaccinations__display_id %}
Display identifier for the user
{% enddocs %}

{% docs upcoming_vaccinations__phone_number %}
Phone number for user.
{% enddocs %}
