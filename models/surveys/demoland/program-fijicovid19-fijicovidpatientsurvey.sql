{{
    config(
        materialized='view',
        tags=['survey', 'demoland']
    )
}}

select * from ({{ get_survey('program-fijicovid19-fijicovidpatientsurvey') }})
