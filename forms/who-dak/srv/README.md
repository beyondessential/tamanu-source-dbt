# WHO DAK infectious disease surveillance

Fourteen Tamanu surveys and a program registry for a notifiable-disease case, generated from the
WHO Surveillance DAK — disease-agnostic components plus modules for cholera, measles, bacterial
meningitis and yellow fever.

- [`domain.py`](domain.py) — everything specific to this DAK: its components, which slice of which
  disease tab becomes which survey, the elements the selection rule reaches for, the elements the
  patient record already holds, the encodable decision rules, and the registry.
- `who-dak-srv_program.json` / `.xlsx` — the generated spec and the workbook that gets uploaded.
- [`dak-conformance.md`](dak-conformance.md) — what conforms to the DAK, what deliberately
  diverges, and what cannot be encoded in a form.

```bash
cd forms/who-dak
FORMS_SKILL=../../../claude-plugins/plugins/tamanu/skills/build-tamanu-forms/scripts
python dak_generator.py --domain srv
python $FORMS_SKILL/build_program_xlsx.py \
    --spec srv/who-dak-srv_program.json --out srv/who-dak-srv_program.xlsx
```

Everything carries a `who-dak-srv` prefix because codes are global upsert keys in Tamanu: a
deployment can hold this configuration and a national adaptation side by side without either
mutating the other's questions.

## What this program is for

Disease surveillance detects a case, tests it, classifies it and reports it. The DAK writes that
as five business processes — clinical evaluation, laboratory, reporting, outbreak investigation,
contact tracing — and repeats all five for each disease it covers. This program carries the three
of those moments that are about **one case**: what the clinician found, what the laboratory
returned, and how the surveillance officer finally classified it.

It does not carry the client. Tamanu holds the name, the identifier, the date of birth, the sex,
the address and its administrative hierarchy, the encounter, the facility, the clinician and the
referral natively, so `Registration common` contributes only the two facts the patient record has
no field for: whether the client has symptoms, and when the first one started.

It also does not carry the counts a surveillance unit reports upward. See
[`dak-conformance.md`](dak-conformance.md) § Three grains.

## Program and registry

| Registry setting | Value | Why |
|---|---|---|
| `currentlyAtType` | `facility` | A case is detected, tested and reported at a facility, and every indicator in the kit is a proportion of cases or specimens at a reporting site. **This cannot be changed once the registry holds registrations** — switch it to `village` before first import where surveillance is community-based. |
| `lossToFollowUpEnabled` | `false` | A surveillance case is closed by classification and outcome, not abandoned, and the kit has no element saying a case stopped being followed. Left off rather than given a threshold this DAK does not state. |

**A registration is a case, not a client.** A person presenting with cholera and later with
measles is enrolled twice. That is the grain every Annex C indicator counts.

### Clinical statuses

Where the case stands. The kit classifies a case twice — once against the case definition when it
presents, and again at `E6` once the clinical and laboratory data are in. The registry holds the
second, whose values are the union of the four diseases' `Final case classification` options.
`Probable` is meningitis's and yellow fever's. Measles is the one disease that classifies a case
as measles without laboratory confirmation, so its `Epidemiologically linked` and `Clinically
compatible` are statuses of their own: neither is confirmed, and neither is a case still under
suspicion. `Discarded` covers cholera's `Not a suspected case`, measles's `Non-measles discarded
case` and yellow fever's own `Discarded`.

| Code | Name | Colour |
|---|---|---|
| `who-dak-srv-suspected` | Suspected case | yellow |
| `who-dak-srv-probable` | Probable case | orange |
| `who-dak-srv-epi-linked` | Epidemiologically linked case | pink |
| `who-dak-srv-clinically-compatible` | Clinically compatible case | brown |
| `who-dak-srv-confirmed` | Confirmed case | red |
| `who-dak-srv-discarded` | Discarded | grey |
| `who-dak-srv-recovered` | Recovered | green |
| `who-dak-srv-died` | Died | purple |

`Recovered` and `Died` are the outcome, from the two values of `SRV.C13.DE.7 Outcome` — `Alive`
and `Deceased`; the other six are the classification.

