{% docs ds__user_access_audit__user_designations %}
Comma-separated list of all designations assigned to the user. Multiple designations are listed alphabetically. Returns NULL if the user has no designations assigned.
{% enddocs %}

{% docs ds__user_access_audit__role_permissions %}
Comma-separated list of all permissions associated with the user's role, displayed in verb:noun format (e.g., "read:Patient, write:Encounter"). Permissions are listed alphabetically. Returns NULL if the role has no permissions assigned.
{% enddocs %}

{% docs ds__user_access_audit__user_display_id %}
The user's display ID (unique identifier shown in the Tamanu interface). This is distinct from the internal UUID user_id.
{% enddocs %}
