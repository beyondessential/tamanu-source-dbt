# WHO DAK ANC

The antenatal care domain of the [WHO DAK standard](../README.md): nine Tamanu surveys generated
from the *Digital adaptation kit for antenatal care* (2021), plus a program registry for the
pregnancy episode.

- [`domain.py`](domain.py) — everything specific to this DAK: its annexes, which tabs become which
  surveys, the elements the selection rule reaches for, the encodable Annex B rules, and the
  registry.
- `who-dak-anc_program.json` / `.xlsx` — the generated spec and the workbook that gets uploaded.
- [`dak-conformance.md`](dak-conformance.md) — what conforms to the DAK, what deliberately
  diverges, and what cannot be encoded in a form.

```bash
cd forms/who-dak
FORMS_SKILL=../../../claude-plugins/plugins/tamanu/skills/build-tamanu-forms/scripts
python dak_generator.py --domain anc
python $FORMS_SKILL/build_program_xlsx.py \
    --spec anc/who-dak-anc_program.json --out anc/who-dak-anc_program.xlsx
```

Everything carries a `who-dak-anc` prefix because codes are global upsert keys in Tamanu: a
deployment can hold this configuration and a national adaptation side by side without either
mutating the other's questions. A country that adapts it — different bands, a national identifier,
a question it cannot store safely — is a sibling domain, not an edit to this.

## Program and registry

Program `who-dak-anc` → id `program-whodakanc`, shown as **WHO DAK ANC**. The importer puts the
program and survey codes through `idify` — `toLowerCase().replace(/\W/g, '')` — so the hyphens
survive in the *code* but are stripped from the *id*. Registry, clinical-status and condition ids
are not idified, so those keep theirs.
Registry `who-dak-anc` → id `programRegistry-who-dak-anc`, also named **WHO DAK ANC** — a registry
name has to be unique among current registries, so a national adaptation alongside this one needs
its own name, not just its own code.

The registry holds **one pregnancy episode per woman**: the ANC record the DAK opens at
registration and closes with `ANC.End.1 Reason for closing ANC record`. Everything about the
episode that has to survive between contacts — where she is in it, which conditions she is
carrying — lives here rather than in the answers to any one contact's form.

| Registry setting | Value | Why |
|---|---|---|
| `currentlyAtType` | `facility` | ANC is delivered from a clinic, and the retention question is "which facility is this woman attending". **This cannot be changed once the registry holds registrations** — switch it to `village` before first import if the deployment tracks women by village instead, which is the usual choice where contacts are made by outreach. |
| `lossToFollowUpEnabled` | `true` | A missed contact is the core ANC measure: WHO's 2016 model recommends eight contacts, and `ANC.End.1` carries `Lost to follow-up` as one of its closure reasons. Tamanu auto-creates a `who-dak-anc-pltfu` "Potential loss to follow up" clinical status when this is on — it is not in the spec, and does not need to be. |
| `lossToFollowUpThresholdDays` | `56` | Eight weeks, the widest gap in WHO's eight-contact schedule (first contact by 12 weeks, then 20, 26, 30, 34, 36, 38, 40). A woman unseen for longer than the longest planned interval has missed a contact. Tamanu's own default of 90 days spans most of a trimester, which on a 40-week episode flags almost nothing in time to act on it. |

### Clinical statuses

One status per woman: where this pregnancy episode stands. One open state, then the outcomes
`ANC.End.1` itself lists, so a closure recorded on the **ANC Episode Outcome** form has a status to
move the registration to.

| Code | Name | Colour |
|---|---|---|
| `who-dak-anc-attending` | Attending ANC | green |
| `who-dak-anc-live-birth` | Live birth | blue |
| `who-dak-anc-stillbirth` | Stillbirth | brown |
| `who-dak-anc-miscarriage` | Miscarriage | orange |
| `who-dak-anc-abortion` | Abortion | yellow |
| `who-dak-anc-died` | Woman died | purple |
| `who-dak-anc-lost-to-follow-up` | Lost to follow-up | red |
| `who-dak-anc-moved-away` | Moved away | teal |
| `who-dak-anc-false-pregnancy` | False pregnancy | pink |
| `who-dak-anc-pltfu` | Potential loss to follow up | grey *(auto-created)* |

`Lost to follow-up` and `Moved away` are deliberately separate, for the same reason the DAK
separates them: the first is a woman the service has lost, the second is one it handed on. Reading
them together makes the retention denominator unanswerable, which is the one thing the registry
exists to answer.

