{% docs metric__who_dak_hiv_indicators %}
D5 metric view for the WHO SMART guidelines HIV Digital Adaptation Kit indicators registered in
documentations/metrics/who_dak_hiv.yml. One row per qualifying subject per reporting month.

Web Annex C of the DAK defines 140 indicators. Sixteen counts are here, covering nine of them:
those computable from the DAK's own data elements as the generated `who-dak-hiv` forms collect
them. Each is a **count**,
and a rate is formed from a numerator and its denominator — HIV positivity is
`who_dak_hiv_hts_client_positive` over `who_dak_hiv_hts_client_tested`, viral suppression is
`who_dak_hiv_art_viral_suppression` over `who_dak_hiv_art_routine_viral_load` — at whatever
grain the consumer groups to. Annex C's `Ref no.` is on each registry row, so an indicator here
maps to the GAM, Global Fund and PEPFAR MER lines those crosswalk sheets define.

| Ref | Indicator | Numerator metric | Denominator metric |
|---|---|---|---|
| HTS.2 | Test volume and positivity | `who_dak_hiv_hts_test_positive` | `who_dak_hiv_hts_test` |
| HTS.3 | Individuals testing positive | `who_dak_hiv_hts_client_positive` | `who_dak_hiv_hts_client_tested` |
| ART.3 | Viral suppression | `who_dak_hiv_art_viral_suppression` | `who_dak_hiv_art_routine_viral_load` |
| ART.4 | New ART patients | `who_dak_hiv_art_initiated` | — a count |
| ART.5 | Late ART initiation | `who_dak_hiv_art_late_initiation` | `who_dak_hiv_art_cd4_at_initiation` |
| DSD.3 | DSD ART coverage | `who_dak_hiv_dsd_enrolled` | `who_dak_hiv_dsd_eligible` |
| ART.1 | People living with HIV on ART | `who_dak_hiv_art_on_art` | an external population estimate |
| ART.1 | …by key population | `who_dak_hiv_art_on_art_key_population` | — |
| ART.9 | ARV toxicity prevalence | `who_dak_hiv_art_toxicity` | `who_dak_hiv_art_on_art` |
| DSD.4 | Retention in DSD ART models | `who_dak_hiv_dsd_retained` | `who_dak_hiv_dsd_retention_eligible` |

**Monthly, per subject.** Annex C counts *clients* in a reporting period, so the period is the
month and a client qualifying twice in one month contributes one row — unlike the
encounter-grained metrics, where every event is its own row. `subject_grain` says which unit the
row counts: `patient` for all but HTS.2, where Annex C counts tests.

**The forms are the source, and that is a real limit.** These indicators read survey answers,
so an indicator is only as complete as the form filling behind it: a client on ART whose care
visit was never submitted is not in `who_dak_hiv_art_initiated`. Nothing here reconstructs
state from elsewhere in Tamanu — the enrolment view of the same programme is
`metric__program_registry_enrolment`, over the program registry rather than the forms.

**Point-in-time and event-anchored indicators sit side by side.** `ART.4` counts an initiation
in the month it happened; `ART.1` counts everyone whose last recorded state is on ART at the
month end, whether or not they were seen. The second reads
`int__who_dak_hiv_client_month_state`, which carries each attribute forward from the last form
that recorded it — so a visit noting a viral load does not blank a DSD enrolment it never
mentioned.

**What is not here, and why.** Of Annex C's 140, 49 declare no numerator computable from DAK
data at all ("Not included in DAK" — survey-based, stock data, another system). Annex C's
population denominators (`ART.1` treatment coverage over estimated PLHIV) come from outside
Tamanu, so the count is emitted and the rate is not. The rest of the covered indicators are a
backlog rather than an obstacle: `tupaia-data-product`'s `annex_c_coverage.py` reports which of
them the forms can compute, and each is a predicate over the same two intermediates.
{% enddocs %}

{% docs metric__who_dak_hiv_indicators__subject_grain %}
Which unit the row counts: `patient` for a client-count indicator, `test` for HTS.2, where
Annex C counts tests rather than people.

It is emitted so a consumer cannot mistake one for the other. Summing `value_numeric` over a
`test`-grained indicator counts tests, including two for a client tested twice in a month;
summing over a `patient`-grained one counts people.
{% enddocs %}

{% docs metric__who_dak_hiv_indicators__period_start %}
First day of the reporting month the subject is counted in.

Which date places a subject in a month is the Annex C element for that indicator: the date
results were returned for HTS.2, the ART start date for ART.4, the viral load sample date for
ART.3. So a form submitted late still counts in the month the event happened.
{% enddocs %}

{% docs metric__who_dak_hiv_indicators__period_end %}
Last day of the reporting month — the period this row's count belongs to, closed.
{% enddocs %}

{% docs metric__who_dak_hiv_indicators__value_numeric %}
Always 1: one subject per row. Summing it gives the indicator's count for whatever grouping the
consumer applies.
{% enddocs %}

{% docs metric__who_dak_hiv_indicators__facility_id %}
Facility of the submission that qualified the subject, from the encounter's location.

Where a client qualifies more than once in a month, the earliest qualifying event carries the
facility, so a client is attributed to where they were first counted rather than to an
arbitrary later visit.
{% enddocs %}

{% docs metric__who_dak_hiv_indicators__age_years %}
Age in whole years at the qualifying event.

Not banded. Annex C disaggregates by age, but which bands depends on what is being reported to
— GAM, PEPFAR MER and a national HMIS differ, and the DAK's own 0-14/15+ split differs again —
so the metric emits the number and the consumer's data table bands it.
{% enddocs %}

{% docs who_dak_hiv__variant_id %}
NULL -- the standard WHO definition, with no deployment-specific variant. A deployment that
reports a locally adapted version of an indicator registers a variant_of row and sets this.
{% enddocs %}

{% docs who_dak_hiv__subject_id %}
The subject counted, per `subject_grain`: the patient id on a client-count indicator, the
survey response id on HTS.2, where Annex C counts tests.
{% enddocs %}

{% docs who_dak_hiv__period_granularity %}
Constant 'month' -- Annex C's reporting period, and the grain a client is deduplicated within.
{% enddocs %}

{% docs who_dak_hiv__value_boolean %}
NULL -- unused by these indicators.
{% enddocs %}

{% docs who_dak_hiv__metric_id %}
The registered indicator id, one of the eleven in documentations/metrics/who_dak_hiv.yml. Each
carries Annex C's own `Ref no.` in its registry row, so an id here resolves to a DAK indicator
and through it to the GAM, Global Fund and MER lines that reference it.
{% enddocs %}

{% docs metric__who_dak_hiv_indicators__months_on_dsd %}
Whole months between the client's DSD ART start date and the end of the reporting month.

Only the DSD.4 metrics carry it, and only from twelve months. Annex C reports that indicator at
12, 24, 36, 48 and 60 months, so the duration is emitted and the consumer selects the cohort --
five near-identical metrics would say the same thing five times and drift apart the first time
one of them changed.
{% enddocs %}

{% docs metric__who_dak_hiv_indicators__key_population %}
The DAK key population the row counts the client in — sex worker, person who injects drugs, and
so on, as the client's most recent form recorded it.

Only `who_dak_hiv_art_on_art_key_population` carries it. That metric's rows are
client-population pairs, because key population is a MultiSelect and a client can belong to
several: summing across populations therefore double-counts such a client, which is what Annex
C's own disaggregation does. The plain count of people is `who_dak_hiv_art_on_art`, and keeping
them as separate metrics is what stops one being mistaken for the other.
{% enddocs %}
