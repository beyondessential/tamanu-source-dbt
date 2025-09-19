{{
    config(
        unique_key='id',
        on_schema_change='sync_all_columns'
    )
}}

{{ jsonb_to_columns_dynamic('patient_program_registration_conditions')}}
where record_data->>'patient_program_registration_id' like '%;%'