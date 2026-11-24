{{ incremental_from_table(
    key='id',
    table='survey_responses',
    indexes=[['encounter_id']]
) }}
{{ survey_responses_base(network=none) }}
