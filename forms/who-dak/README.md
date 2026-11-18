# WHO SMART guidelines Digital Adaptation Kits

Tamanu program forms generated from WHO's **Digital Adaptation Kits** — the operational
specification of a WHO guideline, published per health domain.

Grouped by standard rather than by domain because the *format* is the reusable part. A DAK's
annexes are the same four, whichever of them a given kit has published, so the generator reads the
format and each domain contributes only its own configuration:

```
who-dak/
  dak_generator.py            Annex A -> spec, Annex B -> guidance prompts
  annex_c_coverage.py         which Annex C indicators a domain's forms can compute
  hiv/
    domain.py                 this DAK's identity, processes, core elements, rules, registry
    dak-conformance.md        what conforms, what diverges, what cannot be encoded
    annexes/                  the four Web Annexes (gitignored, fetched)
    who-dak-hiv_program.json  the generated spec
    who-dak-hiv_program.xlsx  the workbook that gets uploaded
  anc/                        the same, for antenatal care
  pnc/                        and for postnatal care, the woman's half
  pnc-newborn/                the same kit's newborn half - one registry per program
  fp/                         and for family planning
  tb/                         and for tuberculosis, whose elements live on a shared tab
  immz/                       and for immunization, whose processes are slices of one tab
  che/                        and for child health, whose reportable output is not a column
  srv/                        and for infectious disease surveillance, whose tab is a disease
  bds/                        and for birth defects surveillance, whose value set nests
  smbp/                       and for self-monitoring of blood pressure, whose tab is an activity
```

| Domain | Kit | Forms | Registry |
|---|---|---|---|
| [`hiv/`](hiv/README.md) | Digital adaptation kit for HIV, second edition (2023) | 10 surveys, 259 questions | The HIV cascade |
| [`anc/`](anc/README.md) | Digital adaptation kit for antenatal care (2021) | 9 surveys, 152 questions | The pregnancy episode |
| [`pnc/`](pnc/README.md) | Digital adaptation kit for postnatal care (2025) | 10 surveys, 110 questions | The woman's postnatal episode |
| [`pnc-newborn/`](pnc-newborn/README.md) | The same kit's neonatal tabs | 5 surveys, 91 questions | The newborn's postnatal episode |
| [`fp/`](fp/README.md) | Digital adaptation kit for family planning (2021) | 4 surveys, 78 questions | A client's contraceptive care |
| [`tb/`](tb/README.md) | Digital adaptation kit for tuberculosis (2024) | 6 surveys, 165 questions | The TB episode |
| [`immz/`](immz/README.md) | Digital adaptation kit for immunizations (2025) | 3 surveys, 41 questions | A client's place in the schedule |
| [`che/`](che/README.md) | Digital adaptation kit for child health (0-59 months) in humanitarian emergencies (2024) | 13 surveys, 200 questions | A child's IMCI consultation |
| [`srv/`](srv/README.md) | Digital adaptation kit for infectious disease surveillance (2026) | 14 surveys, 104 questions | A notifiable-disease case |
| [`bds/`](bds/README.md) | Digital adaptation kit for birth defects surveillance (2025) | 3 surveys, 70 questions | A congenital anomaly case |
| [`smbp/`](smbp/README.md) | Digital adaptation kit for self-monitoring of blood pressure in pregnancy (2025) | 2 surveys, 42 questions | A client's self-monitoring episode |

Adding a domain — child health and development, whichever kit WHO releases next — is a sibling
directory with a `domain.py`, not a second script. What a kit costs is tolerance in the
reader: they agree on the *shape* of a data dictionary and on almost nothing else about it. The
ANC kit prefixes its id columns `[ANC] `, breaks a header across two lines, sentence-cases one
tab, writes `Multiple Choice` where the others write `Multiple Choice Type`, and puts the
selectable text in `Input Options` rather than in the option row's label.
The PNC kit writes `Input option` on 24 rows and `Input Option` on the rest, heads its sub-sections
with untyped rows that carry a `Required` flag, and states 109 of its decision rules as data
elements typed `Annotation`. The FP kit uses the same heading rows *inside* a single element's
option list, spreads one element over five rows to fit five ICD-11 codes on it, leaves a
`Required = R` element with no id at all, and writes prose in the `Required` column where a flag
belongs. Every kit but the HIV one breaks a tab into sections with heading rows.

The TB kit goes further and changes the shape rather than the spelling: it defines the 42 elements
more than one process collects on a shared `TB.Common` tab, and its process tabs reference them by
id, writing `Please check "TB.Common" tab for more data element details` where the type would go.
117 of its rows are such references. It also spells `Quantity subtype` where the others write
`Quantity sub-type`, and leaves three input options marked as nothing at all — no type, no `Input
Option`, which by rule is indistinguishable from a section heading, so those are the one thing the
reader cannot settle and a domain has to name.

The IMMZ kit changes the shape again, in the other direction: where every other kit gives a
business process its own tab, it gives nine activities to one, joins each activity id to its
label with a dot rather than a space, names two activities in one cell for the 48 rows either
process records, and publishes the value set of its most-counted element as a tab of its own
rather than as option rows beneath it.

