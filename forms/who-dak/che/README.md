# WHO DAK child health

Thirteen Tamanu surveys and a program registry for a sick child's IMCI consultation, generated
from the WHO DAK for child health (0–59 months) in humanitarian emergencies.

- [`domain.py`](domain.py) — everything specific to this DAK: its components, which tabs become
  which surveys, the elements the selection rule reaches for, the classification groups, the
  encodable decision rules, and the registry.
- `who-dak-che_program.json` / `.xlsx` — the generated spec and the workbook that gets uploaded.
- [`dak-conformance.md`](dak-conformance.md) — what conforms to the DAK, what deliberately
  diverges, and what cannot be encoded in a form.

```bash
cd forms/who-dak
FORMS_SKILL=../../../claude-plugins/plugins/tamanu/skills/build-tamanu-forms/scripts
python dak_generator.py --domain che
python $FORMS_SKILL/build_program_xlsx.py \
    --spec che/who-dak-che_program.json --out che/who-dak-che_program.xlsx
```

Everything carries a `who-dak-che` prefix because codes are global upsert keys in Tamanu: a
deployment can hold this configuration and a national adaptation side by side without either
mutating the other's questions.

**The directory is `che`, the kit's repository is `ccc`.** WHO slugs its source repository
`smart-dak-ccc` and titles the guide `SMART DAK CCC`, while every identifier inside the kit —
tab names, data element ids, indicator codes — reads `CHE`. The directory, the program code and
the question codes follow the identifiers, because those are what a reader matches against.

## What this program is for

IMCI assesses a sick child against a fixed sequence — danger signs, then the presenting symptom,
then the signs that go with it, then measurements and tests — and reaches a **classification**
that decides the treatment. This program carries that assessment and the classification the
health worker records at the end of it.

It does not carry the child. Tamanu holds the national id, the name, the date of birth, the sex,
the caregiver and the visit natively, so the registration activity on `CHE.A` is not a survey and
this program starts at the reason for consultation.

## Program and registry

| Registry setting | Value | Why |
|---|---|---|
| `currentlyAtType` | `facility` | An IMCI consultation happens at a facility, and every indicator in the kit is a proportion of consultations, disaggregated by facility. **This cannot be changed once the registry holds registrations** — switch it to `village` before first import where the programme is delivered by community health workers, which is common in the humanitarian settings this kit is written for. |
| `lossToFollowUpEnabled` | `true` | Every classification whose treatment does not refer the child ends in a follow-up date, so the kit does give an interval to set a threshold from. |
| `lossToFollowUpThresholdDays` | `60` | The kit's follow-up intervals run from the two days a child with pneumonia or dysentery is asked to come back in to the 30 days a child in nutritional care is. Twice the longest, so a child still inside the slowest routine schedule is never marked lost. Set explicitly rather than left to Tamanu's 90-day default, which is longer than any interval this kit schedules. |

### Clinical statuses

The kit has no element that opens or closes a child's record, so these are the pathway's rather
than the dictionary's. They describe the consultation outcome the treatment tables reach:
referral, treatment at this facility, or a routine visit with nothing to treat.

| Code | Name | Colour |
|---|---|---|
| `who-dak-che-well` | Well child | green |
| `who-dak-che-treated` | Treated at this facility | blue |
| `who-dak-che-follow-up-due` | Follow-up due | yellow |
| `who-dak-che-follow-up-overdue` | Follow-up overdue | orange |
| `who-dak-che-referred` | Referred urgently | red |
| `who-dak-che-nutrition-programme` | In a nutrition programme | purple |
| `who-dak-che-defaulted` | Defaulted | brown |
| `who-dak-che-transferred-out` | Transferred out | grey |
| `who-dak-che-aged-out` | Aged out at 5 years | teal |
| `who-dak-che-died` | Child died | pink |

`Aged out at 5 years` is the one status with no clinical content: this kit covers 0–59 months, and
a registry with no way to say a child has outgrown it accumulates registrations that no form
applies to.

### Registry conditions

What the child carries between consultations, so the assessment reads it rather than
re-establishing it each time. Each traces to an element or a classification of the kit.

| Code | Name |
|---|---|
| `who-dak-che-cond-hiv-confirmed` | Confirmed HIV infection |
| `who-dak-che-cond-hiv-exposed` | HIV exposed |
| `who-dak-che-cond-severe-acute-malnutrition` | Severe acute malnutrition |
| `who-dak-che-cond-moderate-acute-malnutrition` | Moderate acute malnutrition |
| `who-dak-che-cond-low-weight-for-age` | Low weight for age |
| `who-dak-che-cond-preterm` | Preterm birth |
| `who-dak-che-cond-chronic-ear-infection` | Chronic ear infection |
| `who-dak-che-cond-recurrent-wheeze` | Recurrent wheeze |
| `who-dak-che-cond-immunization-incomplete` | Immunizations incomplete for age |

The HIV entries are here because the pneumonia and PSBI branches turn on them, the nutritional
ones because they decide whether a severe classification is complicated, and the last two because
the ear and cough assessments both ask whether the child has been treated for this before.

## The forms

