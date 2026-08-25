# Synthetic data

SQL that generates clinical-shaped activity on a demo or local database, so the
reporting models have something substantial to run against.

> **Never run these against a production database.** They write encounter and
> prescription rows against real patient records. No script can tell a
> production database from a demo one — that check is yours.

## `prescriptions.sql`

Generates prescribing activity across **January to March 2026** for a sample of
the patients already on the database.

```bash
psql "$CONNECTION_STRING" -f prescriptions.sql
```

Takes 20 existing patients, gives each 1–3 clinic or inpatient visits across the
window, and writes 1–3 prescriptions per visit with a plausible regimen — route,
dose, units, frequency, quantity, repeats, duration and indication.

**The patients are real.** Only the encounters and prescriptions are
synthesised, so the data reads as ordinary activity for people already on the
database rather than as an obviously separate block of test records.

### Why it is shaped the way it is

The distribution is deliberate. Each choice covers something that fails
*silently* — where a broken consumer returns a plausible number rather than an
error:

| Shape | What it catches |
|---|---|
| Roughly 1 in 8 prescriptions has **no prescriber** | `prescriptions.prescriber_id` is nullable. A consumer that inner-joins `users` drops those rows with no error at all; only a row count reveals it. |
| Drug codes fall **on and off** an essential-medicines list | A deployment filtering by list membership exercises both branches instead of getting an all-or-nothing result. |
| One drug's **casing differs** between the source list and Tamanu (`INJ902` vs `Inj902`) | Code matching has to be case-insensitive. Under exact matching this one drug lands on the wrong side, and nothing else in the data shows it. |
| Visits spread across **every non-sensitive facility** | Facility parameters have something to filter, and cross-facility leakage is visible. |
| Prescription times at **realistic hours**, never midnight | Tamanu stores these as `YYYY-MM-DD HH:MM:SS` strings. A consumer that truncates to a date, or mishandles the timezone conversion, shows up. |
| Visits per patient vary (1–3), and prescriptions per visit vary (1–3) | Nothing downstream can pass by assuming a fixed fan-out from patient to prescription. |
| A mix of ongoing, PRN, and fixed-duration prescriptions; some encounters open, some closed | Exercises consumers that filter on those flags. |

### Configuration

Everything adjustable sits in two blocks at the top:

- **`syn_config`** — how many patients to sample, the sample seed, the date
  window, and the patient id to exclude. Set that last one to the deployment's
  dbt `test_patient` var: base models filter that patient out, so sampling it
  produces rows that never surface downstream.
- **`syn_regimen`** — the drug codes and the regimen prescribed for each. Codes
  resolve against `reference_data.code` where `type = 'drug'`. The defaults
  exist on the Nauru demo dataset; on another deployment, swap them.

Nothing else is deployment-specific. Facilities, locations, departments and
prescribers are all resolved by lookup, and a pre-flight guard raises a named
error listing any drug code it cannot find rather than quietly generating
nothing.

### Sampling

Patients are selected by `md5(id || seed)` ordering. That spreads the sample
across the whole patient table rather than favouring insertion order, and it is
stable: the same seed always picks the same patients, so a re-run is a no-op and
two environments seeded alike hold comparable data. Change `sample_seed` in
`syn_config` to draw a different sample.

### Re-running

The data is meant to persist, so the script never deletes. Ids are derived from
the patient id, so a second run finds its rows already present and inserts
nothing. Running it again after changing `patient_count` or `sample_seed` adds
the new patients' activity and leaves the existing rows alone.

`prescriptions-remove.sql` deletes everything the script created, matching on
the `synthetic-` id prefix. It is not part of the normal workflow — it is there
for when a database needs resetting. Real patient rows are never touched by
either script.
