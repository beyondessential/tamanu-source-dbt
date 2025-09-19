{{
    config(
        unique_key='id',
        on_schema_change='sync_all_columns'
    )
}}

{{ jsonb_to_columns_dynamic('referrals')}}
