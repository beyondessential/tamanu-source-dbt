# WHO DAK tuberculosis

Six Tamanu surveys and a program registry for a client's TB episode, generated from the WHO DAK
for tuberculosis.

- [`domain.py`](domain.py) — everything specific to this DAK: its components, which tabs become
  which surveys, the elements the selection rule reaches for, the encodable decision rules, and
  the registry.
- `who-dak-tb_program.json` / `.xlsx` — the generated spec and the workbook that gets uploaded.
- [`dak-conformance.md`](dak-conformance.md) — what conforms to the DAK, what deliberately
  diverges, and what cannot be encoded in a form.

```bash
cd forms/who-dak
FORMS_SKILL=../../../claude-plugins/plugins/tamanu/skills/build-tamanu-forms/scripts
python dak_generator.py --domain tb
python $FORMS_SKILL/build_program_xlsx.py \
    --spec tb/who-dak-tb_program.json --out tb/who-dak-tb_program.xlsx
```

Everything carries a `who-dak-tb` prefix because codes are global upsert keys in Tamanu: a
deployment can hold this configuration and a national adaptation side by side without either
mutating the other's questions.

## Program and registry

Program `who-dak-tb` → id `program-whodaktb`, shown as **WHO DAK TB**. The importer puts the
program and survey codes through `idify` — `toLowerCase().replace(/\W/g, '')` — so the hyphens
survive in the *code* but are stripped from the *id*. Registry, clinical-status and condition ids
are not idified, so those keep theirs.
Registry `who-dak-tb` → id `programRegistry-who-dak-tb`, also named **WHO DAK TB** — a registry
name has to be unique among current registries.

**The registry is a TB episode, and unlike contraceptive care it ends.** A client enters as
presumptive TB or as a contact assessed for preventive treatment, and leaves with one of the
kit's six treatment outcomes. That is the same shape as the HIV registry's cascade rather than
the family planning registry's standing state.

| Registry setting | Value | Why |
|---|---|---|
| `currentlyAtType` | `facility` | Diagnosis, treatment initiation and the monitoring schedule all run from a facility, and `TB.F6` records transfers between facilities by id. **This cannot be changed once the registry holds registrations** — switch it to `village` before first import where treatment is supported by community health workers, which is common for DOT. |
| `lossToFollowUpEnabled` | `true` | Interruption is the outcome the TB programme most needs to see, and it is one of the kit's own six: `TB.D24.DE.1 Treatment outcome` carries `Lost to follow-up`. Tamanu auto-creates a `who-dak-tb-pltfu` "Potential loss to follow up" clinical status when this is on — it is not in the spec, and does not need to be. |
| `lossToFollowUpThresholdDays` | `62` | The kit's own definition, from `TB.D24.DE.6`: *"Client did not start treatment or treatment was interrupted for two consecutive months or more"*. Two consecutive months is at most 62 days. Tamanu's default of 90 would leave a client the TB programme already counts as lost sitting in the registry as active for another month. |

The threshold is a registry-wide setting, so it applies to preventive treatment as well, where a
1HP course is over in a month and a 6H course runs half a year. A deployment running large TPT
cohorts should expect the flag to fire on clients who have simply finished.

### Clinical statuses

| Code | Name | Colour |
|---|---|---|
| `who-dak-tb-presumptive` | Presumptive TB | yellow |
| `who-dak-tb-excluded` | TB excluded | grey |
| `who-dak-tb-on-treatment` | On TB treatment | green |
| `who-dak-tb-on-tpt` | On TB preventive treatment | teal |
| `who-dak-tb-cured` | Cured | blue |
| `who-dak-tb-treatment-completed` | Treatment completed | blue |
| `who-dak-tb-treatment-failed` | Treatment failed | orange |
| `who-dak-tb-lost-to-follow-up` | Lost to follow-up | red |
| `who-dak-tb-died` | Died | purple |
| `who-dak-tb-transferred-out` | Transferred out | brown |
| `who-dak-tb-pltfu` | Potential loss to follow up | grey *(auto-created)* |

