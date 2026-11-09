{{ incremental_config(
    key='id',
    source='lab_test_types',
    source_type='table'
) }}
select
    id,
    code,
    external_code,
    name,
    unit,
    male_min,
    male_max,
    female_min,
    female_max,
    range_text as result_type,
    options,
    lab_test_category_id,
    visibility_status,
    is_sensitive,
    available_facilities,
    updated_at_sync_tick
from {{ source('tamanu', 'lab_test_types') }}
where deleted_at is null
    {%- if is_incremental() %}
    and updated_at_sync_tick >= {{ last_sync_tick() }}
    {%- endif %}
