-- Removes everything prescriptions.sql created.
--
-- The synthetic data is meant to stay, so this is not part of the normal
-- workflow -- it is here for when a database needs resetting.
--
-- Matches on the `synthetic-` id prefix only. The patients are real records
-- that were already on the database and are never touched; only the
-- synthesised encounters and prescriptions are removed.
--
-- Usage:
--     psql "$CONNECTION_STRING" -f prescriptions-remove.sql

begin;

delete from encounter_prescriptions
where prescription_id like 'synthetic-presc-%' or encounter_id like 'synthetic-enc-%';

delete from prescriptions where id like 'synthetic-presc-%';
delete from encounters where id like 'synthetic-enc-%';

commit;

-- Should report 0 across the board. Patient rows are deliberately absent from
-- this list: none were created, so none are removed.
select
    'encounters' as entity, count(*) as remaining
from encounters where id like 'synthetic-enc-%'
union all
select 'prescriptions', count(*) from prescriptions where id like 'synthetic-presc-%'
union all
select 'encounter_prescriptions', count(*) from encounter_prescriptions
where prescription_id like 'synthetic-presc-%';
