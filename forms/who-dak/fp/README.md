# WHO DAK family planning

Four Tamanu surveys and a program registry for a client's contraceptive care, generated from the
WHO DAK for family planning.

- [`domain.py`](domain.py) — everything specific to this DAK: its annexes, which tabs become
  which surveys, the elements the selection rule reaches for, the encodable decision rules, and
  the registry.
- `who-dak-fp_program.json` / `.xlsx` — the generated spec and the workbook that gets uploaded.
- [`dak-conformance.md`](dak-conformance.md) — what conforms to the DAK, what deliberately
  diverges, and what cannot be encoded in a form.

```bash
cd forms/who-dak
FORMS_SKILL=../../../claude-plugins/plugins/tamanu/skills/build-tamanu-forms/scripts
python dak_generator.py --domain fp
python $FORMS_SKILL/build_program_xlsx.py \
    --spec fp/who-dak-fp_program.json --out fp/who-dak-fp_program.xlsx
```

Everything carries a `who-dak-fp` prefix because codes are global upsert keys in Tamanu: a
deployment can hold this configuration and a national adaptation side by side without either
mutating the other's questions.

## Program and registry

Program `who-dak-fp` → id `program-whodakfp`, shown as **WHO DAK FP**. The importer puts the
program and survey codes through `idify` — `toLowerCase().replace(/\W/g, '')` — so the hyphens
survive in the *code* but are stripped from the *id*. Registry, clinical-status and condition ids
are not idified, so those keep theirs.
Registry `who-dak-fp` → id `programRegistry-who-dak-fp`, also named **WHO DAK FP** — a registry
name has to be unique among current registries.

**The registry is a client's family planning care, and it has no natural end.** That is the one
structural difference from this repo's other DAK registries: a pregnancy episode closes at
delivery and a postnatal episode closes at six weeks, but contraceptive care is a relationship
that runs for as long as the client wants a method. The registry therefore tracks *where the
client stands* rather than how far through an episode they are.

| Registry setting | Value | Why |
|---|---|---|
| `currentlyAtType` | `facility` | The kit delivers its services from a facility, and `FP.B14` asks which one can provide the method. **This cannot be changed once the registry holds registrations** — switch it to `village` before first import where pills and condoms are distributed by community outreach, which is common. |
| `lossToFollowUpEnabled` | `true` | A resupply not collected is what discontinuation looks like in the data, and Annex C devotes two of its eight indicators (`FP.IND.5` discontinuation, `FP.IND.4` switching) to it. Tamanu auto-creates a `who-dak-fp-pltfu` "Potential loss to follow up" clinical status when this is on — it is not in the spec, and does not need to be. |
| `lossToFollowUpThresholdDays` | `119` | The widest routine resupply window in Annex B's own `FP.S.1` schedule: an injectable expires at service provision + 119 days, against 92 for pills, the patch and the rings. Tamanu's default of 90 days would flag every DMPA client while they are still inside the interval the kit gives them. |

The threshold is a registry-wide setting, so it cannot follow the method: a client on an implant
or an IUD needs no contact for three to five years, and a sterilised client needs none ever, yet
both are flagged at 119 days along with everyone else. `Permanent method` exists as a clinical
status partly to make that visible; a deployment that finds the noise unhelpful on long-acting
methods should turn the flag off rather than lengthen the threshold, which would stop it firing
for the injectable and pill clients it is for.

### Clinical statuses

Where this client's family planning care stands. The kit defines no closing element of its own —
unlike the ANC kit, which ends its record with `ANC.End.1 Reason for closing ANC record` — so
these are the states its care pathway distinguishes rather than a list the DAK supplies.

| Code | Name | Colour |
|---|---|---|
| `who-dak-fp-using-method` | Using a method | green |
| `who-dak-fp-permanent-method` | Permanent method | blue |
| `who-dak-fp-awaiting-method` | Awaiting method or procedure | yellow |
| `who-dak-fp-no-method` | No method - unmet need | orange |
| `who-dak-fp-referred` | Referred | teal |
| `who-dak-fp-seeking-pregnancy` | Stopped - seeking pregnancy | pink |
| `who-dak-fp-stopped` | Stopped contraception | brown |
| `who-dak-fp-lost-to-follow-up` | Lost to follow-up | red |
| `who-dak-fp-transferred-out` | Transferred out | grey |
| `who-dak-fp-pltfu` | Potential loss to follow up | grey *(auto-created)* |