`Wrong entry`, the ninth `ANC.End.1` option, is **not** a status. It means the record should not
exist, and a status leaves a phantom pregnancy episode sitting in every outcome denominator; delete
the registration instead, or mark it with the `recordedInError` condition category. `Other
(specify)`, the tenth, has no status either: it is the kit's escape hatch for a closure reason it
does not model, and inventing a status for it would give every unmodelled outcome one meaningless
bucket. A deployment that finds itself using it should add the reason it actually needs.

The prefix is load-bearing here, not decorative: `prClinicalStatus-<code>` is a global id **and**
the status `code` column carries a database-level unique constraint, so an unprefixed `live-birth`
would collide with the next registry that wanted the same words.

### Registry conditions

Conditions are what the woman is carrying through the pregnancy, so the registry holds her clinical
picture across contacts rather than only what was recorded today. Eighteen conditions, all prefixed
`who-dak-anc-cond-`, each tracing to a diagnosis element in Annex A or to an option of
`ANC.B6.DE83 Existing chronic health conditions`:

- **Diagnosed in this pregnancy** — anaemia, asymptomatic bacteriuria, gestational diabetes
  mellitus, hypertension, severe hypertension, pre-eclampsia, severe pre-eclampsia.
- **Infections** — HIV, syphilis, hepatitis B, hepatitis C, tuberculosis.
- **Pre-existing** — diabetes mellitus, epilepsy, kidney disease, autoimmune disease, blood
  disorder, gynaecological cancer.

Malaria is not among them: the DAK carries prophylaxis and counselling for it but defines no
malaria diagnosis element, so there is nothing to record a condition from.

**Intimate partner violence is deliberately not a registry condition.** The DAK gives it a business
process of its own (`ANC.B10.8` first-line support) and Annex A's own cover sheet warns that these
items belong in a system only where there is support available for the woman. A registry condition
is persistent and visible on her record to everyone with access to the registry, which is exactly
the wrong property for this. It stays where the DAK puts it — asked, and acted on, within a
contact.

Number of fetuses and fetal presentation are likewise not conditions: they are per-contact findings
that change through the pregnancy.

### Condition categories

**These four are deliberately not prefixed.** Tamanu hard-loads four categories into every registry
(`unknown`, `disproven`, `resolved`, `recordedInError`) and merges any spreadsheet rows over them.
The four hardcoded ones alone cannot express a condition that has been *confirmed*, so the spec
adds the standard clinical progression: `suspected`, `underInvestigation`, `confirmed`,
`inRemission`. Tamanu's UI already carries labels for exactly those codes, so prefixing them would
turn four recognised categories into four unrecognised ones — the codes have to match. They are
scoped per registry anyway (the id is
`program-registry-condition-category-<registryId>-<code>`), so there is nothing to collide with.
Drop the sheet if a deployment wants only the hardcoded four.

## The forms

**Nine surveys, one per DAK business process**, generated from Annex A — 152 questions plus 6
decision-support prompts over 17 screens. Screens are the DAK's own activities, and within an
activity the kit's own category dividers become section headings, which is the only structure a tab
like `ANC.B9` has: its ninety elements all sit under one activity.

| Survey | Code | Tab | Questions | Screens | Coded | Mandatory | Indicator-linked |
|---|---|---|---|---|---|---|---|
| ANC Registration | `registration` | `ANC.A` | 8 | 1 | 0 | 8 | 1 |
| Quick Check | `quickcheck` | `ANC.B4`–`B5` | 3 | 2 | 2 | 3 | 0 |
| Profile and History | `profile` | `ANC.B6` | 23 | 1 | 9 | 23 | 1 |
| Symptoms and Follow-up | `symptoms` | `ANC.B7` | 8 | 1 | 4 | 8 | 0 |
| Physical Examination | `physicalexam` | `ANC.B8` | 21 | 1 | 6 | 18 | 4 |
| Laboratory Tests and Imaging | `labtests` | `ANC.B9` | 28 | 1 | 1 | 28 | 5 |
| Counselling and Treatment | `counselling` | `ANC.B10` | 39 | 7 | 5 | 36 | 4 |
| ANC Referral | `referral` | `ANC.C` | 11 | 2 | 1 | 11 | 0 |
| ANC Episode Outcome | `episodeend` | `ANC.End` | 11 | 1 | 5 | 3 | 0 |

Survey ids are `program-whodakanc-<code>`. `ANC Referral` is Tamanu's `referral` survey type, so it
lands on the facility Referrals tab; the rest are `programs`. Survey names carry no `WHO DAK ANC`
prefix — they already sit under that program in the UI, and repeating it would only crowd the form
picker.

Annex A has **10** `ANC.*` tabs, not nine. The one that does not become a form is
**`ANC.Configuration`**: deployment constants rather than patient data — malaria and HIV prevalence
in the population, whether ultrasound and each laboratory test are available at this site. One
value per site, read by the decision logic. A survey is the wrong artefact; these belong in Tamanu
settings or a dbt seed.

