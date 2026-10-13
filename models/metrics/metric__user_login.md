{% docs metric__user_login %}
D5 metric view for the user utilisation indicators registered in documentations/metrics/user.yml:
active_user and user_login.

active_user has one row per user (any status or role) per designation and
allowed facility, dated to the day the model is read. user_login has one row per successful
login (user_login_attempts outcome 'succeeded') over the same user x designation x facility
rows, dated to the login day. A user with several designations or facilities appears several
times, so a consumer counts distinct subject_id.

Consumers filter the population using role_id and visibility_status, and choose
which designations to show. The percentage of users who logged in is count(distinct subject_id) for user_login over
count(distinct subject_id) for active_user, per designation and facility grouping.

See specs/dbt-model/metric__user_login.md for BL-001..BL-005.
{% enddocs %}