The CHE kit is the one whose *reportable output* is not in the dictionary as an element. It leaves
the indicator column empty but for a single element and flags 32 of its 202 candidate elements, so
the two rules that select the other kits select 33 between them. What its 33 indicators count is
the IMCI classification, and it states each of its 72 classifications as a row of its own typed
`Derived`.
It puts three or four banner rows above each header, spells the `Required` legend four ways,
qualifies an option's mark in place — `Input option (for type of skin problem)` — or gives an
option the parent's own mark, writes every option cell as a bullet-list item, defines seven
clusters of questions on a group tab that its process tabs reference by id under three different
type spellings, and names one activity five ways on a single tab.

The SRV kit changes what a tab *is*. Every other kit gives a business process its own tab; this
one gives a **disease** its own tab — cholera, measles, bacterial meningitis, yellow fever — and
runs all five of its processes down each, carrying the process only in the activity id. A survey
is a slice of a disease tab taken by process, and the disease sits in the element id too, so this
is the one kit that strips no prefix at all: `CHOLSRV.C1.DE.12` and `MSLSRV.C1.DE.12` are
different elements and the prefix is what says so.

It also has neither of the two columns every other kit's options live in. The choice is stated in
the data type — `List - select one`, `List value` — and an option's string is its label. Its
`Optionality` is another kit's `Required`; fourteen of its columns end in an asterisk, one of them
the column every header row is found by; it gives the activity's id and its name a column each;
and it overloads `List to include this data element in` five ways, naming the parent wrongly on 13
of the 383 rows that use it. What it asks of a reader that the others do not is to tell three
grains apart on one tab: the case, the counts a surveillance unit reports upward, and the outbreak.
Only the first is a form.

The BDS kit changes what a *value set* is. Every other kit's coded element is one question and a
flat list of answers; this one states the congenital anomaly as a tree three levels deep — the
diagnosis offers ten body-system groups, `Central nervous system defects` offers `Encephalocele`,
and `Encephalocele` offers the eight sites — where each level is a row typed as a list and so is
both a question and one of the values of the question above it. It says which list each row
belongs to in the column the SRV kit overloads, and here that column is load-bearing rather than
advisory: in a nested set the row above an option is often a sibling list rather than its parent,
so `Microcephaly` follows the last spina bifida value and read positionally becomes an eleventh
kind of spina bifida. It also writes its two list types with an en dash where the SRV kit writes a
hyphen, heads one column `Activity ID and name`, and is the only kit using the `Signature` and
`Attachment` data types its own legend defines.

The SMBP kit is the counter-example, and a useful one: it added nothing. A single header row per
tab, the SRV kit's `Optionality` and its hyphenated list types, most kits' `Quantity sub-type` —
every spelling it uses already had a rule, so it is the first kit to be read without one being
written for it. What it changes is what a *tab* is, in the direction opposite to the IMMZ kit's:
each of its two tabs carries exactly one activity across every row, and heads no sections, so
there is no sub-structure to find and each survey is a single screen.

`dak_generator.py` absorbs each of those as a rule rather than a special case — a column matched on
its normalised header, a field naming every spelling it answers to, a heading recognised by having
no type at all. A new kit is expected to add to that list rather than fork the reader, and the
regression test is that the domains already built regenerate byte-identically.

| Annexe | What it is | Used for |
|---|---|---|
| **A** | Data dictionary | Generates the forms: labels, option strings, types, mandatory flags, terminology codes, indicator links |
| **B** | Decision-support logic | Conditional guidance prompts and patient warnings, where a form can express the rule |
| **C** | Indicators and performance metrics | Read by `annex_c_coverage.py`, where the kit writes its calculations in terms of quoted Annex A labels; the target for a `metric__` layer |
| **D** | Functional and non-functional requirements | Not encodable; a conformance checklist for the deployment |

## Building

```bash
cd forms/who-dak
FORMS_SKILL=../../../claude-plugins/plugins/tamanu/skills/build-tamanu-forms/scripts
python dak_generator.py --domain hiv
python $FORMS_SKILL/build_program_xlsx.py \
    --spec hiv/who-dak-hiv_program.json --out hiv/who-dak-hiv_program.xlsx
```

`--domain anc` or `--domain pnc` for the other kits, and so on for each directory holding a
`domain.py`.

