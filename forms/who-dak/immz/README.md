# WHO DAK immunization

Three Tamanu surveys and a program registry for a client's place in the immunisation schedule,
generated from the WHO DAK for immunizations.

- [`domain.py`](domain.py) — everything specific to this DAK: its components, which slices of the
  clinical tab become which surveys, the elements the selection rule reaches for, the encodable
  decision rules, and the registry.
- `who-dak-immz_program.json` / `.xlsx` — the generated spec and the workbook that gets uploaded.
- [`dak-conformance.md`](dak-conformance.md) — what conforms to the DAK, what deliberately
  diverges, and what cannot be encoded in a form.

```bash
cd forms/who-dak
FORMS_SKILL=../../../claude-plugins/plugins/tamanu/skills/build-tamanu-forms/scripts
python dak_generator.py --domain immz
python $FORMS_SKILL/build_program_xlsx.py \
    --spec immz/who-dak-immz_program.json --out immz/who-dak-immz_program.xlsx
```

Everything carries a `who-dak-immz` prefix because codes are global upsert keys in Tamanu: a
deployment can hold this configuration and a national adaptation side by side without either
mutating the other's questions.

## What this program is for

Tamanu already records administered doses. This program does not: it carries what Tamanu has no
construct for — the history and client characteristics an immunisation schedule is computed from,
the recommendation status and contraindications a health worker reaches at a contact, adverse
events, and a registry holding where the client stands against their schedule.

The boundary matters more here than in any other kit read so far, because the overlap is a dose
record, and two places to write a dose is worse than one place that is missing something. The
dose stays in the native vaccine module. See [`dak-conformance.md`](dak-conformance.md) § What the
native vaccine module keeps.

## Program and registry

| Registry setting | Value | Why |
|---|---|---|
| `currentlyAtType` | `facility` | Routine immunisation runs from a facility, and coverage is reported by the facility that administered the dose. **This cannot be changed once the registry holds registrations** — switch it to `village` before first import where the schedule is delivered by outreach, which is common for hard-to-reach populations. |
| `lossToFollowUpEnabled` | `false` | Tamanu's loss to follow-up is one threshold over the whole registration, and an immunisation schedule has no single interval: the routine gap runs from four weeks between primary-series doses to years between a toddler booster and an adolescent dose. Any single number marks a correctly scheduled child as lost. |
| `lossToFollowUpThresholdDays` | *(not set)* | The kit gives none to set it from. Most of its antigen schedules answer *"when does the service become overdue?"* with *"to be determined by Member States; however, there is no recommended overdue date"*, and the ones that do give a date anchor it to the client's date of birth or to their latest dose of that antigen. |

Being overdue is therefore a clinical status recorded against what the client is actually due
for, not a threshold Tamanu applies on its own. A deployment that wants automatic defaulter
tracing needs its own rule over the recorded schedule status and dose history — the `metric__`
layer, not this registry.

### Clinical statuses

| Code | Name | Colour |
|---|---|---|
| `who-dak-immz-up-to-date` | Up to date | green |
| `who-dak-immz-due` | Dose due | yellow |
| `who-dak-immz-overdue` | Dose overdue | orange |
| `who-dak-immz-complete` | Schedule complete | blue |
| `who-dak-immz-further-evaluation` | Further evaluation needed | teal |
| `who-dak-immz-contraindicated` | Contraindicated | brown |
| `who-dak-immz-refused` | Caregiver refusal | pink |
| `who-dak-immz-defaulted` | Defaulted | red |
| `who-dak-immz-transferred-out` | Transferred out | grey |
| `who-dak-immz-died` | Client died | purple |

The first five are the kit's own `IMMZ.D.DE156 Immunization recommendation status` values —
`Due`, `Not due`, `Completed`, `Contraindicated`, `Further evaluation needed` — read at the client
level rather than per antigen dose, with `Not due` becoming *Up to date* because that is what it
means of a whole schedule. *Dose overdue*, *Caregiver refusal*, *Defaulted*, *Transferred out* and
*Client died* are the pathway's: the kit has no element that closes a client's immunisation
record, and a registry needs somewhere for a client to stop.

*Caregiver refusal* is grounded in the kit even so — it is an option of `IMMZ.D.DE.5 Reason
vaccine was not administered`, and it is the one reason that describes a standing position rather
than a one-off deferral.

### Registry conditions

Fourteen, all prefixed `who-dak-immz-cond-`, each an option of `IMMZ.D.DE.161 Potential
contraindications`: immunocompromised, severely immunocompromised, exposed to immunosuppressive
treatment, severely immunosuppressed, immunodeficiency syndromes, altered immunocompetence,
history of anaphylactic reactions, severe allergic reactions, hypersensitivity to vaccine
components, symptomatic HIV infection, TB disease, spina bifida, bladder exstrophy, and prior
history of intussusception.

