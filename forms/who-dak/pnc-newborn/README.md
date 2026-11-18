# WHO DAK PNC (newborn)

The **newborn half** of the WHO DAK postnatal care kit: five Tamanu surveys and a program registry
for the newborn's postnatal episode. Its sibling [`../pnc/`](../pnc/README.md) is the woman's half,
and the two read the same dictionary.

There is no separate WHO DAK for newborn care. The newborn is defined inside the postnatal care
kit, on the tabs it suffixes `b`, and this domain is those tabs.

- [`domain.py`](domain.py) — which tabs become which surveys, the encodable decision rules, and the
  registry.
- `who-dak-pnc-newborn_program.json` / `.xlsx` — the generated spec and the workbook that gets
  uploaded.
- [`../pnc/dak-conformance.md`](../pnc/dak-conformance.md) — the conformance record covers both
  halves; it is one kit.

```bash
cd forms/who-dak
FORMS_SKILL=../../../claude-plugins/plugins/tamanu/skills/build-tamanu-forms/scripts
python dak_generator.py --domain pnc-newborn
python $FORMS_SKILL/build_program_xlsx.py \
    --spec pnc-newborn/who-dak-pnc-newborn_program.json \
    --out pnc-newborn/who-dak-pnc-newborn_program.xlsx
```

## Why this is a separate program

The kit assesses **two patients at every contact**. A Tamanu survey submits against one patient,
and a program carries **one** registry, so two subjects need two programs. Splitting only the
surveys would have left the newborn with forms and no registry — nowhere for *preterm*, *risk of
bacterial infection* or *very low weight* to live between contacts, which is the whole reason a
registry exists.

Question codes carry a distinct prefix, `whodakpncnb` rather than `whodakpnc`, so the same data
element becomes a distinct question in each program: `PNC.B4b.DE.1` is `whodakpncnb-b4b-de-1` here
and appears nowhere in the maternal program. Codes are global upsert keys, so one element cannot
belong to two programs' questions.

**Reception is shared and stays with the mother.** `PNC.A Registration` records the newborn's danger
signs (`PNC.A2.DE.74`) on the woman's contact, because that is how the kit models reception — one
arrival, both assessed. Those answers therefore attach to her submission, not the newborn's. A
deployment that needs them on the newborn's record should add a reception form to this program;
the newborn danger signs are asked again here on the physical examination, where they do attach to
the newborn.

## The registry

Registry `who-dak-pnc-newborn` → id `programRegistry-who-dak-pnc-newborn`, named **WHO DAK PNC
(newborn)**. Settings match the maternal registry — `currentlyAtType: facility`,
`lossToFollowUpEnabled: true`, `lossToFollowUpThresholdDays: 28` — because mother and newborn are
seen at one contact, so a service that has lost one has usually lost both.

### Clinical statuses

| Code | Name | Colour |
|---|---|---|
| `who-dak-pnc-newborn-in-care` | In postnatal care | green |
| `who-dak-pnc-newborn-referred` | Referred | orange |
| `who-dak-pnc-newborn-completed` | Postnatal care completed | blue |
| `who-dak-pnc-newborn-lost-to-follow-up` | Lost to follow-up | red |
| `who-dak-pnc-newborn-transferred-out` | Transferred out | teal |
| `who-dak-pnc-newborn-died` | Died | purple |
| `who-dak-pnc-newborn-pltfu` | Potential loss to follow up | grey *(auto-created)* |

Deliberately the same vocabulary as the maternal registry, so the two read side by side.

### Registry conditions

Sixteen conditions, all prefixed `who-dak-pnc-newborn-cond-`, each tracing to a `PNC.B6b` suggested
diagnosis:

- **Birth and growth** — preterm birth, small for gestational age, very low weight.
- **Infection and exposure** — risk of bacterial infection, umbilical cord infection, gonococcal
  eye infection, risk of congenital syphilis, risk of HIV transmission, risk of tuberculosis.
- **Congenital** — club foot, cleft lip or palate, congenital malformation (other), eye
  abnormality, suspected hearing impairment.
- **Other** — neonatal jaundice, possible serious illness.

Transient exam findings — the kit's `Abnormal <site> finding` diagnoses, mild hypothermia, sleeping
uncomfortably — are what one contact observed, not what the newborn is carrying, and stay on that
contact's form. The maternal registry follows the same rule.

**Risk of neglect (`PNC.B6b.DE.19`) is deliberately not a registry condition.** It is a safeguarding
flag rather than a clinical one, and a registry condition is persistent and visible to everyone with
registry access. Whether that flag should follow the child is a child-protection policy decision for
the deployment, not a default for a template to set — the same reasoning that keeps intimate partner
violence out of the ANC registry. Add it if the deployment's safeguarding policy calls for it.

### Condition categories

The same four added over Tamanu's hardcoded set, deliberately unprefixed — see
[`../pnc/README.md`](../pnc/README.md#condition-categories) for why.

## The forms

Five surveys, 91 questions plus 6 decision-support prompts over 7 screens.

| Survey | Code | Tab | Questions | Screens | Coded | Mandatory |
|---|---|---|---|---|---|---|
| Newborn Symptoms and Wellbeing | `nbsymptoms` | `PNC.B3b` | 17 | 2 | 16 | 17 |
| Newborn Physical Examination | `nbexam` | `PNC.B4b` | 33 | 1 | 24 | 30 |
| Newborn Care and Treatment | `nbtreatment` | `PNC.B6b` | 2 | 2 | 0 | 2 |
| Newborn Symptoms and Wellbeing (follow-up) | `funbsymptoms` | `PNC.D3b` | 12 | 1 | 12 | 12 |
| Newborn Physical Examination (follow-up) | `funbexam` | `PNC.D4b` | 27 | 1 | 21 | 27 |

Survey ids are `program-whodakpncnewborn-<code>`. 91 of 91 questions verified against the dictionary
on every build, with zero label, option or mandatory mismatches; 73 coded questions carry 354 of the
kit's own options.

`Newborn Care and Treatment` is two questions because its tab holds 57 `Annotation` rows — the kit's
suggested diagnoses, which a form cannot conclude — and almost nothing else. Those annotations are
the source of this registry's condition list.

## Before importing

Import **both** PNC workbooks: this one and [`../pnc/`](../pnc/README.md). They are two halves of
one kit, and a deployment running only the maternal half has no newborn record at all.

The same deployment decisions apply as for the maternal half — `isSensitive` is `FALSE`,
`currentlyAtType` is `facility` and cannot be changed once the registry holds registrations, and the
kit's conditionality is prose so nearly every question appears at every contact. See
[`../pnc/README.md`](../pnc/README.md#before-importing).

Then, in **central admin → Import → Programs**, upload
`who-dak-pnc-newborn_program.xlsx`. The import upserts by code, so it is repeatable.
