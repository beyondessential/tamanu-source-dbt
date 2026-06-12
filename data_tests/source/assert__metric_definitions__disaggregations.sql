select
    md.metric_id,
    trim(d) as offending_disaggregation
from {{ ref('metric_definitions') }} md
cross join lateral unnest(string_to_array(md.disaggregations, ',')) as t(d)
where trim(d) not in ('age_group', 'sex', 'facility_id', 'dhis_ncd_category')
