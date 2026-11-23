{{ incremental_from_table(
    key='patient_id',
    table='patient_birth_data'
) }}
{{ patient_birth_data_base(network=none) }}
