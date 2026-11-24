{{ incremental_from_logs(
    key='id',
    table='patient_program_registrations'
) }}
{{ patient_program_registrations_change_logs_base(network=none) }}
