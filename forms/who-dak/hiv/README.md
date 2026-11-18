# WHO DAK HIV

The HIV domain of the [WHO DAK standard](../README.md): ten Tamanu surveys generated from the
*Digital adaptation kit for HIV*, second edition (2023), plus a program registry.

- [`domain.py`](domain.py) — everything specific to this DAK: its annexes, which tabs become which
  surveys, the core-element shortlist, the encodable Annex B rules, and the registry.
- `who-dak-hiv_program.json` / `.xlsx` — the generated spec and the workbook that gets uploaded.
- [`dak-conformance.md`](dak-conformance.md) — what conforms to the DAK, what deliberately
  diverges, and what cannot be encoded in a form.

```bash
cd forms/who-dak
FORMS_SKILL=../../../claude-plugins/plugins/tamanu/skills/build-tamanu-forms/scripts
python dak_generator.py --domain hiv
python $FORMS_SKILL/build_program_xlsx.py \
    --spec hiv/who-dak-hiv_program.json --out hiv/who-dak-hiv_program.xlsx
```

Everything carries a `who-dak-hiv` prefix because codes are global upsert keys in Tamanu: a
deployment can hold this configuration and a national adaptation side by side without either
mutating the other's questions. A country that adapts it — trimming regimens, adding a national
identifier, dropping a question it cannot store safely — is a sibling domain, not an edit to this.

## Program and registry

Program `who-dak-hiv` → id `program-whodakhiv`, shown as **WHO DAK HIV**. The importer puts the
program and survey codes through `idify` — `toLowerCase().replace(/\W/g, '')` — so the hyphens
survive in the *code* but are stripped from the *id*. Registry, clinical-status and condition ids
are not idified, so those keep theirs.
Registry `who-dak-hiv` → id `programRegistry-who-dak-hiv`, also named **WHO DAK HIV** — a
registry name has to be unique among current registries, so a national adaptation alongside this
one needs its own name, not just its own code.

| Registry setting | Value | Why |
|---|---|---|
| `currentlyAtType` | `facility` | HIV care is delivered from an ART clinic, and the retention question is "which facility is this client attending". **This cannot be changed once the registry holds registrations** — switch it to `village` before first import if the deployment tracks clients by village instead. |
| `lossToFollowUpEnabled` | `true` | Retention is the core HIV cascade measure (DAK "HIV treatment outcome", Component 5). Tamanu auto-creates a `who-dak-hiv-pltfu` "Potential loss to follow up" clinical status when this is on — it is not in the spec, and does not need to be. |
| `lossToFollowUpThresholdDays` | `90` | Tamanu's own default. WHO's current definition of treatment interruption is ≥28 days after a missed appointment, which is the stricter and more clinically useful flag; set it to `28` if the deployment reports against that definition. |

### Clinical statuses

One status per client, the HIV cascade position. Ordered as the cascade runs, and coloured so
"on treatment" reads as the good state and everything that ends the episode reads as cold or dark.

| Code | Name | Colour |
|---|---|---|
| `who-dak-hiv-diagnosed-not-on-art` | Diagnosed, not on ART | orange |
| `who-dak-hiv-on-art` | On ART | green |
| `who-dak-hiv-art-interrupted` | ART interrupted | yellow |
| `who-dak-hiv-lost-to-follow-up` | Lost to follow up | red |
| `who-dak-hiv-transferred-out` | Transferred out | blue |
| `who-dak-hiv-art-stopped` | ART stopped | brown |
| `who-dak-hiv-died` | Died | purple |
| `who-dak-hiv-pltfu` | Potential loss to follow up | grey *(auto-created)* |

`ART interrupted` and `Lost to follow up` are deliberately separate: the first is a client the
service still holds, the second is one it has lost. Collapsing them makes the retention
denominator unreadable, which is the one thing the registry exists to answer.

The prefix is load-bearing here, not decorative: `prClinicalStatus-<code>` is a global id **and**
the status `code` column carries a database-level unique constraint, so an unprefixed `on-art`
would collide with the next registry that wanted the same word.

### Registry conditions

Conditions are the comorbidities and coinfections the DAK tracks alongside HIV, so the registry
carries a client's clinical picture across visits rather than only what was captured today.
Fifteen conditions, all prefixed `who-dak-hiv-cond-`: TB (active disease), advanced HIV disease,
cryptococcal disease, Kaposi sarcoma, hepatitis B, hepatitis C, syphilis, other STI, cervical
precancer or cancer, malnutrition, hypertension, diabetes, mental health condition, substance
use disorder, HIV drug resistance.

Pregnancy is **not** a registry condition — it is captured per visit on the form, and PMTCT is
its own DAK business process (HIV.E) with its own form if the deployment needs it.

### Condition categories

**These four are deliberately not prefixed.** Tamanu hard-loads four categories into every
registry (`unknown`, `disproven`, `resolved`, `recordedInError`) and merges any spreadsheet rows
over them. The four hardcoded ones alone cannot express a condition that has been *confirmed*,
so the spec adds the standard clinical progression: `suspected`, `underInvestigation`,
`confirmed`, `inRemission`. Tamanu's UI already carries labels for exactly those codes, so
prefixing them would turn four recognised categories into four unrecognised ones — the codes
have to match. They are scoped per registry anyway (the id is
`program-registry-condition-category-<registryId>-<code>`), so there is nothing to collide with.
Drop the sheet if a deployment wants only the hardcoded four.

## The form

**Ten surveys, one per DAK business process**, generated from Annex A — 259 questions over 48
screens, where the screens are the DAK's own activities in process order. Each form therefore
reads as its business process runs (`HIV.D1` → `HIV.D29` for the care visit, Fig. 11) rather than
as a shape of our choosing.

