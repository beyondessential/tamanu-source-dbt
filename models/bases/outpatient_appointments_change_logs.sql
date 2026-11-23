{{ incremental_from_logs(
    key='appointment_id',
    table='appointments'
) }}
{{ outpatient_appointments_change_logs_base(network=none) }}
