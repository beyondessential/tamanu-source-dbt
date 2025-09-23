{% macro get_table_list() %}
    {% set query %}
        select distinct table_name 
        from {{ source('logs__tamanu', 'changes') }} 
        where table_schema = 'public'
    {% endset %}

    {% if execute %}
        {% set results = run_query(query) %}
        {% set table_names = results.columns[0].values() %}
        {% for table_name in table_names %}
            {{ print(table_name) }}
        {% endfor %}
    {% endif %}
{% endmacro %}


{% macro jsonb_to_columns_dynamic(table_name) %}
    {% if execute %}
        {% set keys_query %}
            with versions AS (
                select distinct on (version)
                    version,
                    record_data
                from {{ source("logs__tamanu", "changes") }}
                where table_name = '{{ table_name }}'
                    and version != 'unknown'
            ),
            latest_version as (
                select
                    record_data
                from versions
                order by string_to_array(version, '.')::int[] desc
                limit 1
            )
            select distinct key
            from latest_version,
            lateral jsonb_each_text(record_data)
        {% endset %}

        {% set keys_result = run_query(keys_query) %}
        {% set keys = keys_result.columns[0].values() %}
    {% else %}
        {% set keys = [] %}
    {% endif %}

    with
    {% if is_incremental() %}
    max_updated_at as (
        select max(logged_at) as max_logged_at
        from {{ this }}
    ),
    {% endif %}
    latest_changes as (
        select distinct on (record_id)
            record_id,
            logged_at,
            record_data,
            version
        from {{ source('logs__tamanu', 'changes') }}
        {% if is_incremental() %}
        cross join max_logged_at
        {% endif %}
        where table_name = '{{ table_name }}'
            {% if is_incremental() %}
                and logged_at > max_logged_at.max_logged_at
            {% endif %}
        order by
            record_id,
            logged_at desc,
            CASE WHEN version = 'unknown' THEN 0 ELSE 1 END desc, -- Ensure 'unknown' versions are sorted last
            CASE WHEN version != 'unknown' THEN string_to_array(version, '.')::int[] END desc
    )

    select
        record_id as logs_changes_record_id,
        logged_at,
        {% if keys|length > 0 %}
            {% for key in keys %}
                record_data->>'{{ key }}' as {{ key }}{% if not loop.last %},{% endif %}
            {% endfor %}
        {% endif %}
    from latest_changes
{% endmacro %}
