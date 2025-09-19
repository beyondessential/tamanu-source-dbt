{% macro jsonb_to_columns_dynamic(table_name) %}
    {% if execute %}
        {% set keys_query %}
            WITH latest_version AS (
                SELECT record_data,
                    row_number() over (order by string_to_array(version, '.')::int[] desc) as rn
                FROM {{ source("logs__tamanu", "changes") }}
                WHERE table_name = '{{ table_name }}'
                    and version != 'unknown'
            )
            SELECT DISTINCT key
            FROM latest_version,
            LATERAL jsonb_each_text(record_data)
            WHERE rn = 1
        {% endset %}

        {% set keys_result = run_query(keys_query) %}
        {% set keys = keys_result.columns[0].values() %}
    {% else %}
        {% set keys = [] %}
    {% endif %}

    with
    {% if is_incremental() %}
    max_updated_at as (
        select max(record_updated_at) as max_updated_at
        from {{ this }}
    ),
    {% endif %}

    changes_data as (
        select
            record_updated_at,
            record_data,
            row_number() over (
                partition by record_id 
                order by record_updated_at desc
            ) as rn
        from {{ source('logs__tamanu', 'changes') }}
        {% if is_incremental() %}
        cross join max_updated_at
        {% endif %}
        where table_name = '{{ table_name }}'
            {% if is_incremental() %}
                and record_updated_at > max_updated_at.max_updated_at
            {% endif %}
    ),

    latest_changes as (
        select
            record_updated_at,
            record_data
        from changes_data
        where rn = 1
    )

    select
        record_updated_at,
        {% if keys|length > 0 %}
        {% for key in keys %}
        record_data->>'{{ key }}' as {{ key }}{% if not loop.last %},{% endif %}
        {% endfor %}
        {% else %}
        null as placeholder
        {% endif %}
    from latest_changes
{% endmacro %}
