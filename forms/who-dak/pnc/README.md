# WHO DAK PNC

The **maternal half** of the WHO DAK postnatal care kit: ten Tamanu surveys and a program registry
for the woman's postnatal episode. Its sibling [`../pnc-newborn/`](../pnc-newborn/README.md) is the
newborn's half, and the two read the same dictionary.

- [`domain.py`](domain.py) — everything specific to this DAK: its components, which tabs become
  which surveys, the elements the selection rule reaches for, the encodable decision rules, and the
  registry.
- `who-dak-pnc_program.json` / `.xlsx` — the generated spec and the workbook that gets uploaded.
- [`dak-conformance.md`](dak-conformance.md) — what conforms to the DAK, what deliberately
  diverges, and what cannot be encoded in a form.

```bash
cd forms/who-dak
FORMS_SKILL=../../../claude-plugins/plugins/tamanu/skills/build-tamanu-forms/scripts
python dak_generator.py --domain pnc
python $FORMS_SKILL/build_program_xlsx.py \
    --spec pnc/who-dak-pnc_program.json --out pnc/who-dak-pnc_program.xlsx
```

**This kit is not published as IRIS Web Annexes.** WHO ships it as an implementation-guide site,
and its four components are downloads from that site. `domain.py` records their URLs and the data
dictionary's checksum; see [`dak-conformance.md`](dak-conformance.md) § Fetching the components.

Everything carries a `who-dak-pnc` prefix because codes are global upsert keys in Tamanu: a
deployment can hold this configuration and a national adaptation side by side without either
mutating the other's questions.

## Two subjects, two programs

The kit assesses **two patients at every contact** — the woman and the newborn — and splits every
assessment tab accordingly, `a` for maternal and `b` for neonatal. A Tamanu survey submits against
one patient and a program carries one registry, so the two halves are **two programs**: this one and
[`../pnc-newborn/`](../pnc-newborn/README.md).

Reception is the exception: `PNC.A Registration` records the newborn's danger signs on the woman's
contact, because that is how the kit models arrival. Those answers attach to her submission — see
the newborn domain for what to do if they need to attach to the newborn's.

Linking mother and baby as Tamanu patients is a deployment concern this configuration does not
attempt.

## Program and registry

Program `who-dak-pnc` → id `program-whodakpnc`, shown as **WHO DAK PNC**. The importer puts the
program and survey codes through `idify` — `toLowerCase().replace(/\W/g, '')` — so the hyphens
survive in the *code* but are stripped from the *id*. Registry, clinical-status and condition ids
are not idified, so those keep theirs.
Registry `who-dak-pnc` → id `programRegistry-who-dak-pnc`, also named **WHO DAK PNC** — a registry
name has to be unique among current registries.

**The registry is the woman's postnatal episode.** The newborn has one of its own, in
[`../pnc-newborn/`](../pnc-newborn/README.md): a program carries one registry, so two subjects need
two programs. Import both.

| Registry setting | Value | Why |
|---|---|---|
| `currentlyAtType` | `facility` | PNC contacts are delivered from a facility, and the retention question is which one she is attending. **This cannot be changed once the registry holds registrations** — switch it to `village` before first import where postnatal contacts are made by community outreach, which is common. |
| `lossToFollowUpEnabled` | `true` | A missed contact is the measure the postnatal period turns on: WHO schedules contacts at 24 hours, day 3, day 7–14 and six weeks, and the deaths this care exists to prevent cluster in the first days. Tamanu auto-creates a `who-dak-pnc-pltfu` "Potential loss to follow up" clinical status when this is on — it is not in the spec, and does not need to be. |
| `lossToFollowUpThresholdDays` | `28` | Four weeks, the widest gap in that schedule (day 14 to six weeks). Tamanu's default of 90 days is longer than the entire postnatal period, so it would never fire before the episode had already ended. |

### Clinical statuses

One status per woman: where this postnatal episode stands. The kit defines no closing element of
its own — unlike the ANC kit, which ends its record with `ANC.End.1 Reason for closing ANC record`
— so these are the states its care pathway distinguishes rather than a list the DAK supplies.

| Code | Name | Colour |
|---|---|---|
| `who-dak-pnc-attending` | Attending PNC | green |
| `who-dak-pnc-referred` | Referred | orange |
| `who-dak-pnc-completed` | PNC completed | blue |
| `who-dak-pnc-lost-to-follow-up` | Lost to follow-up | red |
| `who-dak-pnc-transferred-out` | Transferred out | teal |
| `who-dak-pnc-died` | Woman died | purple |
| `who-dak-pnc-pltfu` | Potential loss to follow up | grey *(auto-created)* |

`Referred` is a status here where the ANC registry has none, because this kit gives referral two
business processes of its own (`PNC.B7` non-emergency, `PNC.C1` emergency) and a referred woman is
still the service's to account for. It does not end the episode.

The prefix is load-bearing, not decorative: `prClinicalStatus-<code>` is a global id **and** the
status `code` column carries a database-level unique constraint, so an unprefixed `completed` would
collide with the next registry that wanted the word.

### Registry conditions

Sixteen conditions, all prefixed `who-dak-pnc-cond-`, each tracing to a `PNC.B6a` suggested
diagnosis — the diagnoses the kit's own decision logic concludes about the woman:

- **Hypertensive** — hypertension, severe hypertension, pre-eclampsia, severe pre-eclampsia.
- **Infection** — postpartum infection, uterine infection, perineal infection, caesarean-section
  wound infection, respiratory tract infection.
- **Carried from before or across episodes** — anaemia, HIV, tuberculosis, syphilis.
- **Other postnatal** — postpartum bleeding, postnatal depression or anxiety, risk of
  alloimmunization.

