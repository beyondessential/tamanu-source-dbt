# WHO DAK birth defects surveillance

Three Tamanu surveys and a program registry for a congenital anomaly case, generated from the WHO
Birth Defects Surveillance DAK.

- [`domain.py`](domain.py) — everything specific to this DAK: its components, which tab becomes
  which survey, the elements the selection rule reaches for, the elements the patient record
  already holds, and the registry.
- `who-dak-bds_program.json` / `.xlsx` — the generated spec and the workbook that gets uploaded.
- [`dak-conformance.md`](dak-conformance.md) — what conforms to the DAK, what deliberately
  diverges, and what cannot be encoded in a form.

```bash
cd forms/who-dak
FORMS_SKILL=../../../claude-plugins/plugins/tamanu/skills/build-tamanu-forms/scripts
python dak_generator.py --domain bds
python $FORMS_SKILL/build_program_xlsx.py \
    --spec bds/who-dak-bds_program.json --out bds/who-dak-bds_program.xlsx
```

Everything carries a `who-dak-bds` prefix because codes are global upsert keys in Tamanu: a
deployment can hold this configuration and a national adaptation side by side without either
mutating the other's questions.

## What this program is for

A birth defects surveillance system records every newborn, stillbirth and termination found to
have a congenital anomaly, so that the prevalence of each anomaly can be tracked and a change in
it detected. The DAK writes that as three business processes — collection and abstraction, case
confirmation, data aggregation — and this program carries the two of them that are about **one
case**: the case record the data collector fills in or abstracts, and the anomaly diagnosis
assigned against it.

It does not carry the newborn's own registration. Tamanu holds the name, the identifier, the date
of birth, the sex and the facility natively, so those seven elements are left to the patient
record. The parents' names and identifiers **are** on the form: Tamanu can link a patient to a
mother and a father, but only where both are patients of this deployment, and a surveillance case
is routinely recorded for a newborn whose mother is not.

It also does not carry the periodic report a surveillance unit approves and sends upward. See
[`dak-conformance.md`](dak-conformance.md) § Three processes, two forms.

## Program and registry

| Registry setting | Value | Why |
|---|---|---|
| `currentlyAtType` | `facility` | A case is found, abstracted and confirmed at a facility, and the kit's coverage indicator is a proportion of the live births at a reporting site. **This cannot be changed once the registry holds registrations** — switch it to `village` before first import where surveillance is community-based. |
| `lossToFollowUpEnabled` | `false` | The kit has a loss-to-follow-up indicator, `BDS.IND.41`, and states it as a case record status rather than as an elapsed time: cases that are `Incomplete` over cases that are `Complete` or `Incomplete`. The status below already carries that, so Tamanu's separate threshold is left off rather than giving one fact two places to be recorded. |

**A registration is a case, not a client.** The kit's own unit is the case record, and a newborn
found to have anomalies of two body systems is one case with two conditions rather than two
registrations. That is the grain every Annex C prevalence counts.

### Clinical statuses

Where the case record stands, from the four values of `BDS.Comm.DE.1 Case record status`. This is
the element the kit's data-quality indicators are all keyed on — `BDS.IND.39` counts completeness
within `Complete`, `BDS.IND.41` reads `Incomplete` as loss to follow-up, and `BDS.IND.42` and
`BDS.IND.43` restrict to `Complete` — and every prevalence numerator requires it as well.

| Code | Name | Colour |
|---|---|---|
| `who-dak-bds-open` | Open | blue |
| `who-dak-bds-incomplete` | Incomplete | orange |
| `who-dak-bds-complete` | Complete | green |
| `who-dak-bds-discarded` | Discarded | grey |

### Registry conditions

Which anomaly the case is of, from the ten body-system groups the kit offers directly under
`BDS.Comm.DE.20 Congenital anomaly diagnosis`.

| Code | Name |
|---|---|
| `who-dak-bds-cond-cns` | Central nervous system defects |
| `who-dak-bds-cond-ear` | Ear defects |
| `who-dak-bds-cond-heart` | Congenital heart defects |
| `who-dak-bds-cond-orofacial` | Orofacial defects |
| `who-dak-bds-cond-gastrointestinal` | Gastrointestinal defects |
| `who-dak-bds-cond-genitourinary` | Genitourinary defects |
| `who-dak-bds-cond-musculoskeletal` | Musculoskeletal defects |
| `who-dak-bds-cond-abdominal-wall` | Abdominal wall defects |
| `who-dak-bds-cond-chromosomal` | Chromosomal abnormalities |
| `who-dak-bds-cond-infection` | Congenital infection syndromes |

The group rather than the specific defect. The groups are the level a registry list stays legible
at, and the specific defect is on the form, where the value set's lower levels record it.

### Registry condition categories

Tamanu hard-loads `unknown`, `disproven`, `resolved` and `recordedInError` into every registry and
merges spreadsheet rows over them. The kit's `BDS.Comm.DE.7 Congenital anomaly diagnosis status`
has four values, and two of them the hard-loaded four already say: `Excluded` is `disproven`, and
`Misdiagnosis` is `recordedInError`. The other two are the distinction every prevalence indicator
turns on — each counts `"Congenital anomaly diagnosis status" = "Confirmed diagnosis"` — and
neither is expressible, so both are added.

| Code | Name |
|---|---|
| `possible` | Possible diagnosis |
| `confirmed` | Confirmed diagnosis |

## The forms

| Survey | Code | Tab | Questions | Screens | Coded | Mandatory |
|---|---|---|---|---|---|---|
| Birth Defects Case Record | `case` | `BDS.A.Data collect abstract` | 34 | 5 | 2 | 14 |
| Birth Defects Anomaly Diagnosis | `anomaly` | `BDS.Common` | 32 | 3 | 32 | 3 |
| Birth Defects Case Confirmation | `review` | `BDS.B.Case confirmation` | 4 | 4 | 0 | 0 |

**70 dictionary questions across 12 screens**, 156 option strings, 17 mandatory, 16 linked to an
Annex C indicator. The workbook holds 82 rows in all, the rest being screen headings. Nothing
comes from Annex B, which this kit does not publish — see
[`dak-conformance.md`](dak-conformance.md) § No decision-support logic.

`Coded` counts questions answered from a list rather than freely. Terminology mappings — ICD-11,
ICD-10, LOINC, SNOMED CT, ICHI, ICF and ATC — ride along on every question in `_dak`.

**All 42 of the kit's Annex C indicators are computable from these forms.** Run
`python annex_c_coverage.py --domain bds` to check that against the current spec.

### The anomaly form is a tree

`Birth Defects Anomaly Diagnosis` is one question and its value set, three levels deep.
`Congenital anomaly diagnosis` offers the ten body-system groups; picking one reveals that group's
own question; picking a value there that is itself a list reveals the third level. Twenty-seven of
its thirty-two questions are gated this way, so a case with one anomaly is asked about one branch
rather than about all ten. See [`dak-conformance.md`](dak-conformance.md) § A value set that
nests.

## Question codes

A question code strips the kit's `BDS.` prefix and keeps the rest of the element id —
`whodakbds-comm-de-20`, `whodakbds-a4-de-1`. What makes the ids unique is the segment after the
prefix, which names the tab's own numbering.