| Survey | Code | Process | Questions | Screens | Coded | Mandatory | Indicator-linked |
|---|---|---|---|---|---|---|---|
| HIV Registration | `registration` | `HIV.A` | 12 | 2 | 2 | 11 | 3 |
| HIV Testing Services Visit | `htsvisit` | `HIV.B` | 40 | 7 | 21 | 9 | 34 |
| PrEP Visit | `prepvisit` | `HIV.C` | 13 | 4 | 9 | 3 | 10 |
| HIV Care and Treatment Visit | `carevisit` | `HIV.D` | 100 | 16 | 33 | 18 | 60 |
| HIV-TB Coinfection | `hivtb` | `HIV.D` (TB) | 15 | 3 | 7 | 1 | 12 |
| PMTCT, Delivery and Infant Diagnosis | `pmtct` | `HIV.E`–`HIV.F` | 34 | 7 | 11 | 24 | 15 |
| HIV Diagnostics | `diagnostics` | `HIV.G` | 14 | 1 | 4 | 3 | 11 |
| Follow-up and Contact Tracing | `followup` | `HIV.H` | 9 | 3 | 5 | 5 | 4 |
| HIV Referral | `referral` | `HIV.I` | 11 | 2 | 1 | 11 | 0 |
| HIV Prevention | `prevention` | `HIV.Prevention` | 11 | 3 | 2 | 0 | 11 |

Survey ids are `program-whodakhiv-<code>`. `HIV Referral` is Tamanu's `referral` survey type, so it
lands on the facility Referrals tab; the rest are `programs`. Survey names carry no `WHO DAK HIV`
prefix — they already sit under that program in the UI, and repeating it would only crowd the form
picker.

Annex A has **12** `HIV.*` tabs, not ten. The two that do not become forms:

- **`HIV.Surveillance`** defines no data elements of its own. Its rows re-list elements owned by
  other processes — HIV test date, baseline CD4, clinical stage, ART start date — as a
  cross-cutting reporting view. There is no form in it; it is a reporting concern, and belongs
  with the metric layer.
- **`HIV.Configuration`** is deployment constants rather than patient data: population prevalence
  of TB, population HIV incidence, prevalence of pretreatment NNRTI drug resistance,
  malaria-endemic setting. One value per deployment, read by the DAK's decision logic. A survey is
  the wrong artefact — these belong in Tamanu settings or a dbt seed.

Question codes carry the DAK data element id: `HIV.D.DE39` → `whodakhiv-d-de39`. Hyphens,
because the importer allows only alphanumerics and `-` in an id and the code is embedded in the
`pde-<code>` id built from it. Labels, option strings and the mandatory flag are Annex A's,
verbatim — verified against the dictionary on every build. Each question also carries a `_dak`
block in the spec recording its data element id, activity, data type, why it was selected, and the
Annex C indicators it feeds; 160 of the 259 have indicator links. That block is the crosswalk
source and is not written to the workbook, which has no column for it.

### What is captured, and what is not

The selection rule, the deliberate divergences (eight elements the DAK leaves country-configured
and so are emitted as free text), and the known gaps are all in
[`dak-conformance.md`](dak-conformance.md). Three that matter most when reading the
forms:

- **Conditional visibility is almost absent.** Annex A expresses conditionality as prose plus a
  `Required = C` flag, which does not translate mechanically into `visibilityCriteria`, so each
  form asks nearly every one of its questions every time. The exception is the four Annex B
  decision-support prompts, which are gated — see
  [`dak-conformance.md`](dak-conformance.md). Filling in the rest is the first thing
  to fix.
- **`HIV Registration` duplicates the Tamanu patient record.** It is here because the DAK defines
  the process, but `whodakhiv-a-de1` First name and `whodakhiv-a-de2` Family name as survey
  questions are the anti-pattern Tamanu forms are meant to avoid: the patient record already holds
  them. Either drop this survey, or convert its patient-demographic questions to `PatientData`
  reads. That is a deployment decision and is deliberately left open rather than guessed at.
- **Calculated elements are not here.** BMI, virally suppressed, established on ART and
  creatinine clearance are DAK Component 5 Table 12 elements, not Annex A process elements. They
  depend on history a single submission cannot see, and belong in the reporting layer.

## Before importing

Three decisions belong to the deployment, not to this repo, and are flagged rather than
silently chosen:

1. **`isSensitive` is `FALSE`.** An HIV form is a strong candidate for sensitive. It is left off
   because turning it on changes who can read the responses, which is a deployment's call, not a
   template's.
2. **Eight coded elements have no option list**, because the DAK leaves them country-configured
   (Table 13) — current ART regimen, ART regimen prescribed, medications prescribed, vaccine type,
   country of birth, administrative area, HIV diagnosing facility, adverse event severity. They are
   emitted as free text rather than having a list invented for them, and should be replaced with a
   local coded list or an `Autocomplete` over existing Tamanu reference data.
3. **Nearly every question appears on every visit**, since the DAK's conditionality is prose that
   does not translate mechanically (above). A deployment using this in anger will want the
   `visibilityCriteria` filled in first.

A country adaptation that makes those choices differently is a new sibling directory under
`hiv/` with its own prefix — not an edit to this one, which is meant to keep saying what the DAK
says.

Then, in **central admin → Import → Programs**, upload `who-dak-hiv_program.xlsx`.
Requires `create` and `write` permission on Program and Survey. The import is repeatable — it
upserts by code, so a corrected spec can be rebuilt and re-uploaded over the top.

Survey `status` is `publish`, so it imports onto a production server. A `draft` row is silently
skipped anywhere but dev, demo or staging, which is the usual reason a form "imports fine" and
then cannot be found.