Three of these distinguish states a single "not using a method" status would flatten, and the
distinction is the point of the register: **unmet need** is a client who wants to avoid pregnancy
and has no method, which is the service's failure; **awaiting method or procedure** is a client
the service turned away for a stock-out or a skill gap, which `FP.C.DE47` and `FP.C.DE54` record;
and **stopped — seeking pregnancy** is a client who no longer wants one, which is not a failure at
all. Counting all three as one number is how a stock-out disappears into a coverage statistic.

The prefix is load-bearing, not decorative: `prClinicalStatus-<code>` is a global id **and** the
status `code` column carries a database-level unique constraint, so an unprefixed `referred` would
collide with the next registry that wanted the word.

### Registry conditions

Twenty-six conditions, all prefixed `who-dak-fp-cond-`, each tracing to an option of
`FP.B.DE257 Health condition(s)` — the WHO medical eligibility criteria condition list, which is
what decides whether a client can use a given method.

The grouping is the kit's own. `FP.B.DE257` carries 154 options broken up by 21 heading
rows — *Diabetes*, *Hypertension*, *Cardiovascular disease*, *Liver disorders* — and those section
names are the condition classes below. That structure is also exactly what the form has to drop,
because Tamanu has no option-group construct: what the form flattens, the registry carries.

- **Cardiometabolic** — hypertension, cardiovascular disease, venous thromboembolism, diabetes
  mellitus.
- **Neurological and mental health** — migraine with aura, epilepsy, depressive disorders.
- **Systemic and organ** — systemic lupus erythematosus, anaemia, thyroid disorder, gall bladder
  disease, liver disorder, viral hepatitis, kidney disease.
- **Oncological and gynaecological** — breast cancer, cervical cancer, endometrial or ovarian
  cancer, gestational trophoblastic disease, uterine fibroids, pelvic inflammatory disease,
  unexplained vaginal bleeding.
- **Infection** — sexually transmitted infection, HIV, syphilis, tuberculosis, schistosomiasis.

**Eight are shared with the ANC or PNC registry by design** — hypertension, diabetes, anaemia,
HIV, tuberculosis, syphilis, epilepsy and kidney disease. The same client carries them between
services, and seven are named identically so a deployment reading more than one sees one condition
rather than several. Diabetes is the exception: the ANC registry splits it into `Diabetes mellitus
(pre-existing)` and a gestational form, a distinction a family planning contact does not make.

Transient findings are deliberately excluded: `Vaginitis`, `Urinary tract infection`, `Local
infection` and the surgical-site options are what a single contact observed rather than what the
client is carrying, and the kit's `Conditions relevant to sterilization and FAB` group is a
procedural relevance bucket rather than a condition at all.

`Migraine with aura` looks oddly specific beside the rest, and is not: it is the one headache
type that makes combined hormonal contraception a category 4 — an unacceptable health risk —
where migraine without aura does not. A registry that recorded only "migraine" could not answer
the question the client's method choice turns on.

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

**Four surveys, one per business process**, generated from the data dictionary — 78 questions plus
8 guidance prompts and 3 patient issues over 24 screens.

| Survey | Code | Tab | Questions | Screens | Coded | Mandatory |
|---|---|---|---|---|---|---|
| FP Registration | `registration` | `FP.A. Registration` | 9 | 1 | 1 | 9 |
| FP Counselling | `counselling` | `FP.B. Counselling` | 40 | 13 | 16 | 17 |
| FP Service Provision | `serviceprovision` | `FP.C. Service provision` | 19 | 8 | 5 | 5 |
| FP Referral | `referral` | `FP.D. Referral` | 10 | 2 | 1 | 10 |

Survey ids are `program-whodakfp-<code>`. `FP Referral` is Tamanu's `referral` survey type, so it
lands on the facility Referrals tab; the rest are `programs`.

**This kit has no configuration tab.** All four of its `FP.*` tabs define patient encounter data
and all four become forms, where the ANC and PNC kits each hold back a tab of site constants.

Question codes carry the data element id: `FP.B.DE257` → `whodakfp-b-de257`. Labels, option
strings and the mandatory flag are the dictionary's, verbatim — 77 of 77 numbered data-element
questions verified on every build, with zero label, option or mandatory mismatches. 23 coded
questions carry 426 of the kit's own options.

