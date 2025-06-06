{{
    config(
        materialized='view',
        tags=['survey', 'demoland']
    )
}}

select * from ({{ get_survey('program-cancerregistrydemotwo-cancerregreferrald2') }})
