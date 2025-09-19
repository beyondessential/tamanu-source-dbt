{{
    config(
        unique_key='id',
        on_schema_change='sync_all_columns'
    )
}}

{{ jsonb_to_columns_dynamic('patient_program_registrations')}}
where (record_data->>'patient_id') != '{{ var("test_patient") }}'
    and record_data->>'id' like '%;%'