These are the contraindications the client carries between contacts, so the registry holds them
rather than each contact re-collecting them. The other eight options of the same element are not
registry conditions: pregnancy, planning pregnancy within the month, breastfeeding, receiving
blood products, severe acute illness, acute gastroenteritis, moderate to severe fever and taking
antibiotics defer today's dose rather than describing the client, and the form records them at
the contact where they apply.

## The forms

| Survey | Code | Activities | Questions | Screens | Coded | Mandatory |
|---|---|---|---|---|---|---|
| Immunization History and Risk Factors | `history` | `IMMZ.D1` | 31 | 1 | 14 | 4 |
| Immunization Status and Contraindications | `status` | `IMMZ.D2`, `IMMZ.D5`, `IMMZ.D7`, `IMMZ.D18` | 7 | 4 | 3 | 2 |
| Adverse Event Following Immunization | `aefi` | `IMMZ.D17` | 6 | 1 | 3 | 0 |

44 answerable questions, of which 41 carry a data element id and three are decision-support
patient issues. 124 option strings, all the kit's own.

### One tab, nine activities

Every other kit read here gives a business process its own Annex A tab. This one puts client
history, the schedule determination, contraindications, counselling, the dose record, adverse
events, the next visit and certificate issuance on a single `IMMZ.D Administer vaccine` tab, and
separates them only by activity id. A process in [`domain.py`](domain.py) therefore names the
`activities` it takes, and is a slice of a tab rather than the whole of it.

The kit also names two activities in one cell — `IMMZ.D1.Capture or update client history OR
IMMZ.D13.Update client record` — on the 48 rows either process records. Each slice takes
such a row under the half of the cell that named it, so one activity opens one screen.

### The vaccine library

`IMMZ.D.DE.19 Vaccine type` is mandatory, `Select all that apply`, and the element every coverage
indicator counts — and Annex A gives it no options at all. The kit publishes them as a tab of its
own, `IMMZ.Z Vaccine library`, whose 34 rows name one vaccine family each. Those labels are the
strings Annex B and Annex C quote (`"Vaccine type" = "BCG vaccines"`), so they are the only values
an indicator can ever match, and `OPTION_SOURCES` points the reader at them. Left alone, the
kit's central question would import as a free-text box.

### The selection rule

The shared rule is `Required = R`, or linked to an Annex C indicator, or named in the kit's core
shortlist. This kit leans on the shortlist harder than any but the TB kit, because it states every
client characteristic its decision tables read as `Required = C` — HIV status, ART status,
immunological stability, preterm birth, birth weight, TB infection test result, dengue
serostatus, and the antigen-specific dose types. The first two rules alone would carry a history
form that asks what was given without asking any of what governs what comes next.

Each entry in `CORE_ELEMENTS` is an input named by an Annex B antigen decision table, or an
element those tables' guidance turns on.

### What is captured, and what is not

- **The forms do not compute what a client is due for.** Annex B states its logic as 24 antigen
  decision tables, each reaching `Immunization recommendation status` from the client's age, the
  doses already counted and their immune status. Those inputs are date arithmetic over a dose
  history the form does not hold. The form collects the inputs, records the status the health
  worker reached, and shows the kit's own guidance for that status.
- **No dose is administered here.** Vaccine brand, manufacturer, batch, expiry, dose quantity and
  the administering health worker are the native vaccine module's, and `IMMZ.D13` is not a survey.
- **Conditional visibility is almost absent.** The dictionary expresses conditionality as prose in
  `Explain conditionality` plus a `Required = C` flag, which does not translate mechanically into
  `visibilityCriteria`, so each form asks nearly every one of its questions every time. The nine
  Annex B prompts and issues are the only gated content.
- **Stock, cold chain and certificates are out.** `IMMZ.I Report generation` is aggregate stock
  and coverage reporting, which belongs to the metric layer; `IMMZ.D20` and `IMMZ.D21` issue a
  verifiable digital certificate, which is a signing service rather than a question.

## Before importing

Three decisions belong to the deployment, not to this repo:

1. **The dose record stays in the native vaccine module.** This program assumes it. A deployment
   that instead wants the DAK's own dose fields has to decide which of the two is authoritative
   for coverage reporting before either is used, not after.
2. **`currentlyAtType` is `facility`** and cannot be changed once the registry holds
   registrations. Decide before the first import whether outreach sessions make `village` the
   right unit.
3. **`IMMZ.Z Vaccine library`'s 34 families are the value set, not a product list.** A deployment
   reporting by product needs its own mapping from the products it stocks to these families;
   changing the option strings breaks every Annex C indicator that compares against them.
