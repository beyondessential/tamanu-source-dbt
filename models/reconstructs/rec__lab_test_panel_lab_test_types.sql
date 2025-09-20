{{
    config(
        unique_key='logs_changes_record_id',
        on_schema_change='sync_all_columns'
    )
}}

{{ jsonb_to_columns_dynamic('lab_test_panel_lab_test_types')}}
