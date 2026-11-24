-- May include notes for the test patient.
{{ incremental_from_table(
    key='id',
    table='notes'
) }}
{{ notes_base(network=none) }}
