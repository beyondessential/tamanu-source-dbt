# WHO DAK self-monitoring of blood pressure in pregnancy

Two Tamanu surveys and a program registry for a pregnant client monitoring her own blood pressure,
generated from the WHO SMBP DAK.

- [`domain.py`](domain.py) — everything specific to this DAK: its components, which tab becomes
  which survey, the elements the selection rule reaches for, the elements the patient record
  already holds, the Annex B rules a form can express, and the registry.
- `who-dak-smbp_program.json` / `.xlsx` — the generated spec and the workbook that gets uploaded.
- [`dak-conformance.md`](dak-conformance.md) — what conforms to the DAK, what deliberately
  diverges, and what cannot be encoded in a form.

```bash
cd forms/who-dak
FORMS_SKILL=../../../claude-plugins/plugins/tamanu/skills/build-tamanu-forms/scripts
python dak_generator.py --domain smbp
python $FORMS_SKILL/build_program_xlsx.py \
    --spec smbp/who-dak-smbp_program.json --out smbp/who-dak-smbp_program.xlsx
```

Everything carries a `who-dak-smbp` prefix because codes are global upsert keys in Tamanu: a
deployment can hold this configuration and a national adaptation side by side without either
mutating the other's questions.

## What this program is for

WHO recommends that a pregnant woman with, or at risk of, a hypertensive disorder may measure her
own blood pressure between antenatal contacts. The DAK writes that as two things a digital system
has to do: set her up once — her diagnosis, her conditions and medications, whichever prior
reading exists, which arm to use, and a baseline taken as two seated measurements averaged — and
then record each reading she takes afterwards, with the context that explains it and the danger
signs she reports alongside it.

This program is those two, one survey each. A third activity, `SMBP.B7 Review health actions based
on SMBP results`, collects nothing at all: it is where the kit's decision tables sit, and what it
produces is guidance. That guidance rides on the reading form as Annex B prompts, beside the
answers that raise it.

It does not carry the client's own registration. Tamanu holds the name, the identifier, the date
of birth, the address, the telephone number and the email natively, so those seven elements are
left to the patient record. Nor does it carry the twelve elements naming the client's closest
facility, her health worker, her pharmacy and her community health worker: those configure her own
tracking application so it knows whom to alert, and are not facts about her.

## Program and registry

| Registry setting | Value | Why |
|---|---|---|
| `currentlyAtType` | `facility` | The clinic that enrolled her is what reviews her readings and what she is referred back to. **This cannot be changed once the registry holds registrations** — switch it to `village` before first import where the program is run by community health workers. |
| `lossToFollowUpEnabled` | `false` | A client who stops submitting readings is exactly what the program watches for, but the kit states no monitoring interval: its scheduling-logic column is empty on all 122 rows and it publishes no scheduling annexe. A threshold chosen here would mark her lost on a cadence WHO has not set. A deployment that has agreed one sets `lossToFollowUpEnabled` and `lossToFollowUpThresholdDays` in [`domain.py`](domain.py) and regenerates. |

**A registration is an episode, not a reading.** A client enrols once, submits readings until the
pregnancy ends, and is one registration throughout — the reading form is answered many times
against it. That is the grain the registry's conditions and statuses are stated at.

### Clinical statuses

Where the episode stands. The kit has no case-status element of its own — unlike the surveillance
kits, whose statuses are theirs — so this is our own modelling of its two processes: enrolment and
baseline, then the readings, then a close.

| Code | Name | Colour |
|---|---|---|
| `who-dak-smbp-enrolled` | Enrolled | blue |
| `who-dak-smbp-monitoring` | Monitoring | green |
| `who-dak-smbp-referred` | Referred to health worker | orange |
| `who-dak-smbp-pregnancy-ended` | Pregnancy ended | purple |
| `who-dak-smbp-stopped` | Monitoring stopped | yellow |
| `who-dak-smbp-lost-to-follow-up` | Lost to follow-up | red |
| `who-dak-smbp-moved-away` | Moved away | teal |

`Enrolled` and `Monitoring` are the two halves of the kit's own set-up process: a client is
enrolled when her tracking is configured and monitoring once her baseline is taken, and a
registration sitting at `Enrolled` with readings arriving against it is a baseline that was never
established. `Referred to health worker` is where a registration sits between a reading that
raised one of the Annex B prompts and the review that closes it out — `SMBP.B7` in the kit, which
has no form of its own.

### Registry conditions

What the client is monitored for, carried across readings rather than held only by the set-up
form.

