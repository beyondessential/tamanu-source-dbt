{{ incremental_from_logs(
    key='id',
    table='patient_program_registration_conditions'
) }}
{{ patient_program_registration_conditions_change_logs_base(network=none) }}
