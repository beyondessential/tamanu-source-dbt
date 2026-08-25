-- Synthetic prescription data: January to March 2026.
--
-- Attaches realistic prescribing activity to a sample of the patients already
-- on the database, so ds__encounter_prescriptions has a populated window to
-- report on. Patients are real; the encounters and prescriptions are
-- synthesised.
--
-- NEVER RUN THIS AGAINST A PRODUCTION DATABASE. It writes clinical-shaped rows
-- into public.* against real patient records. Demo and local databases only.
--
-- Usage:
--     psql "$CONNECTION_STRING" -f prescriptions.sql
--
-- The data is meant to stay. Re-running does not delete or duplicate anything:
-- ids are derived from the patient id, so a second run inserts nothing.
-- prescriptions-remove.sql is there for when you do want it gone.

begin;

-- ---------------------------------------------------------------------------
-- Configuration
-- ---------------------------------------------------------------------------
create temporary table syn_config on commit drop as
select
    -- How many existing patients to prescribe for.
    20 as patient_count,
    -- Changing the seed reshuffles which patients are picked. The same seed
    -- always picks the same ones, so a re-run is stable and two environments
    -- seeded alike are comparable.
    'prescriptions-2026q1' as sample_seed,
    date '2026-01-01' as window_start,
    date '2026-03-31' as window_end,
    -- Deployments exclude a designated test patient from their base models
    -- (dbt var `test_patient`). Sampling it would produce rows that silently
    -- never surface downstream. Set to the deployment's value, or leave as-is.
    'h1627394-3778-4c31-a510-9fcb88efdbf3' as excluded_patient_id;

-- Drug codes resolve against reference_data.code where type = 'drug', paired
-- with a plausible regimen for that medication. The defaults exist on the
-- Nauru demo dataset. Swap them for codes on your target database -- the
-- guard below names anything it cannot find rather than seeding nothing.
--
-- The mix is deliberate. A deployment that filters prescriptions by
-- essential-medicines-list membership needs drugs on both sides of that list,
-- and needs the one whose casing differs between the list and Tamanu
-- (INJ902 vs Inj902), which is the case exact-match comparison gets wrong.
create temporary table syn_regimen (
    slot, code, route, dose_amount, dosing_unit, dispensing_unit,
    frequency, quantity, repeats, duration_value, duration_unit, indication
) on commit drop as
values
    (0, '51130',         'oral',    5.0,   'mL',     'mL',     'Three times daily', 100, 0, 7.0,  'days',   'Acute otitis media'),
    (1, '31273',         'oral',    200.0, 'mg',     'mg',     'Every 8 hours',      30, 1, 5.0,  'days',   'Musculoskeletal pain'),
    (2, 'DonatedDUP111', 'oral',    5.0,   'mL',     'mL',     'Every 6 hours',      60, 0, 3.0,  'days',   'Fever'),
    (3, '70001',         'topical', 1.0,   'Application', 'Tube', 'Five times daily',  1, 0, 5.0,  'days',   'Herpes simplex lesion'),
    (4, 'Inj902',        'inhalation', 1.0, 'mL',    'mL',     'Once daily',          1, 0, 1.0,  'days',   'Anaesthetic induction'),
    (5, '10151',         'topical', 5.0,   'mL',     'mL',     'Once daily',        100, 0, 14.0, 'days',   'Wound cleansing');

-- ---------------------------------------------------------------------------
-- Pre-flight guards
-- ---------------------------------------------------------------------------
do $$
declare
    missing text;
    n_patients int;
begin
    select string_agg(r.code, ', ' order by r.code)
    into missing
    from syn_regimen r
    where not exists (
        select 1 from reference_data rd
        where rd.type = 'drug' and rd.deleted_at is null and rd.code = r.code
    );
    if missing is not null then
        raise exception
            'Drug codes not present on this database: %. Edit the syn_regimen block at the top of this script.',
            missing;
    end if;

    select count(*) into n_patients
    from patients p, syn_config c
    where p.deleted_at is null and p.id <> c.excluded_patient_id;
    if n_patients = 0 then
        raise exception 'No patients on this database to prescribe for.';
    end if;

    if (select count(*) from locations l
        join facilities f on f.id = l.facility_id
        where l.deleted_at is null and coalesce(f.is_sensitive, false) = false) = 0 then
        raise exception 'No locations in a non-sensitive facility -- nothing to attach encounters to.';
    end if;

    if (select count(*) from users where deleted_at is null) = 0 then
        raise exception 'No users available to act as prescribers.';
    end if;
end $$;

-- ---------------------------------------------------------------------------
-- Sample real patients
-- ---------------------------------------------------------------------------
-- md5(id || seed) is a stable pseudo-random ordering: it spreads the selection
-- across the whole patient table without depending on insertion order, and it
-- returns the same patients on every run.
create temporary table syn_patient on commit drop as
select
    p.id as patient_id,
    row_number() over (order by md5(p.id || c.sample_seed)) - 1 as slot
from patients p
cross join syn_config c
where p.deleted_at is null
    and p.id <> c.excluded_patient_id
order by md5(p.id || (select sample_seed from syn_config))
limit (select patient_count from syn_config);

create temporary table syn_location on commit drop as
select
    row_number() over (order by l.facility_id, l.id) - 1 as slot,
    l.id as location_id,
    (select d.id from departments d where d.deleted_at is null order by d.id limit 1) as department_id
from locations l
join facilities f on f.id = l.facility_id
where l.deleted_at is null
    and coalesce(f.is_sensitive, false) = false
    and l.id = (
        select l2.id from locations l2
        where l2.facility_id = l.facility_id and l2.deleted_at is null
        order by l2.id limit 1
    );