One question has no DAK id at all, because the dictionary never gave it one: `Current medications`
is `Required = R`, owns fourteen option rows, and sits in the id space between `FP.B.DE241` and
`FP.B.DE242` without a number. Its code is built from its activity and label —
`whodakfp-b11-4-current-medications` — and its `_dak.dataElementId` is left blank rather than
filled with an invented id. See [`dak-conformance.md`](dak-conformance.md).

### The selection rule

An element is carried when it is `Required = R`, feeds an indicator, or is named in the domain's
shortlist. **This kit needs the shortlist far more than the others do.** It marks only 41 of its
121 elements `Required = R` and links just three to an Annex C indicator, so the first two rules
alone leave `FP.C. Service provision` with five questions and no pregnancy checklist — a form that
records a hormonal method being given with no record that pregnancy was excluded first.

The shortlist adds 36 elements across the two clinical tabs, and every one is an input to an
encoded Annex B rule, an element an Annex C calculation names, or a branch the care pathway turns
on. See [`dak-conformance.md`](dak-conformance.md).

### What is captured, and what is not

Three things that matter most when reading the forms; the rest is in
[`dak-conformance.md`](dak-conformance.md):

- **The medical eligibility criteria are not evaluated.** Twelve of the kit's 28 decision tables
  are the MEC wheel — a condition-by-method matrix returning category 1 to 4 per method — and a
  Tamanu form cannot compute it. The forms collect its two inputs, `Health condition(s)` and
  `Current medications`, and leave the judgement with the clinician, which is why the registry
  carries the condition list.
- **`Health condition(s)` is one question with 154 options.** The kit groups them under 21
  headings and Tamanu has no option-group construct, so they land as one flat list. The headings
  are not lost — they are the registry's condition classes above.
- **Conditional visibility is almost absent.** The dictionary expresses conditionality as prose in
  `Skip Logic` plus a `Required = C` flag, which does not translate mechanically into
  `visibilityCriteria`, so each form asks nearly every one of its questions every time. The eleven
  Annex B prompts are the only gated content — this kit's selection carries no "Other (specify)"
  free-text box for the gate that would otherwise apply to one.

## Before importing

Four decisions belong to the deployment, not to this repo:

1. **`isSensitive` is `FALSE`.** These forms carry HIV status, sexual history, STI risk factors and
   a client's reasons for not using contraception. Turning it on changes who can read the
   responses, which is a deployment's call — and contraceptive use is information clients are
   harmed by having disclosed.
2. **`currentlyAtType` is `facility`** and cannot be changed once the registry holds registrations.
   Community distribution of pills and condoms is common; decide before the first import.
3. **`Current medications` imports as a mandatory single-select.** The dictionary types it `Coding`
   but never says whether more than one answer is allowed, and the generator does not guess. A
   client on antiretrovirals *and* rifampicin cannot record both, and both change their medical
   eligibility, so a deployment using this in anger should switch it to `MultiSelect` first.
4. **Nearly every question appears at every contact**, since the kit's conditionality is prose that
   does not translate mechanically. A deployment using this in anger will want the
   `visibilityCriteria` filled in first — most of all on `FP.C`, where the pregnancy checklist and
   the pregnancy test are alternatives rather than a sequence.

A country adaptation that makes those choices differently is a new sibling directory with its own
prefix — not an edit to this one, which is meant to keep saying what the DAK says.

Then, in **central admin → Import → Programs**, upload `who-dak-fp_program.xlsx`. Requires
`create` and `write` permission on Program and Survey. The import is repeatable — it upserts by
code, so a corrected spec can be rebuilt and re-uploaded over the top.

Survey `status` is `publish`, so it imports onto a production server. A `draft` row is silently
skipped anywhere but dev, demo or staging, which is the usual reason a form "imports fine" and then
cannot be found.

### One heading needs retiring on a server that imported an earlier workbook

The `FP Counselling` activity heading for `FP.B2` is coded `whodakfp-counselling-act-b2`. A server
that imported a workbook built before that code was corrected holds it as
`whodakfp-counselling-act-b2-take`, and the importer upserts by code rather than sweeping rows the
sheet no longer names — so importing over the top leaves both, and the form shows the heading
twice.

Nothing is at risk: a heading is an `Instruction` and stores no answers. To clear the old one, add
a row to the `FP Counselling` sheet with `code` `whodakfp-counselling-act-b2-take`, `type`
`Instruction` and `visibilityStatus` `historical`, and import once. That soft-deletes the survey
screen component; its `pde-` row stays behind, which nothing renders and nothing points at. A
server that has never imported this program needs none of this.