### Registry conditions

Which disease the case is of, from the options of `SRV.C11.DE.1 Diagnosis` — the one element the
kit defines disease-agnostically and every disease's process records.

| Code | Name |
|---|---|
| `who-dak-srv-cond-cholera` | Cholera |
| `who-dak-srv-cond-measles` | Measles |
| `who-dak-srv-cond-bacterial-meningitis` | Bacterial meningitis |
| `who-dak-srv-cond-yellow-fever` | Yellow fever |
| `who-dak-srv-cond-other` | Other notifiable disease |

`Other` is the kit's own fifth option, and it is what a deployment adding a disease module of its
own records against until the kit publishes one.

## The forms

Three surveys per disease, because the kit's five processes are three moments with three different
people in them: the clinician at the bedside, the laboratory, and the surveillance officer
afterwards.

| Survey | Code | Tab (activities) | Questions | Screens | Coded | Mandatory |
|---|---|---|---|---|---|---|
| Surveillance Symptom Onset | `onset` | `Registration common` | 2 | 1 | 0 | 1 |
| Cholera Case Notification | `chol-case` | `Cholera` (`C1`–`C13`) | 8 | 4 | 3 | 6 |
| Cholera Laboratory Results | `chol-lab` | `Cholera` (`D1`–`D9`) | 6 | 3 | 2 | 6 |
| Cholera Case Investigation | `chol-inv` | `Cholera` (`F1`, `E6`) | 5 | 2 | 4 | 5 |
| Measles Case Notification | `msl-case` | `Measles` (`C1`–`C10`) | 11 | 4 | 2 | 10 |
| Measles Laboratory Results | `msl-lab` | `Measles` (`D1`, `D8`) | 3 | 2 | 1 | 3 |
| Measles Case Investigation | `msl-inv` | `Measles` (`F1`, `G1`–`G4`, `E4`, `E6`) | 15 | 4 | 4 | 14 |
| Bacterial Meningitis Case Notification | `men-case` | `Bacterial Meningitis` (`C1`–`C11`) | 13 | 5 | 7 | 13 |
| Bacterial Meningitis Laboratory Results | `men-lab` | `Bacterial Meningitis` (`D1`, `D8`) | 11 | 2 | 7 | 10 |
| Bacterial Meningitis Case Investigation | `men-inv` | `Bacterial Meningitis` (`F1`, `E4`, `E6`) | 6 | 3 | 2 | 5 |
| Yellow Fever Case Notification | `yf-case` | `Yellow fever` (`C1`–`C10`) | 12 | 4 | 2 | 9 |
| Yellow Fever Laboratory Results | `yf-lab` | `Yellow fever` (`D1`, `D8`) | 5 | 2 | 3 | 3 |
| Yellow Fever Case Investigation | `yf-inv` | `Yellow fever` (`F1`, `E4`, `E6`) | 7 | 3 | 5 | 7 |
| Surveillance Diagnosis and Outcome | `outcome` | `Surveillance common` | 4 | 2 | 2 | 3 |

**104 dictionary questions across 41 screens**, 219 option strings, 95 mandatory, 33 linked to an
Annex C indicator. Fifteen more come from Annex B: eleven guidance prompts and four patient
issues, the latter counted in the `Questions` column above because Tamanu treats them as
answerable. The workbook holds 160 rows in all, the rest being screen and section headings.

`Coded` counts questions answered from a list rather than freely. Terminology mappings — ICD-11,
ICD-10, LOINC, SNOMED CT, ICHI, ICF and ATC — ride along on every question in `_dak`.

**A case uses one disease's three surveys, not all fourteen.** The onset and outcome surveys are
disease-agnostic and bracket whichever module the case belongs to.

## Question codes

A question code keeps the kit's own element id whole, disease prefix and all —
`whodaksrv-cholsrv-c1-de-12`. Every other domain strips the kit's prefix before building the code;
this one cannot, because `CHOLSRV.C1.DE.12` and `MSLSRV.C1.DE.12` are different elements of
different diseases and the prefix is the only thing telling them apart.
