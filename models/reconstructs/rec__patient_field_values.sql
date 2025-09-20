{{
    config(
        unique_key='record_id',
        on_schema_change='sync_all_columns'
    )
}}

{{ jsonb_to_columns_dynamic('patient_field_values')}}