create temporary table syn_prescriber on commit drop as
select row_number() over (order by u.id) - 1 as slot, u.id as user_id
from users u where u.deleted_at is null order by u.id limit 5;

-- ---------------------------------------------------------------------------
-- Encounters -- each sampled patient attends 1 to 3 times across the window
-- ---------------------------------------------------------------------------
create temporary table syn_visit on commit drop as
select
    sp.patient_id,
    sp.slot as patient_slot,
    v.visit_no,
    -- visits land on different days per patient rather than all on the 1st
    ((select window_start from syn_config)
        + ((sp.slot * 11 + v.visit_no * 29) % 89))::date as visit_date,
    'synthetic-enc-' || substr(md5(sp.patient_id), 1, 12) || '-' || v.visit_no as encounter_id
from syn_patient sp
cross join generate_series(1, 3) as v (visit_no)
where v.visit_no <= 1 + (sp.slot % 3);

insert into encounters (
    id, patient_id, encounter_type, start_date, end_date,
    location_id, department_id, examiner_id
)
select
    sv.encounter_id,
    sv.patient_id,
    case when sv.patient_slot % 4 = 0 then 'admission' else 'clinic' end,
    to_char(sv.visit_date, 'YYYY-MM-DD') || ' '
        || lpad((8 + (sv.patient_slot % 8))::text, 2, '0') || ':'
        || lpad(((sv.patient_slot * 13) % 60)::text, 2, '0') || ':00',
    case
        when sv.patient_slot % 4 = 0
            then to_char(sv.visit_date + 2, 'YYYY-MM-DD') || ' 11:20:00'
    end,
    loc.location_id,
    loc.department_id,
    pres.user_id
from syn_visit sv
join syn_location loc
    on loc.slot = sv.patient_slot % (select count(*) from syn_location)
join syn_prescriber pres
    on pres.slot = sv.patient_slot % (select count(*) from syn_prescriber)
-- NOT EXISTS rather than ON CONFLICT: this needs no assumption about which
-- unique constraints the target database happens to carry
where not exists (
    select 1 from encounters e where e.id = sv.encounter_id
);

-- ---------------------------------------------------------------------------
-- Prescriptions -- 1 to 3 per visit, with a plausible regimen
-- ---------------------------------------------------------------------------
create temporary table syn_plan on commit drop as
select
    sv.encounter_id,
    sv.patient_id,
    sv.patient_slot,
    sv.visit_no,
    sv.visit_date,
    i.item_no,
    row_number() over (order by sv.encounter_id, i.item_no) as n,
    'synthetic-presc-' || substr(md5(sv.encounter_id), 1, 12) || '-' || i.item_no as prescription_id
from syn_visit sv
cross join generate_series(1, 3) as i (item_no)
where i.item_no <= 1 + ((sv.patient_slot + sv.visit_no) % 3);

insert into prescriptions (
    id, date, start_date, end_date, medication_id, prescriber_id,
    route, dose_amount, dosing_unit, dispensing_unit, frequency,
    quantity, repeats, duration_value, duration_unit, indication,
    is_ongoing, is_prn, is_variable_dose, unit_conversion
)
select
    sp.prescription_id,
    -- a real prescribing time of day, not midnight: consumers that truncate to
    -- a date or mishandle the timezone conversion are visible against this
    to_char(sp.visit_date, 'YYYY-MM-DD') || ' '
        || lpad((8 + (sp.n % 9))::text, 2, '0') || ':'
        || lpad(((sp.n * 7) % 60)::text, 2, '0') || ':00',
    to_char(sp.visit_date, 'YYYY-MM-DD') || ' '
        || lpad((8 + (sp.n % 9))::text, 2, '0') || ':'
        || lpad(((sp.n * 7) % 60)::text, 2, '0') || ':00',
    to_char(sp.visit_date + r.duration_value::int, 'YYYY-MM-DD') || ' 23:59:00',
    rd.id,
    -- roughly one in eight is recorded without a prescriber. prescriber_id is
    -- nullable, and a consumer that inner-joins users drops those rows with no
    -- error at all, so the data has to contain the case.
    case when sp.n % 8 = 0 then null else pres.user_id end,
    r.route,
    r.dose_amount,
    r.dosing_unit,
    r.dispensing_unit,
    r.frequency,
    r.quantity,
    r.repeats,
    r.duration_value,
    r.duration_unit,
    r.indication,
    sp.n % 9 = 0,
    sp.n % 6 = 0,
    false,
    1
from syn_plan sp
join syn_regimen r
    on r.slot = (sp.n - 1) % (select count(*) from syn_regimen)
join reference_data rd
    on rd.code = r.code and rd.type = 'drug' and rd.deleted_at is null
left join syn_prescriber pres
    on pres.slot = sp.n % (select count(*) from syn_prescriber)
where not exists (
    select 1 from prescriptions p where p.id = sp.prescription_id
);

insert into encounter_prescriptions (encounter_id, prescription_id, is_selected_for_discharge)
select sp.encounter_id, sp.prescription_id, sp.n % 12 = 0
from syn_plan sp
where not exists (
    select 1 from encounter_prescriptions ep
    where ep.prescription_id = sp.prescription_id
);

commit;

-- ---------------------------------------------------------------------------
-- What is on the database now
-- ---------------------------------------------------------------------------
select 'patients prescribed for' as entity, count(distinct e.patient_id) as n
from encounters e where e.id like 'synthetic-enc-%'
union all
select 'encounters', count(*) from encounters where id like 'synthetic-enc-%'
union all
select 'prescriptions', count(*) from prescriptions where id like 'synthetic-presc-%'
union all
select 'prescriptions without a prescriber', count(*) from prescriptions
where id like 'synthetic-presc-%' and prescriber_id is null;