**Six of these are the kit's own treatment outcomes** (`TB.D24.DE.1`), and `Cured` and `Treatment
completed` are kept apart because the kit keeps them apart: cure requires bacteriological
evidence at the end of treatment and completion does not, and treatment success — the number
every TB programme reports — is the two added together. A registry that flattened them could
still report success and could no longer report either half of it.

`Not evaluated`, the kit's sixth outcome, is deliberately *not* a status: it means no outcome was
assigned, which the registry expresses by the client still standing in an earlier one. The kit's
own definition folds transfers out into it; `Transferred out` is a separate status here because
`TB.F6.DE.1 Client transferred` records the transfer as it happens, and a client whose care moved
to another facility is a different fact from a client nobody assessed.

The prefix is load-bearing, not decorative: `prClinicalStatus-<code>` is a global id **and** the
status `code` column carries a database-level unique constraint, so an unprefixed `cured` would
collide with the next registry that wanted the word.

### Registry conditions

Twenty-six conditions, all prefixed `who-dak-tb-cond-`. They are what the client carries between
contacts: the form of the disease, its resistance profile, and the comorbidities that change how
it is treated.

- **The disease** — pulmonary TB and extrapulmonary TB from `TB.Comm.DE.102 Site of TB disease`,
  and the six extrapulmonary forms from `TB.Comm.DE.105`: TB meningitis, CNS TB, disseminated TB,
  osteoarticular TB, pericardial TB, peripheral lymph node TB. The site is not a detail: it
  decides the specimen, the regimen duration and, for meningitis and osteoarticular disease, the
  regimen itself.
- **The resistance profile** — RR-TB, Hr-TB, MDR-TB, pre-XDR-TB and XDR-TB, from
  `TB.C20.DE.46 TB resistance type`. This is the single fact that decides which of the kit's
  sixteen regimens a client is eligible for, and it persists across every later contact.
- **Comorbidities** — HIV, diabetes mellitus, viral hepatitis, malnutrition, chronic lung
  disease, silica exposure, alcohol use disorder, drug use disorder, tobacco smoking, dialysis,
  anti-TNF treatment, transplantation preparation, and fibrotic lesions on chest X-ray. Each
  traces to an option of `TB.Comm.DE.23 Risk factors/comorbidities`.

**Six of that element's options are deliberately not conditions.** `Prisoners`, `Health-care
workers`, `Immigrants`, `Homeless people` and `General population in high TB prevalence settings`
are populations, not conditions — the kit lists them because they are screening risk groups, and
recording "prisoner" as a clinical condition on a patient record is both wrong and durable.
`Previously treated for TB` is a treatment history, which the diagnosis form records properly
against `TB.C4.DE.1 TB treatment history` and `TB.Comm.DE.48 Year of previous TB treatment`.

**Four are shared with the HIV and FP registries by design** — HIV, diabetes mellitus, viral
hepatitis and malnutrition — and are named as those registries name them, so a deployment running
more than one sees one condition rather than several. The kit's own word for malnutrition is
`Undernutrition`. Tuberculosis itself appears in the HIV and FP registries as a single condition;
here it is the subject, so it is carried as the site and resistance entries above.

### Condition categories

**These four are deliberately not prefixed.** Tamanu hard-loads four categories into every registry
(`unknown`, `disproven`, `resolved`, `recordedInError`) and merges any spreadsheet rows over them.
The four hardcoded ones alone cannot express a condition that has been *confirmed*, so the spec
adds the standard clinical progression: `suspected`, `underInvestigation`, `confirmed`,
`inRemission`. Tamanu's UI already carries labels for exactly those codes, so prefixing them would
turn four recognised categories into four unrecognised ones. They are scoped per registry anyway
(the id is `program-registry-condition-category-<registryId>-<code>`), so there is nothing to
collide with. Drop the sheet if a deployment wants only the hardcoded four.

## The forms

**Six surveys, one per business process**, generated from the data dictionary — 165 questions plus
15 guidance prompts and 3 patient issues over 45 screens.

| Survey | Code | Tab | Questions | Screens | Coded | Mandatory |
|---|---|---|---|---|---|---|
| TB Registration | `registration` | `TB.A.Registration` | 11 | 2 | 3 | 11 |
| TB Screening | `screening` | `TB.B.Screening` | 25 | 5 | 11 | 4 |
| TB Diagnosis | `diagnosis` | `TB.C.Diagnosis` | 61 | 14 | 34 | 9 |
| TB Treatment | `treatment` | `TB.D.TB Treatment` | 38 | 10 | 21 | 7 |
| TB Preventive Treatment | `tpt` | `TB.E.TPT` | 24 | 13 | 10 | 1 |
| TB Referral | `referral` | `TB.F.Referral` | 9 | 1 | 3 | 2 |

Survey ids are `program-whodaktb-<code>`. `TB Referral` is Tamanu's `referral` survey type, so it
lands on the facility Referrals tab; the rest are `programs`. The Questions column counts the
three patient issues with the questions that raise them, which is why screening and diagnosis
show one and two more than the element counts in the generator's own output.

**Two of the kit's eight tabs are not forms.** `TB.Configuration` holds deployment constants —
population prevalence of HIV and of TB, the national screening policy — which are Tamanu settings
or a dbt seed rather than questions a clinician answers, the same treatment the ANC, PNC and HIV
kits give their configuration tabs. `TB.Common` is not a process at all: it is where the shared
elements are *defined*, and it reaches the forms through the tabs that reference it.

### The shared tab

This kit's structural signature. Six process tabs define 132 elements in place and then reference
another 117 rows' worth from `TB.Common`, writing `Please check "TB.Common" tab for more data
element details` where the type would go. Read literally, those 117 rows are questions with no
type, no options and no description — a form of mandatory-looking free-text boxes with the kit's
answer lists stripped off.

The generator follows the reference: the definition supplies the type, the options and the
description, and the reference row supplies **this process's own `Required` flag** and
conditionality. `TB.Comm.DE.57 Symptoms of TB` is `Required = C` at screening and `R` at
diagnosis, and both are true statements about when a system must capture it.

A shared element therefore appears on every form that collects it, and its question code carries
the survey: `whodaktb-screening-comm-de-3` and `whodaktb-treatment-comm-de-3` are both
`TB.Comm.DE.3 Body weight (kg)`. A code becomes the global `pde-<code>` id and may appear once
per workbook, so a single unscoped code would carry weight on whichever form was built first and
silently drop it from the other three — and weight at screening, at diagnosis, at each treatment
follow-up and for TPT dosing are four different measurements. `_dak.dataElementId` is unchanged
on all four, so an indicator still reaches every copy.

64 of the 165 questions are shared-tab copies, of 27 distinct elements.

### Question codes and labels

Question codes carry the data element id: `TB.C24.DE.1` → `whodaktb-c24-de-1`, with the survey
inserted for a shared element as above. Labels, option strings and the mandatory flag are the
dictionary's, verbatim — 165 of 165 questions verified against an independent read of Annex A,
with zero label, option or mandatory mismatches. 82 coded questions carry 437 of the kit's own
options.

### The selection rule

An element is carried when it is `Required = R`, feeds an Annex C indicator, or is named in the
domain's shortlist. **This kit leans on the shortlist heavily.** Of the 249 elements its six
process tabs offer, 34 are `Required = R` and 161 are `Required = C`, so the first two rules
alone leave the TPT form with the seven elements Annex C happens to link and no record of what
was given, and the diagnostic cascade without the drug-susceptibility panel it turns on.

The shortlist names 91 elements across five tabs, and every one is an input to an encoded Annex B
rule, an element an Annex C calculation names, or a branch the care pathway turns on. See
[`dak-conformance.md`](dak-conformance.md).

### What is captured, and what is not

Four things that matter most when reading the forms; the rest is in
[`dak-conformance.md`](dak-conformance.md):

- **The forms do not choose a regimen.** `TB.D9.DT` and `TB.D10.DT` select from sixteen regimens
  on resistance, age, site, severity and pregnancy, and `TB.DT.14` is 311 rows of weight-band
  dosing. A Tamanu `visibilityCriteria` is a conjunction of equalities on one form, so none of
  that is expressible. The forms collect every input and record the regimen the clinician chose.
- **Neither do they reach a screening result.** `TB.B7.DT` walks 57 rules over five inputs to get
  there. The form collects the inputs, records the result the health worker reached, and shows
  the kit's own guidance for that result — refer for diagnostic evaluation, assess for TPT, or
  repeat the test.
- **Conditional visibility is almost absent.** The dictionary expresses conditionality as prose in
  `Explain conditionality` plus a `Required = C` flag, which does not translate mechanically into
  `visibilityCriteria`, so each form asks nearly every one of its questions every time. The 18
  Annex B prompts and issues are the only gated content.
- **`TB.C11.DE.12 TB diagnostic tool` imports as free text.** The dictionary types it `Coding` and
  gives it no options, so the list of tools a facility actually has is a deployment's to supply.
  Annex B's `TB.C16.1.DT.05` compares it against `Xpert MTB/RIF Ultra`, so a deployment adding the
  list should use the kit's own spelling.

## Before importing

Four decisions belong to the deployment, not to this repo:

1. **`isSensitive` is `FALSE`.** These forms carry HIV status, CD4 count, ART dates, drug and
   alcohol use, and imprisonment as a screening risk group. Turning it on changes who can read the
   responses, which is a deployment's call.
2. **`currentlyAtType` is `facility`** and cannot be changed once the registry holds
   registrations. Community-supported treatment is common in TB programmes; decide before the
   first import.
3. **`TB Treatment` is one form for the whole of treatment**, because the kit's tab is: it carries
   eligibility, the regimen, initiation, the monthly follow-up examinations and the final outcome,
   and `TB.D24.DE.1 Treatment outcome` is `Required = R`, so a mandatory outcome sits on the form
   a nurse fills in at every monthly visit. A deployment using this in anger will want to split it
   into initiation, follow-up and outcome forms, or make that question optional first.
4. **`TB Registration` duplicates the Tamanu patient record.** First name, last name, unique id,
   address, sex and telephone number are all `Required = R`, so the selection rule cannot leave
   them out. Tamanu already holds them on the patient; a deployment should trim this form to the
   fields the TB programme adds — source of referral, encounter date, age group — before first
   import.

A country adaptation that makes those choices differently is a new sibling directory with its own
prefix — not an edit to this one, which is meant to keep saying what the DAK says.

Then, in **central admin → Import → Programs**, upload `who-dak-tb_program.xlsx`. Requires
`create` and `write` permission on Program and Survey. The import is repeatable — it upserts by
code, so a corrected spec can be rebuilt and re-uploaded over the top.

Survey `status` is `publish`, so it imports onto a production server. A `draft` row is silently
skipped anywhere but dev, demo or staging, which is the usual reason a form "imports fine" and then
cannot be found.