**Six are shared with the ANC registry by design** — hypertension, pre-eclampsia, anaemia, HIV,
tuberculosis and syphilis. The same woman carries them out of pregnancy and into the postnatal
period, and the two registries name them identically so a deployment reading both sees one
condition rather than two.

Transient findings are deliberately excluded: fever, low oximetry, abnormal pulse rate and the
`Abnormal <site> exam` diagnoses are what a single contact observed, not what the woman is
carrying, and belong on the contact's form where the kit puts them.

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

**Ten surveys, one per maternal business process**, generated from the data dictionary — 110
questions plus 8 decision-support prompts over 13 screens. The five neonatal tabs are in
[`../pnc-newborn/`](../pnc-newborn/README.md).

| Survey | Code | Tab | Questions | Screens | Coded | Mandatory |
|---|---|---|---|---|---|---|
| PNC Registration | `registration` | `PNC.A` | 10 | 1 | 6 | 3 |
| Maternal Profile and Health History | `profile` | `PNC.B1` | 14 | 1 | 13 | 14 |
| Pregnancy, Labour and Birth Information | `birthinfo` | `PNC.B2` | 23 | 2 | 16 | 22 |
| Maternal Symptoms and Wellbeing | `matsymptoms` | `PNC.B3a` | 8 | 1 | 8 | 8 |
| Maternal Physical Examination | `matexam` | `PNC.B4a` | 18 | 1 | 12 | 17 |
| Maternal Care and Treatment | `mattreatment` | `PNC.B6a` | 2 | 2 | 0 | 2 |
| PNC Referral | `referral` | `PNC.B7` | 6 | 1 | 0 | 6 |
| PNC Emergency Referral | `emergencyreferral` | `PNC.C1` | 4 | 1 | 0 | 4 |
| Maternal Symptoms and Wellbeing (follow-up) | `fumatsymptoms` | `PNC.D3a` | 8 | 2 | 8 | 8 |
| Maternal Physical Examination (follow-up) | `fumatexam` | `PNC.D4a` | 17 | 1 | 12 | 17 |

Survey ids are `program-whodakpnc-<code>`. The two referral surveys are Tamanu's `referral` survey
type, so they land on the facility Referrals tab; the rest are `programs`.

The kit has **16** `PNC.*` tabs: ten maternal ones become the forms above, five neonatal ones become
the forms in [`../pnc-newborn/`](../pnc-newborn/README.md), and one, **`PNC Configuration`**, becomes
no form at all — site constants rather than patient data, population prevalence of gestational
diabetes, of HIV and of schistosomiasis, and which services this site offers. One value per site,
read by the decision logic; settings or a dbt seed, not a survey.

Question codes carry the data element id: `PNC.B1.DE.1` → `whodakpnc-b1-de-1`. Labels, option
strings and the mandatory flag are the dictionary's, verbatim — 106 of 106 data-element questions
verified on every build, with zero label, option or mandatory mismatches; the remaining four are the
`PNC.A2.DT.01` / `PNC.A2.DT.12` decision-support issues below. 75 coded questions carry 519 of the
kit's own options.

### The selection rule

An element is carried when it is `Required = R`, feeds an indicator, or is named in the domain's
shortlist. This kit marks 206 elements Required, so the shortlist is used on two tabs only — every
danger-sign element in the kit is `Required = C`, and without them the registration form would ask
why the woman came and nothing else. See [`dak-conformance.md`](dak-conformance.md).

### What is captured, and what is not

Three things that matter most when reading the forms; the rest is in
[`dak-conformance.md`](dak-conformance.md):

- **The kit's 109 suggested diagnoses are not on the forms.** `PNC.B6a` and `PNC.B6b` state them
  as data elements typed `Annotation` — a diagnosis the decision logic concludes plus the guidance
  that goes with it, where the HIV and ANC kits put their rules in a separate decision-support
  annexe. A form can prompt but not conclude, and there is no answer to store, so they are not
  carried. They are instead the source of this registry's condition list.
- **Conditional visibility is almost absent.** The dictionary expresses conditionality as prose in
  `Explain Conditionality` plus a `Required = C` flag, which does not translate mechanically into
  `visibilityCriteria`, so each form asks nearly every one of its questions every time. The eight
  danger-sign prompts are the only gated content.
- **Each assessment appears twice**, once for the first contact (`PNC.B3a`, `PNC.B4a` …) and once
  for a follow-up (`PNC.D3a`, `PNC.D4a` …), with different data element ids. That is the
  dictionary's own structure, reproduced rather than improved on.

## Before importing

Four decisions belong to the deployment, not to this repo:

1. **`isSensitive` is `FALSE`.** These forms carry HIV status, mental-health screening and
   pregnancy outcome. Turning it on changes who can read the responses, which is a deployment's
   call.
2. **`currentlyAtType` is `facility`** and cannot be changed once the registry holds registrations.
   Postnatal contacts are frequently made in the community; decide before the first import.
3. **Import the newborn workbook too.** A deployment running only this half has no newborn record
   at all — see [`../pnc-newborn/`](../pnc-newborn/README.md).
4. **Nearly every question appears at every contact**, since the kit's conditionality is prose that
   does not translate mechanically. A deployment using this in anger will want the
   `visibilityCriteria` filled in first.

A country adaptation that makes those choices differently is a new sibling directory with its own
prefix — not an edit to this one, which is meant to keep saying what the DAK says.

Then, in **central admin → Import → Programs**, upload `who-dak-pnc_program.xlsx`. Requires
`create` and `write` permission on Program and Survey. The import is repeatable — it upserts by
code, so a corrected spec can be rebuilt and re-uploaded over the top.

Survey `status` is `publish`, so it imports onto a production server. A `draft` row is silently
skipped anywhere but dev, demo or staging, which is the usual reason a form "imports fine" and then
cannot be found.
