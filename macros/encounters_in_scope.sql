{% macro encounters_in_scope(is_sensitive=false, encounter_type=none, extra_predicates=none) %}
{#-
    Encounters resolved to their facility, partitioned by sensitivity.

    The encounters -> locations -> facilities join with `f.is_sensitive` is the most
    repeated block in the repo. Keeping it here is what stops the copies drifting.

    See specs/dbt-model/encounters_in_scope.md for the BL clauses this macro implements.

    Arguments
      is_sensitive      facility partition. false = non-sensitive facilities only.
      encounter_type    optional, restricts to one encounter_type (e.g. 'admission').
      extra_predicates  optional SQL text appended to the where clause.

    Alias contract (BL-003). `extra_predicates` is raw SQL spliced into this macro's
    own where clause, so it may reference exactly these aliases:
        e   encounters
        l   locations
        f   facilities
    Nothing else is in scope, and these aliases must not be renamed here without
    updating every caller.

    `extra_predicates` is row-selecting only (BL-004) -- it narrows which encounters
    are returned and nothing else. This macro has no window functions or aggregates,
    so a caller's predicate cannot change the value of any column, only which rows
    survive. Callers own their own filters; see encounter_scope_common_filters() for
    the optional-id filters the reports share.

    Deliberately contains no parameter() call (BL-005). Datasets build on analytics
    targets, where parameter() falls through to a var() literal rather than a bind
    placeholder, so a filter baked in here would be a footgun for dataset callers.
-#}

{%- set predicates = [] -%}
{%- if encounter_type -%}
    {%- do predicates.append("e.encounter_type = '" ~ encounter_type ~ "'") -%}
{%- endif -%}
{%- if extra_predicates -%}
    {#- Both parens sit on their own line. A caller's predicate text may legally end on
        a `--` comment, and a same-line `)` would then be commented out and the model
        would fail to compile. -#}
    {%- set wrapped_predicates %}
(
{{ extra_predicates }}
)
{%- endset -%}
    {%- do predicates.append(wrapped_predicates) -%}
{%- endif -%}

select
    e.id as encounter_id,
    e.patient_id,
    e.encounter_type,
    e.reason_for_encounter,
    e.start_datetime,
    e.end_datetime,
    -- localised alongside the raw values so a caller can present either without
    -- repeating the shift; the shift is a per-row expression, so emitting both costs
    -- nothing and ordering by either is equivalent (it is monotonic per row)
    {{ to_user_selected_timezone('e.start_datetime') }} as start_datetime_local,
    {{ to_user_selected_timezone('e.end_datetime') }} as end_datetime_local,
    e.location_id,
    e.department_id,
    e.clinician_id,
    e.patient_billing_type_id,
    f.id as facility_id,
    f.name as facility
-- BL-002: the test patient is already excluded by the encounters base model, so it
-- is not re-applied here
from {{ ref('encounters') }} e
-- BL-006: location and facility are inner joins, so an encounter whose location_id
-- is null or dangling produces no row at all
join {{ ref('locations') }} l
    on l.id = e.location_id
join {{ ref('facilities') }} f
    on f.id = l.facility_id
    -- BL-001: facility scope partitioned by the is_sensitive argument
    and f.is_sensitive = {{ is_sensitive }}
{%- if predicates %}
where {{ predicates | join('\n    and ') }}
{%- endif %}

{% endmacro %}