| Code | Name | From |
|---|---|---|
| `who-dak-smbp-cond-chronic-hypertension` | Chronic hypertension | `SMBP.A9.DE.33` |
| `who-dak-smbp-cond-gestational-hypertension` | Gestational hypertension | `SMBP.A9.DE.34` |
| `who-dak-smbp-cond-pre-eclampsia` | Pre-eclampsia | `SMBP.A9.DE.35` |
| `who-dak-smbp-cond-superimposed-pre-eclampsia` | Chronic hypertension with superimposed pre-eclampsia | `SMBP.A9.DE.36` |
| `who-dak-smbp-cond-gdm` | Diabetes arising in pregnancy (gestational diabetes) | `SMBP.A9.DE.40` |
| `who-dak-smbp-cond-diabetes-type-1` | Diabetes, pre-existing type 1 | `SMBP.B7.DT.01` |
| `who-dak-smbp-cond-diabetes-type-2` | Diabetes, pre-existing type 2 | `SMBP.B7.DT.01` |
| `who-dak-smbp-cond-diabetes-other` | Diabetes, other or unspecified | `SMBP.A9.DE.41` |

The first four are the value set of `SMBP.A9.DE.32 Type of hypertensive disorder of pregnancy`,
which is the mandatory question the set-up form opens the client's history with.

**The four diabetes rows are load-bearing rather than descriptive.** `SMBP.B7.DT.01` lowers the
threshold at which the kit refers a client from 140/90 to 130/80 where she has diabetes, and that
gate cannot be written on the reading form: the answer is on the set-up form, and a visibility
gate names questions of the survey it is on. Held as a registry condition, the diabetes is
attached to the registration each reading is recorded against, which is what lets a `metric__`
layer over these two forms apply the threshold the form could not. See
[`dak-conformance.md`](dak-conformance.md) § A threshold that reads another survey.

Two of them are named by that decision table and by no row of the dictionary, whose
`Current health conditions` list offers gestational diabetes and `Diabetes, other or unspecified`
and nothing between. The strings are the decision table's own; the form's option list is left as
Annex A wrote it.

### Registry condition categories

Tamanu hard-loads `unknown`, `disproven`, `resolved` and `recordedInError` into every registry and
merges spreadsheet rows over them. None of those four can express a condition that is *held*, and
self-monitoring exists to catch a rise before it is diagnosed, so the two ends of that are added.

| Code | Name |
|---|---|
| `suspected` | Suspected |
| `confirmed` | Confirmed |

## The forms

| Survey | Code | Tab | Questions | Screens | Coded | Mandatory |
|---|---|---|---|---|---|---|
| SMBP Set-up and Baseline | `setup` | `SMBP.A Identification & prep` | 24 | 1 | 5 | 14 |
| SMBP Reading | `reading` | `SMBP.Conduct SMBP` | 18 | 1 | 6 | 8 |

**42 dictionary questions across 2 screens**, 53 option strings, 22 mandatory. Annex B adds seven
guidance prompts and three patient issues to the reading form. The workbook holds 54 rows in all,
the rest being screen headings.

`Coded` counts questions answered from a list rather than freely. Terminology mappings — ICD-11,
ICD-10, LOINC, SNOMED CT, ICHI, ICF and ATC — ride along on every question in `_dak`.

**This kit publishes no Annex C**, so there is no indicator coverage to report:
`python annex_c_coverage.py --domain smbp` says so rather than failing. See
[`dak-conformance.md`](dak-conformance.md) § No indicators.

### One screen per survey

Every other kit divides a process tab into activities and the reader turns each into a screen.
This one gives each tab a single activity — all 72 rows of the set-up tab are `SMBP.A9`, all 50 of
the reading tab are `SMBP.B4` — and heads no sections, so each survey is one screen. No section
headings are invented to break them up: a screen division states which questions belong together,
and the kit states none. See [`dak-conformance.md`](dak-conformance.md) § One activity, one
screen.

### The reading form escalates

`SMBP Reading` carries the two averages the kit's decision tables read, and each is followed by the
prompts its value raises: record the context at 140/90, contact a health worker from 140/90, go to
a facility right away from 160/110, with a patient issue on the last. The danger-sign question does
the same — any of the eight the kit classifies raises an urgent prompt and an issue.

Nothing is raised when a reading is normal or no danger sign is reported. Both of the kit's
reassuring outputs can render beside the warning they contradict, so neither is encoded — see
[`dak-conformance.md`](dak-conformance.md) § No reassurance is encoded.

## Question codes

A question code strips the kit's `SMBP.` prefix and keeps the rest of the element id —
`whodaksmbp-b4-de-4`, `whodaksmbp-a9-de-66`. What makes the ids unique is the segment after the
prefix, which names the tab's own numbering. The set-up and reading tabs both carry a
`First seated systolic reading in arm for SMBP measurements`, and `whodaksmbp-a9-de-62` and
`whodaksmbp-b4-de-2` are what keep the baseline and the readings apart.
