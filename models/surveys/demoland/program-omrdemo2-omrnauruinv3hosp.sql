{{
    config(
        materialized='view',
        tags=['survey', 'demoland']
    )
}}

select * from ({{ get_survey('program-omrdemo2-omrnauruinv3hosp') }})