Question codes carry the DAK data element id: `ANC.B9.DE34` → `whodakanc-b9-de34`, `ANC.End.1` →
`whodakanc-end-1`. Hyphens, because the importer allows only alphanumerics and `-` in an id and the
code is embedded in the `pde-<code>` id built from it. Labels, option strings and the mandatory flag
are Annex A's, verbatim — 152 of 152 verified against the dictionary on every build, with zero
label, option or mandatory mismatches; 33 coded questions carry 246 of Annex A's own options.
Each question also carries a `_dak` block in the spec
recording its data element id, activity, data type, why it was selected, and its Annex C indicator
links; that block is the crosswalk source and is not written to the workbook, which has no column
for it.

### The selection rule

Annex A's nine form-bearing tabs hold 351 parent elements. An element is carried when it is
`Required = R` or linked to an Annex C indicator. This kit publishes Annex A as its **core** data
dictionary, so unlike the HIV kit there is no second, narrower shortlist to consult — the shortlist
half of the rule is used for one tab only, `ANC.End`, where the first two rules select the closure
reason and drop the outcome. See [`dak-conformance.md`](dak-conformance.md).

### What is captured, and what is not

The deliberate divergences and the known gaps are in
[`dak-conformance.md`](dak-conformance.md). Three that matter most when reading the forms:

- **A danger sign recorded in both halves of `ANC.DT.01` raises two patient issues**, not just
  two prompts. The rule is split only because its thirteen signs overrun a varchar(255) column, and
  both halves carry the same `issueNote`, so the duplicate is visible on the patient record. Two
  issues on a danger sign is the right failure, but it is a failure rather than a design.
- **Conditional visibility is almost absent.** Annex A expresses conditionality as prose in
  `Skip logic` plus a `Required = C` flag, which does not translate mechanically into
  `visibilityCriteria`, so each form asks nearly every one of its questions every time. The
  exception is the four Annex B decision-support prompts, which are gated. Filling in the rest is
  the first thing to fix.
- **`ANC Registration` duplicates the Tamanu patient record.** First name, last name, address,
  mobile phone number and unique identification as survey questions are the anti-pattern Tamanu
  forms are meant to avoid: the patient record already holds them. Either drop this survey and keep
  only `ANC contact number`, or convert its demographic questions to `PatientData` reads. That is a
  deployment decision and is deliberately left open rather than guessed at.
- **Calculated elements are emitted as plain questions.** Annex A gives BMI (`ANC.B8.DE4`), weight
  gain (`DE15`, `DE16`), parity (`ANC.B6.DE23`), previous fetal loss (`DE32`) and preterm birth
  (`ANC.End.17`) a `Calculation` formula, which the generator does not read: they are ordinary
  questions a clinician types into. A deployment wanting them derived needs a `CalculatedQuestion`
  with a separator-free code of its own, since a math.js `calculation` parses `a-b` as subtraction.
- **The referral form asks for what Tamanu already knows.** `ANC.C.DE9`–`DE11` are the referring
  provider's name, cadre and facility, and Annex A's own `Calculation` for them reads "Same as
  end-user's profile". They are `Required = R`, so they are carried, but they should be
  `UserData` reads rather than free text.

## Before importing

Three decisions belong to the deployment, not to this repo, and are flagged rather than silently
chosen:

1. **`isSensitive` is `FALSE`.** These forms carry HIV status, intimate partner violence and
   pregnancy outcome. It is left off because turning it on changes who can read the responses,
   which is a deployment's call, not a template's.
2. **`currentlyAtType` is `facility`** and cannot be changed once the registry holds registrations.
   Decide before the first import.
3. **Nearly every question appears on every contact**, since the DAK's conditionality is prose that
   does not translate mechanically (above). A deployment using this in anger will want the
   `visibilityCriteria` filled in first — most of all on `Counselling and Treatment`, where 39
   questions cover eleven activities the DAK expects to be reached selectively.

A country adaptation that makes those choices differently is a new sibling directory with its own
prefix — not an edit to this one, which is meant to keep saying what the DAK says.

Then, in **central admin → Import → Programs**, upload `who-dak-anc_program.xlsx`. Requires
`create` and `write` permission on Program and Survey. The import is repeatable — it upserts by
code, so a corrected spec can be rebuilt and re-uploaded over the top.

Survey `status` is `publish`, so it imports onto a production server. A `draft` row is silently
skipped anywhere but dev, demo or staging, which is the usual reason a form "imports fine" and then
cannot be found.
