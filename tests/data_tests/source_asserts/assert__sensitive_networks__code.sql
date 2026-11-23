{{ config(severity='error') }}

-- AC-003, BL-010 (see specs/dbt-model/sensitive-facility-partition.md): one row per sensitive
-- network the deployment does not list in the `sensitive_networks` var. Data at a facility in an
-- unlisted network is in no model, so it reaches no report or data table until the network is
-- listed and its models are generated.
{%- set listed = listed_sensitive_networks() %}
select
    sn.id as sensitive_network_id,
    sn.code
from {{ ref('sensitive_networks') }} sn
{%- if listed %}
    where sn.code not in ('{{ listed | join("', '") }}')
{%- endif %}