| Survey | Code | Tab | Questions | Screens | Coded | Mandatory |
|---|---|---|---|---|---|---|
| Reason for Consultation | `consultation` | `CHE.A.Registration` (`CHE.B3` slice) | 3 | 1 | 2 | 1 |
| Life-threatening Illness and Danger Signs | `danger-signs` | `CHE.B7-9.LTI-DangerSigns` | 10 | 2 | 4 | 3 |
| Measurements | `measurements` | `CHE.B6.Measurements` | 21 | 1 | 1 | 1 |
| Symptoms, 2-59 Months | `symptoms-child` | `CHE.B10-14.Symptoms ≥2 mths` | 12 | 4 | 7 | 1 |
| Signs, 2-59 Months | `signs-child` | `CHE.B10-16.Signs ≥2 mths` | 43 | 7 | 9 | 4 |
| Symptoms, Young Infant | `symptoms-infant` | `CHE.B18-21.Symptoms <2 mths` | 4 | 3 | 1 | 3 |
| Signs, Young Infant | `signs-infant` | `CHE.B18-21.Signs <2 mths` | 25 | 4 | 9 | 6 |
| Assessments and Tests | `assessments` | `CHE.B22.Assessments-Tests` | 34 | 1 | 6 | 0 |
| Health Promotion | `health-promotion` | `CHE.B17.Health Promotion` | 12 | 1 | 10 | 0 |
| Classification | `classification` | `CHE.B23.Classification` | 17 | 1 | 17 | 0 |
| Severe Classification Summary | `severe` | `CHE.B27.Combined Data Element` | 11 | 1 | 0 | 0 |
| Malaria Setting and Test Availability | `setting-malaria` | `CHE.B25.Population-Malaria` | 7 | 1 | 4 | 7 |
| HIV Prevalence Setting | `setting-hiv` | `CHE.B.26.Population-HIV` | 1 | 1 | 1 | 1 |
| **Total** | | | **200** | **28** | **71** | **27** |

Plus 26 decision-support rows — 12 guidance prompts and their patient issues, and two
health-promotion prompts with no issue — and 261 option strings taken from the dictionary.

### The classification is the output

The kit states each of its classifications as a row of its own: 72 `Derived` rows on
`CHE.B23.Classification`, each a classification its algorithm concludes, grouped by the
`Data element subcategory` column into the assessment that reaches it. Read as conclusions they
all drop, the way the PNC kit's 109 `Annotation` rows do — and that would be the end of the
program's reporting, because **all 33 of this kit's Annex C indicators count a classification**:

```
COUNT of consultations of infants and children with "age" = 0–59 months
with "Pneumonia" classification recommended
```

A health worker following IMCI records the classification, so `CLASSIFICATIONS` carries each group
as one Select-all question whose options are the group's classification labels verbatim — 17
questions carrying 72 classifications, and those labels are the strings the indicators quote.

The 28 `Derived qualifier` rows are not carried. Each qualifies one classification — `Pneumonia`,
then `With wheezing` — and the kit repeats a qualifier under every classification it applies to,
so `With wheezing` appears three times in the cough group and `Fever present every day for more
than 7 days` three times in the fever group. Flattened into one option list they collide with each
other and lose the classification they qualified, and no indicator counts one.

### One tab, seven groups

The kit defines a cluster of questions once and references the cluster by id. The respiratory rate
is five questions — the count, whether it could be taken, a second count, whether that was
possible, and the fast-breathing conclusion — defined under `CHE.B24.DE01` on
`CHE.B24.Group questions`, and named from the sign tabs for either age band and from the
assessment tab.

Nothing in the reference row says which tab holds the definition. It is marked `Group questions`
on one tab, `Group question` on another and `N/A` on a third, so what identifies a reference is
its id resolving to a group on the tab `GROUP_SOURCE` names, not the spelling beside it. Ten such
references expand to 48 questions across four surveys.

A question reached this way takes its survey into its code — `whodakche-signs-child-b24-g-de01`
and `whodakche-assessments-b24-g-de01` are the same respiratory rate taken at two points in the
consultation — because a code is a global upsert key and one unscoped code would carry the
question on whichever form was built first.

### The selection rule

The shared rule is `Required = R`, or linked to an Annex C indicator, or named in the kit's core
shortlist. **The first two rules select almost nothing here.** The
`Links to aggregate indicators` column is filled in for exactly one element in the whole kit, and
32 of the 202 candidate elements are marked `R` — 33 between the two rules. Most of the rest are
`C`, conditional on a symptom the child presents with, which is what an IMCI assessment is made of
rather than a reason to leave it out.

So the shortlist carries the program rather than supplementing it — 143 elements, against the TB
kit's 91 and the PNC kit's four. Without it the program would hold a danger-sign list, a
respiratory rate and little else: no temperature, no weight, no dehydration signs, no feeding
assessment, and no health promotion at all.

### What is captured, and what is not

Three tabs are not surveys:

- `CHE.A`'s registration activity is the patient record — national id, name, date of birth, sex,
  caregiver, telephone numbers, visit date — which Tamanu holds natively. Carrying it here would
  give a deployment two places to write a child and no rule for which one counts.
- `CHE.B24.Group questions` is where the clusters above are defined; it reaches the forms through
  `GROUP_SOURCE` rather than on its own.
- `CHE.B28.Country Configuration` holds one element, a population mean, which is a deployment
  setting rather than a question anyone answers about a child.

## Before importing

Three decisions belong to the deployment, not to this repo:

1. **`currentlyAtType` is `facility`** and cannot be changed once the registry holds
   registrations. Decide before the first import whether community delivery makes `village` the
   right unit.
2. **The classification option strings are the reporting interface.** Every Annex C indicator
   compares against them by name, so renaming one in the admin panel silently breaks the
   indicator that counts it. A deployment wanting different wording needs a mapping, not an edit.
3. **`setting-malaria` and `setting-hiv` describe the site, not the child.** They ask which
   malaria tests are available within two hours and what species the microscopists can
   differentiate — answers that are the same for every child at that facility. A deployment
   holding them as configuration instead should drop the two surveys rather than ask them at each
   consultation.