Rendering the spec into a workbook is not this repo's job. The surveys, the registry sheets and
the importer's own validators are generic Tamanu concerns, and live in the `build-tamanu-forms`
skill — the `tamanu` plugin of the `bes` marketplace. Clone
[claude-plugins](https://github.com/beyondessential/claude-plugins) beside this repo. What stays
here is the DAK: Annex A in, spec out.

The annexes are not committed — third-party spreadsheets WHO serves at stable URLs, ignored via
`<domain>/annexes/`. Each `domain.py` records the URLs and the dictionary's checksum, and the
generator prints the fetch command when a file is absent:

```bash
mkdir -p forms/who-dak/hiv/annexes
curl -sL -o forms/who-dak/hiv/annexes/WHO-UCN-HHS-SIA-2023.27-eng.xlsx \
    https://iris.who.int/server/api/core/bitstreams/e9b0d20e-32ab-4d66-a5b6-638d39b0b443/content
```

Not every kit publishes annexes, though. The HIV, ANC and FP kits ship four numbered spreadsheets
as separate IRIS items; the PNC kit ships a PDF in IRIS and its four components as downloads from
WHO's SMART guidelines implementation-guide site, so its `ANNEXES` entries record a component page
and a version-pinned URL instead of an IRIS handle. Pin the version: the component page serves
whatever is current.

The BDS kit publishes no Annex B at all: `input/decision-logic/` at its released tag holds nothing
but the `.gitignore` that would have hidden the workbook, so its forms carry no guidance prompt and
its `DECISION_SUPPORT` is empty. The SMBP kit has the same gap one annexe over — its
`input/indicators/` holds only that `.gitignore` — so it records no `C` in `ANNEXES`, and
`annex_c_coverage.py` reports the kit as publishing none rather than failing on the missing entry.
A kit without Annex C also loses the second clause of the selection rule, so its core shortlist
carries what `Required = R` alone leaves out.

The TB kit is published the same way but without version-pinned download paths, so its `ANNEXES`
entries point at WHO's own source repository for the guide — `WorldHealthOrganization/smart-dak-tb`
— at the tag whose `sushi-config.yaml` declares the released version. Same publisher, released
bytes, and a URL that cannot move under the checksum. Pin the tag, never the branch: `main` is a
continuous integration build.

The ignore rule is scoped to `forms/who-dak/*/annexes/` rather than to `forms/who-dak/`, which
also holds the code. On a case-insensitive filesystem `forms/WHO-DAK/` and `forms/who-dak/` are
the same directory, so a rule on the latter silently swallows the generator on Windows while
tracking it on Linux.

## What a domain declares

`domain.py` is data, not code:

| | |
|---|---|
| `DAK` | The kit's title, and the prefix stripped from data element ids when deriving question codes |
| `ANNEXES` | Filename, IRIS handle and download URL per annexe; sha256 for Annex A |
| `PROGRAM` | Tamanu program name, code, and the prefix for question codes |
| `PROCESSES` | Which Annex A tab becomes which survey, its name and `surveyType`; and, for a kit that packs several processes onto one tab, the `activities` that survey takes |
| `CORE_TABS`, `CORE_ELEMENTS` | The kit's own core-elements shortlist, and which tabs it covers |
| `ELEMENT_TYPES` | Optional. A data type for an element the kit types inconsistently, read off its sibling rows rather than invented |
| `OPTION_SOURCES` | Optional. The tab holding an element's value set, for a kit that publishes it as a library rather than as option rows beneath the element |
| `GROUP_SOURCE` | Optional. The tab defining the clusters of questions a kit's process tabs reference by id, for a kit that defines a group once and names it from each process that collects it |
| `CLASSIFICATIONS` | Optional. The tab, data type and groups of a kit that states each value of an element as a row of its own, naming the question each group becomes |
| `OPTION_ROWS` | Optional. Ids of rows the kit marks as nothing at all that are input options of the question above them, which no rule can distinguish from a section heading |
| `OPTION_LABELS` | Optional. A replacement string for an option the kit labels with another option of the same question, read off that row's own code mapping rather than invented; two identical options collapse to one and lose an answer |
| `PATIENT_RECORD` | Optional. Ids the patient record already holds, so a kit that registers its own client does not give a deployment two places to write one fact |
| `ANNEX_C` | Optional. Where `annex_c_coverage.py` finds the indicators, for a kit that merges its header across rows and so has none to match on; `sheet` may name several, for a kit that splits them the way its dictionary is split |
| `DECISION_SUPPORT` | Annex B rules that a form can express, with the annexe's own guidance text |
| `REGISTRY` | The Tamanu program registry — **not** from the DAK, which has no registry concept |

The selection rule is shared: an element is carried when it is `Required = R`, or feeds an Annex C
indicator, or is named in the kit's core shortlist. The third exists because the first two alone
drop clinically central but unreported elements — the HIV kit publishes such a shortlist, and for
the ANC kit, whose Annex A *is* its core list, it carries the pregnancy outcome that `Required` and
the indicator links between them leave out. How much the shortlist has to do varies by kit rather
than by taste: the ANC kit needs it on one tab, the FP kit on two, because it marks only a third of
its elements `Required = R` and links three of them to an indicator, so the first two rules alone
drop its pregnancy checklist entirely.

## Where this sits

This is the collection side of the WHO DAK standard (maui-team architecture decision D12): a
Tamanu program-import workbook per domain, uploaded through central admin by a deployment that
opts into that domain. Its question codes are the DAK's own data element ids, which is what the
`metric__who_dak_*` models in this repo read to compute Annex C indicators. Nothing under `forms/`
is part of the dbt project.

The Tupaia dashboards over those metrics, each domain's standard product config and its data
tables, live in `tupaia-data-product`.
