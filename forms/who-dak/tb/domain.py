"""The tuberculosis domain of the WHO DAK standard: everything specific to this DAK.

The format is shared — `../dak_generator.py` reads any DAK's data dictionary and decision-support
logic. What differs per domain is which tabs become which surveys, which elements are worth
carrying, which decision rules are encodable, and the registry, which is a Tamanu construct with
no DAK equivalent.

This kit's structural signature is a shared tab. Six process tabs define the elements each
activity collects, and a seventh, `TB.Common`, defines the 42 elements more than one process
collects — weight, HIV status, symptoms, sample type, every test result — once. A process tab
then references them by id, writing `Please check "TB.Common" tab for more data element details`
where the type would go. See `dak-conformance.md` § The shared tab.
"""

# --- the DAK's own identity --------------------------------------------------
# Digital adaptation kit for tuberculosis (2024), DAK version 1.0.1.
# Publication: https://www.who.int/publications/i/item/9789240086616
DAK = {
    "title": "Digital adaptation kit for tuberculosis (2024)",
    "elementPrefix": "TB.",  # stripped from data element ids when deriving question codes
}

# The kit's four components, fetched not committed (see ../../../.gitignore). The sha256 is the
# copy these artefacts were generated from, so a WHO revision announces itself rather than
# quietly changing a form.
#
# Like the PNC kit, this one is not published as IRIS Web Annexes: IRIS carries the PDF
# (handle 10665/376631) and WHO ships the four components through its SMART guidelines
# implementation guide at https://smart.who.int/dak-tb/. Unlike the PNC kit, the component pages
# there serve whatever the site last built, so `url` points at WHO's own source repository for
# the guide — `WorldHealthOrganization/smart-dak-tb` — at the `v1.0.1` tag, which is the tag
# whose `sushi-config.yaml` reads `version: 1.0.1` and `releaseLabel: release`. That is a
# version-pinned path to the released bytes, which the component page is not; `page` records the
# human-facing publication for each component.
ANNEXES = {
    "A": {
        "name": "core data dictionary",
        "filename": "TB DAK_core data dictionary.xlsx",
        "handle": "10665/376631",
        "page": "https://smart.who.int/dak-tb/dictionary.html",
        "url": (
            "https://raw.githubusercontent.com/WorldHealthOrganization/smart-dak-tb/v1.0.1/"
            "input/dictionary/TB%20DAK_core%20data%20dictionary.xlsx"
        ),
        "sha256": "cdb5dc0c8df53227f24b6f79aa1416452ebad6d93230b1470b6e48f0dde3dfa5",
    },
    "B": {
        "name": "decision-support logic",
        "filename": "TB DAK_decision-support logic.xlsx",
        "page": "https://smart.who.int/dak-tb/decision-logic.html",
        "url": (
            "https://raw.githubusercontent.com/WorldHealthOrganization/smart-dak-tb/v1.0.1/"
            "input/decision-logic/TB%20DAK_decision-support%20logic.xlsx"
        ),
        "sha256": "71041cedf87d73989a4b52a061b0d00cf67495569ac3a99c1d1ccf67a551fdc5",
    },
    "C": {
        "name": "indicators",
        "filename": "TB DAK_indicators.xlsx",
        "page": "https://smart.who.int/dak-tb/indicators.html",
        "url": (
            "https://raw.githubusercontent.com/WorldHealthOrganization/smart-dak-tb/v1.0.1/"
            "input/indicators/TB%20DAK_indicators.xlsx"
        ),
        "sha256": "30e15b52ca0b889c72e160157d9d3bf5dea080df9e11551a4cbe4f8838f5e8cb",
    },
    "D": {
        "name": "functional and non-functional requirements",
        "filename": "TB DAK_functional and non-functional requirements.xlsx",
        "page": "https://smart.who.int/dak-tb/system-requirements.html",
        "url": (
            "https://raw.githubusercontent.com/WorldHealthOrganization/smart-dak-tb/v1.0.1/"
            "input/system-requirements/"
            "TB%20DAK_functional%20and%20non-functional%20requirements.xlsx"
        ),
    },
}

# Where `../annex_c_coverage.py` finds this kit's indicators. Positions rather than header names:
# like the FP kit, this one splits its header across two rows — `Numerator` spans columns D and E
# on the first, `Description` and `Computation` name them on the second — so there is no single
# header row to match on. The sheet also carries a business-process divider row every few
# indicators, which the reader skips because those rows carry no id.
#
# `firstDataRow` is the spreadsheet's own row number; `columns` are zero-based offsets, so
# `id: 0` is column A. An off-by-one on `numerator` reads the prose Description column instead
# and every indicator then reports no quoted elements rather than failing.
ANNEX_C = {
    "sheet": "Indicator table",
    "firstDataRow": 4,
    "columns": {"id": 0, "name": 1, "numerator": 4, "denominator": 6},
}

# --- the Tamanu program -----------------------------------------------------
PROGRAM = {
    "programName": "WHO DAK TB",
    "programCode": "who-dak-tb",
    "codePrefix": "whodaktb",  # question codes: whodaktb-c24-de-1, whodaktb-screening-comm-de-3
}

# One survey per business process. `TB.Common` is not a process — it is where the other tabs'
# shared elements are defined, and the generator follows each reference into it — and
# `TB.Configuration` holds deployment constants (population prevalence of HIV and of TB, the
# national screening policy), which are settings or a dbt seed rather than questions a clinician
# answers.
#
# `TB.F.Referral` maps onto Tamanu's own `referral` survey type; the rest are `programs`.
PROCESSES = [
    {"tab": "TB.A.Registration", "code": "registration", "name": "TB Registration", "surveyType": "programs"},
    {"tab": "TB.B.Screening", "code": "screening", "name": "TB Screening", "surveyType": "programs"},
    {"tab": "TB.C.Diagnosis", "code": "diagnosis", "name": "TB Diagnosis", "surveyType": "programs"},
    {"tab": "TB.D.TB Treatment", "code": "treatment", "name": "TB Treatment", "surveyType": "programs"},
    {"tab": "TB.E.TPT", "code": "tpt", "name": "TB Preventive Treatment", "surveyType": "programs"},
    {"tab": "TB.F.Referral", "code": "referral", "name": "TB Referral", "surveyType": "referral"},
]

# Rows the dictionary marks as nothing at all — no data type, no `Input Option` — that are input
# options of the question above them rather than section headings. A bare row is
# indistinguishable from a heading by rule, so naming them here is the only way to recover them,
# and it keeps the divergence from Annex A visible.
#
# `TB.C3.DE.2` and `TB.C3.DE.3` are "High" and "Low" under `TB.C3.DE.1 Risk of MDR-TB`, which
# Annex B reads as an option string rather than as a Boolean: `TB.C16.1.DT.02` fires on
# `"Risk of MDR-TB" = 'High'` and `TB.C16.1.DT.03` on `= 'Low'`. `TB.Comm.DE.85` is the last
# option of `TB.Comm.DE.73 Test sample type`, after ten siblings the kit marks properly.
OPTION_ROWS = {
    "TB.C3.DE.2",  # High - see ELEMENT_TYPES for the parent
    "TB.C3.DE.3",  # Low
    "TB.Comm.DE.85",  # Other - the eleventh sample type
}

# A type the kit states inconsistently, read off its sibling rows rather than invented.
#
# `TB.C3.DE.1 Risk of MDR-TB` is typed `Boolean` with the two rows beneath it holding "High" and
# "Low" — the values Annex B's `TB.C16.1.DT` compares it against, and neither of them true or
# false. `TB.A7.DE.38 Alternative contact relationship` is typed `String` but declares
# `Select one` and carries nine `Input Option` rows, which a String drops on the floor.
ELEMENT_TYPES = {
    "TB.C3.DE.1": "Coding",  # Risk of MDR-TB - High / Low, per Annex B
    "TB.A7.DE.38": "Coding",  # Alternative contact relationship - Select one, with nine options
}

# The kit's own core shortlist. `Required = R` and an Annex C indicator link between them carry
# the registration and screening forms, but this kit states most of its clinical content as
# `Required = C` — 127 of its 203 typed elements — so the diagnostic cascade, the treatment
# record and the whole of TPT would otherwise select down to almost nothing. Each entry below is
# an input to an encoded Annex B rule, an element an Annex C calculation names, or a branch the
# care pathway turns on.
CORE_TABS = {"TB.B.Screening", "TB.C.Diagnosis", "TB.D.TB Treatment", "TB.E.TPT", "TB.F.Referral"}

CORE_ELEMENTS = {
    # --- screening ---------------------------------------------------------
    # The algorithm chosen, the result reached and the date it was reached: `TB.B7.DT`'s inputs
    # and its output, and the element every screening indicator counts (`TB.IND.1`, `TB.IND.2`).
    "TB.B4.DE.1",  # TB screening algorithm
    "TB.B5.DE.1",  # CRP test result in mg/L - the CRP algorithms' only input
    "TB.B7.DE.1",  # TB screening result
    "TB.B7.DE.5",  # Date of TB screening result
    "TB.Comm.DE.57",  # Symptoms of TB
    "TB.Comm.DE.68",  # Symptom screening result
    "TB.Comm.DE.130",  # CXR result
    "TB.Comm.DE.126",  # HIV status - the branch `TB.B4.DT` and `TB.C7.DT` both turn on
    "TB.Comm.DE.45",  # Inpatient with HIV - `TB.B7.DT.30`, `TB.C7.DT.01`
    "TB.Comm.DE.46",  # History of contact with a person with TB
    "TB.Comm.DE.88",  # mWRD test result
    "TB.Comm.DE.101",  # Date of TB diagnostic test result
    # --- diagnosis ---------------------------------------------------------
    # The cascade from presumptive TB to a diagnosis, and the resistance profile that decides
    # which regimen the client is eligible for.
    "TB.C1.DE.3",  # Signs and symptoms of - `TB.C7.DT.15`, `TB.C7.DT.16`
    "TB.C1.DE.7",  # Date of presumptive TB registration
    "TB.C2.DE.1",  # At risk for HIV
    "TB.C2.DE.2",  # HIV clinical stage
    "TB.C2.DE.7",  # Advanced HIV disease
    "TB.C2.DE.8",  # Seriously ill - `TB.C7.DT.03`, `TB.C7.DT.08`
    "TB.C3.DE.1",  # Risk of MDR-TB - `TB.C16.1.DT.02`, `.03`; see ELEMENT_TYPES
    "TB.C3.DE.4",  # TB contact in the previous 12 months - `TB.C24.DT`
    "TB.C11.DE.2",  # TB diagnostic test type
    "TB.C11.DE.12",  # TB diagnostic tool - `TB.C16.1.DT.05`
    "TB.C12.DE.1",  # LF-LAM test result
    "TB.C16.1.DE.1",  # mWRD test RIF resistance result
    "TB.C16.1.DE.5",  # Interpretation of ultra melting curve result
    "TB.C16.1.DE.13",  # Date rifampicin susceptibility status determined
    # The rest of the drug-susceptibility panel. Annex A links the isoniazid, fluoroquinolone,
    # bedaquiline and linezolid results to an indicator and leaves the other five unlinked, but
    # a panel carried by halves records a resistance profile the regimen tables cannot read.
    "TB.C20.DE.21",  # Amikacin susceptibility test result
    "TB.C20.DE.26",  # Pyrazinamide susceptibility test result
    "TB.C20.DE.31",  # Clofazimine susceptibility test result
    "TB.C20.DE.36",  # Delamanid susceptibility test result
    "TB.C20.DE.41",  # Pretomanid susceptibility test result
    "TB.C20.DE.46",  # TB resistance type
    "TB.C22.DE.1",  # Total score - `TB.C24.DT`'s treatment decision score for children
    "TB.C24.DE.1",  # TB diagnosis result
    "TB.C24.DE.4",  # Date of TB diagnosis
    "TB.C24.DE.5",  # TB registration number
    "TB.C24.DE.6",  # Method of diagnosis
    "TB.C24.DE.9",  # Extensive TB disease - `TB.D10.DT`
    "TB.C24.DE.10",  # Severe TB disease - `TB.D9.DT`, `TB.D10.DT`
    "TB.Comm.DE.44",  # CD4 count - the LF-LAM thresholds of `TB.C7.DT`
    "TB.Comm.DE.72",  # Test sample collected
    "TB.Comm.DE.73",  # Test sample type
    "TB.Comm.DE.86",  # Date of test sample collection
    "TB.Comm.DE.87",  # Date of TB diagnostic test
    "TB.Comm.DE.93",  # Microscopy - sputum test result
    "TB.Comm.DE.96",  # Culture result
    "TB.Comm.DE.23",  # Risk factors/comorbidities - `TB.C16.1.DT.15`, and the registry's list
    "TB.Comm.DE.48",  # Year of previous TB treatment - `TB.C16.1.DT.17`'s false-positive window
    # --- treatment ---------------------------------------------------------
    # Eligibility, the regimen, the dates the treatment cohort is counted from, and the outcome.
    "TB.D1.DE.1",  # TB treatment regimen type
    "TB.D1.DE.5",  # Additional eligibility criteria for drug-resistant TB regimens
    "TB.D5.DE.1",  # Breastfeeding - `TB.D9.DT`, `TB.D10.DT`
    "TB.D5.DE.2",  # Willing to use effective contraception - `TB.D10.DT`
    "TB.D5.DE.3",  # Postpartum - `TB.D9.DT`
    "TB.D10.DE.1",  # Composition of TB treatment regimen
    "TB.D10.DE.25",  # TB treatment duration
    "TB.D13.DE.1",  # TB treatment started
    "TB.D13.DE.2",  # Date TB treatment started
    "TB.D13.DE.3",  # Month of treatment - the monitoring schedule counts in these
    "TB.D13.DE.4",  # Expected completion date of TB treatment
    "TB.D18.DE.2",  # Bacteriologically converted (to negative)
    "TB.D18.DE.3",  # Conversion date
    # Every indicator from `TB.IND.10` on excludes de-notified cases from its denominator, so a
    # form with no way to record one cannot compute any of them.
    "TB.D18.DE.6",  # Case de-notified
    "TB.D18.DE.7",  # Reason de-notified
    "TB.Comm.DE.43",  # Date started on ART - `TB.IND.17`'s numerator
    "TB.D24.DE.8",  # Date outcome assigned
    "TB.Comm.DE.49",  # Hypersensitivity or allergy or contraindication to TB drugs
    "TB.Comm.DE.102",  # Site of TB disease
    "TB.Comm.DE.105",  # Type of extrapulmonary TB
    "TB.Comm.DE.133",  # LFT result
    "TB.Comm.DE.136",  # Reason treatment was not started
    "TB.Comm.DE.121",  # Pregnancy status - the regimens `TB.D9.DT` and `TB.D10.DT` rule out
    # --- TB preventive treatment -------------------------------------------
    # Nothing on this tab is `Required = R`, so without the shortlist the TPT form is the seven
    # elements Annex C happens to link and no record of what was given.
    "TB.E1.DE.1",  # TB preventive treatment counselling offered
    "TB.E2.DE.1",  # TB prevention services accepted - the consent this pathway turns on
    "TB.E3.1.DE.1",  # TB infection test recommended - `TB.E3.1.DT`'s output
    "TB.E3.3.DE.1",  # TB infection test performed - `TB.E4.7.DT.09`, `.15`
    "TB.E3.3.DE.2",  # Date of TB infection test
    "TB.E3.3.DE.3",  # Type of TB infection test performed
    "TB.E3.4.DE.1",  # TB infection test result - `TB.E4.7.DT.08`, `.14`
    "TB.E3.4.DE.3",  # Date of TB infection test result
    "TB.E4.1.DE.1",  # TB resistance type of index case - `TB.E4.7.DT`, `TB.E6.DT`
    "TB.E4.2.DE.1",  # Medication affecting TPT - `TB.E8.DT`
    "TB.E4.7.DE.2",  # Date when eligibility for TPT was determined
    "TB.E6.DE.1",  # TPT regimen
    "TB.E9.DE.9",  # TPT expected completion date
    "TB.E14.DE.1",  # TPT completion date
    # --- referral ----------------------------------------------------------
    # Where the client went and why, which is the only record of a transfer between facilities.
    "TB.F6.DE.4",  # Reason for transfer
    "TB.F6.DE.10",  # Transfer in date
    "TB.F6.DE.11",  # Transfer out date
    "TB.F6.DE.13",  # Destination facility ID
    "TB.F6.DE.16",  # Reason for the referral
    "TB.F6.DE.27",  # Destination facility name
}

# --- decision support (Annex B) ---------------------------------------------
# A form can prompt; it cannot conclude. Each rule shows the DAK's own guidance when its inputs
# are answered, and leaves the judgement with the clinician.
#
# This kit's decision tables are algorithms rather than alerts: `TB.B7.DT` walks 57 rules over
# five inputs to reach a screening result, `TB.D9.DT` and `TB.D10.DT` choose a regimen, and
# `TB.DT.14` is 311 rows of weight-band dosing. A Tamanu `visibilityCriteria` is a conjunction of
# equalities on the same form, so none of those is encodable as written. What is encodable is the
# guidance attached to a *conclusion the health worker records*: the kit's own text for a
# positive screen, for a detected mWRD result, for RIF resistance. Those are the rules below.
# See dak-conformance.md for the tables that are not encodable and why.
DECISION_SUPPORT = [
    # TB.B7.DT reaches one of three screening results, and every rule that reaches a given result
    # carries the same guidance for it. Gating on the recorded result rather than reproducing the
    # 57 rules keeps the kit's own words next to the answer that raised them.
    {
        "rule": "TB.B7.DT",
        "survey": "screening",
        "after": "TB.B7.DE.1",
        "code": "whodaktb-ds-b7-screen-positive",
        "name": "Screen positive for TB - refer for diagnostic evaluation",
        "guidance": (
            "Refer the client for diagnostic evaluation including a WHO-recommended rapid "
            "diagnostic (mWRD) test and clinical evaluation as indicated."
        ),
        "gate": {"TB.B7.DE.1": "Screen positive for TB"},
        "issue": {"issueType": "warning", "issueNote": "Screened positive for TB - diagnostic evaluation due"},
    },
    {
        "rule": "TB.B7.DT",
        "survey": "screening",
        "after": "TB.B7.DE.1",
        "code": "whodaktb-ds-b7-screen-negative",
        "name": "Screen negative for TB - assess for TPT",
        "guidance": "Assess the client for TB preventive treatment.",
        "gate": {"TB.B7.DE.1": "Screen negative for TB"},
    },
    {
        "rule": "TB.B7.DT",
        "survey": "screening",
        "after": "TB.B7.DE.1",
        "code": "whodaktb-ds-b7-inconclusive",
        "name": "Inconclusive screen - consider repeating the test",
        "guidance": (
            "Consider repeating the test. Explore alternate diagnoses, and assess the client for "
            "TB preventive treatment if TB disease is ruled out."
        ),
        "gate": {"TB.B7.DE.1": "Inconclusive"},
    },
    # TB.B4.DT proposes a screening algorithm from risk group and age. Age is on the patient
    # record rather than on this form, so the two age branches are stated in the guidance rather
    # than gated on - which is why this is one prompt for people living with HIV and not two.
    {
        "rule": "TB.B4.DT",
        "survey": "screening",
        "after": "TB.B3.DE.1",
        "code": "whodaktb-ds-b4-plhiv-algorithm",
        "name": "Person living with HIV - choose the recommended algorithm",
        # Trimmed to fit the varchar(255) `text` column: the two age branches and what each
        # screens with, without the wording Annex B wraps them in.
        "guidance": (
            "Aged 10 and above: screen with a WHO-recommended algorithm for people living with "
            "HIV (W4SS with CXR, in parallel or in sequence). Under 10: screen at every "
            "encounter with cough, fever, poor weight gain and contact history."
        ),
        "gate": {"TB.B3.DE.1": ["PLHIV"]},
    },
    # TB.C24.DT.01 is the only rule in the kit that interrupts the pathway outright: a child with
    # danger signs is stabilised or transferred before anything else. Age is not on the form, so
    # the prompt names the age the rule applies to; danger signs in an adult warrant the same
    # response, which is why showing it more widely is safe.
    {
        "rule": "TB.C24.DT.01",
        "survey": "diagnosis",
        "after": "TB.C1.DE.2",
        "code": "whodaktb-ds-c24-danger-signs",
        "name": "Danger signs present - stabilise or transfer",
        "guidance": (
            "Stabilise the client and transfer as needed: refer to a higher level of care as "
            "appropriate. In a child under 10 years this is the first step of the diagnostic "
            "algorithm and comes before any further assessment."
        ),
        "gate": {"TB.C1.DE.2": "Yes"},
        "issue": {"issueType": "warning", "issueNote": "Danger signs recorded at TB diagnosis"},
    },
    # TB.C7.DT.03 and TB.C7.DT.08 both put a seriously ill client living with HIV onto LF-LAM,
    # inpatient or not, so the two rules collapse into one gate.
    {
        "rule": "TB.C7.DT.03",
        "survey": "diagnosis",
        "after": "TB.C2.DE.8",
        "code": "whodaktb-ds-c7-lf-lam-seriously-ill",
        "name": "Seriously ill and living with HIV - perform an LF-LAM assay",
        "guidance": (
            "Collect a urine sample and perform a urine LF-LAM assay. If the LF-LAM assay is "
            "positive, collect a specimen and perform an mWRD test."
        ),
        "gate": {"TB.Comm.DE.126": "HIV-positive", "TB.C2.DE.8": "Yes"},
    },
    {
        "rule": "TB.C7.DT.16",
        "survey": "diagnosis",
        "after": "TB.C1.DE.3",
        "code": "whodaktb-ds-c7-extrapulmonary",
        "name": "Extrapulmonary TB - test with Xpert or culture",
        "guidance": (
            "Collect a specimen and perform initial testing for the diagnosis of TB with Xpert "
            "MTB/RIF, Xpert MTB/RIF Ultra or TB culture."
        ),
        "gate": {"TB.C1.DE.3": ["Extrapulmonary TB"]},
    },
    # TB.C12.DT reads each test's result into a confirmation decision. The three results below
    # reach the same conclusion whatever else the table knows, so each is one prompt.
    {
        "rule": "TB.C12.DT.02",
        "survey": "diagnosis",
        "after": "TB.Comm.DE.88",
        "code": "whodaktb-ds-c12-mwrd-detected",
        "name": "MTB detected - TB is bacteriologically confirmed",
        "guidance": (
            "TB disease is bacteriologically confirmed. Interpret the rifampicin resistance "
            "results if available; otherwise conduct additional investigations to assess "
            "resistance to rifampicin."
        ),
        "gate": {"TB.Comm.DE.88": "MTB detected"},
    },
    {
        "rule": "TB.C12.DT.04",
        "survey": "diagnosis",
        "after": "TB.Comm.DE.88",
        "code": "whodaktb-ds-c12-mwrd-error",
        "name": "Error, invalid or no mWRD result - repeat with a new specimen",
        "guidance": (
            "Consider repeating the mWRD test with a new specimen. Conduct additional testing in "
            "accordance with national guidelines, and use clinical judgement for treatment "
            "decisions."
        ),
        "gate": {"TB.Comm.DE.88": "Error/Invalid/No result"},
    },
    {
        "rule": "TB.C12.DT.31",
        "survey": "diagnosis",
        "after": "TB.Comm.DE.93",
        "code": "whodaktb-ds-c12-microscopy-positive",
        "name": "Sputum smear positive - TB is bacteriologically confirmed",
        "guidance": (
            "TB disease is bacteriologically confirmed. Perform an mWRD test to evaluate rifampicin resistance."
        ),
        "gate": {"TB.Comm.DE.93": "Positive"},
    },
    {
        "rule": "TB.C12.DT.33",
        "survey": "diagnosis",
        "after": "TB.Comm.DE.96",
        "code": "whodaktb-ds-c12-culture-positive",
        "name": "Culture positive for TB - TB is bacteriologically confirmed",
        "guidance": (
            "TB disease is bacteriologically confirmed. Consider performing follow-on testing to "
            "detect drug resistance."
        ),
        "gate": {"TB.Comm.DE.96": ["Positive for TB"]},
    },
    # TB.C16.1.DT.02 and .03 split on the MDR-TB risk assessment, and the split is the whole
    # point of the rule: the same detected result means treat for MDR-TB in a high-risk client
    # and repeat the test in a low-risk one. Both inputs are on this form.
    {
        "rule": "TB.C16.1.DT.02",
        "survey": "diagnosis",
        "after": "TB.C16.1.DE.1",
        "code": "whodaktb-ds-c161-rif-resistant-high-risk",
        "name": "RIF resistance detected, high MDR-TB risk - treat as MDR-TB",
        "guidance": (
            "The client is infected with a strain of Mycobacterium tuberculosis complex resistant "
            "to rifampicin. Treat with an MDR-TB regimen in accordance with national guidelines, "
            "and perform drug-susceptibility testing to detect resistance to other medicines."
        ),
        "gate": {"TB.C16.1.DE.1": "RIF resistance DETECTED", "TB.C3.DE.1": "High"},
        "issue": {"issueType": "warning", "issueNote": "Rifampicin resistance detected"},
    },
    {
        "rule": "TB.C16.1.DT.03",
        "survey": "diagnosis",
        "after": "TB.C16.1.DE.1",
        "code": "whodaktb-ds-c161-rif-resistant-low-risk",
        "name": "RIF resistance detected, low MDR-TB risk - repeat the test",
        "guidance": "Repeat the mWRD test with a fresh specimen and interpret the results.",
        "gate": {"TB.C16.1.DE.1": "RIF resistance DETECTED", "TB.C3.DE.1": "Low"},
    },
    # TB.E4.7.DT decides TPT eligibility from the screening result, the risk group and the
    # infection test. The first two are collected on the screening form, so only the two rules
    # that turn on the infection test alone can be encoded here.
    {
        "rule": "TB.E4.7.DT.08",
        "survey": "tpt",
        "after": "TB.E3.4.DE.1",
        "code": "whodaktb-ds-e47-infection-test-negative",
        "name": "TB infection test negative - use clinical judgement",
        "guidance": (
            "The TB infection test result is negative. A negative test does not rule out TB "
            "infection: use clinical judgement in deciding whether to offer TB preventive "
            "treatment."
        ),
        "gate": {"TB.E3.4.DE.1": "Negative"},
    },
    {
        "rule": "TB.E4.7.DT.09",
        "survey": "tpt",
        "after": "TB.E3.3.DE.1",
        "code": "whodaktb-ds-e47-no-infection-test",
        "name": "No TB infection test result - use clinical judgement",
        "guidance": (
            "TB infection test results are not available for this client. Testing for TB "
            "infection is not a requirement for starting TB preventive treatment: use clinical "
            "judgement."
        ),
        "gate": {"TB.E3.3.DE.1": "No"},
    },
]

# --- the program registry ---------------------------------------------------
# Not from the DAK: program registries are a Tamanu construct, and this is our own modelling of
# a client's TB episode. Clinical status and condition codes are prefixed with the registry code
# because `prClinicalStatus-<code>` is a global id and the status code is unique database-wide.
REGISTRY = {
    "registryCode": "who-dak-tb",
    "registryName": "WHO DAK TB",
    "currentlyAtType": "facility",
    "visibilityStatus": "current",
    "lossToFollowUpEnabled": True,
    # The kit's own definition, from `TB.D24.DE.6`: "Client did not start treatment or treatment
    # was interrupted for two consecutive months or more". Two consecutive months is at most 62
    # days, and Tamanu's default of 90 would leave a client the TB programme already counts as
    # lost sitting in the registry as active for another month.
    "lossToFollowUpThresholdDays": 62,
    # Where this client's TB episode stands. The six treatment states are the kit's own
    # `Treatment outcome` values (`TB.D24.DE.1`); the states before treatment are the pathway's,
    # since the kit has no element that says a client is under diagnostic evaluation.
    "clinicalStatuses": [
        {"code": "who-dak-tb-presumptive", "name": "Presumptive TB", "color": "yellow"},
        {"code": "who-dak-tb-excluded", "name": "TB excluded", "color": "grey"},
        {"code": "who-dak-tb-on-treatment", "name": "On TB treatment", "color": "green"},
        {"code": "who-dak-tb-on-tpt", "name": "On TB preventive treatment", "color": "teal"},
        {"code": "who-dak-tb-cured", "name": "Cured", "color": "blue"},
        {"code": "who-dak-tb-treatment-completed", "name": "Treatment completed", "color": "blue"},
        {"code": "who-dak-tb-treatment-failed", "name": "Treatment failed", "color": "orange"},
        {"code": "who-dak-tb-lost-to-follow-up", "name": "Lost to follow-up", "color": "red"},
        {"code": "who-dak-tb-died", "name": "Died", "color": "purple"},
        {"code": "who-dak-tb-transferred-out", "name": "Transferred out", "color": "brown"},
    ],
    # What the client carries between contacts, so the registry holds it rather than each contact
    # re-collecting it: the form of the disease, its resistance profile, and the comorbidities
    # that change how it is treated.
    #
    # The disease and resistance entries trace to `TB.Comm.DE.102 Site of TB disease`,
    # `TB.Comm.DE.105 Type of extrapulmonary TB` and `TB.C20.DE.46 TB resistance type`; the
    # comorbidities to the options of `TB.Comm.DE.23 Risk factors/comorbidities`.
    #
    # Six of that element's options are deliberately not here: `Prisoners`, `Health-care
    # workers`, `Immigrants`, `Homeless people` and `General population in high TB prevalence
    # settings` are populations rather than conditions, and `Previously treated for TB` is a
    # history the diagnosis form records against `TB.Comm.DE.48 Year of previous TB treatment`.
    #
    # HIV, diabetes, viral hepatitis and malnutrition are named as the HIV and FP registries name
    # them, so a deployment running more than one sees one condition rather than several. The
    # kit's own word for malnutrition is "Undernutrition".
    "conditions": [
        {"code": "who-dak-tb-cond-pulmonary", "name": "Pulmonary TB"},
        {"code": "who-dak-tb-cond-extrapulmonary", "name": "Extrapulmonary TB"},
        {"code": "who-dak-tb-cond-tb-meningitis", "name": "TB meningitis"},
        {"code": "who-dak-tb-cond-cns-tb", "name": "TB of the central nervous system"},
        {"code": "who-dak-tb-cond-disseminated-tb", "name": "Disseminated TB"},
        {"code": "who-dak-tb-cond-osteoarticular-tb", "name": "Osteoarticular TB"},
        {"code": "who-dak-tb-cond-pericardial-tb", "name": "Pericardial TB"},
        {"code": "who-dak-tb-cond-lymph-node-tb", "name": "Peripheral lymph node TB"},
        {"code": "who-dak-tb-cond-rr-tb", "name": "Rifampicin-resistant TB (RR-TB)"},
        {"code": "who-dak-tb-cond-hr-tb", "name": "Isoniazid-resistant TB (Hr-TB)"},
        {"code": "who-dak-tb-cond-mdr-tb", "name": "Multidrug-resistant TB (MDR-TB)"},
        {"code": "who-dak-tb-cond-pre-xdr-tb", "name": "Pre-extensively drug-resistant TB (pre-XDR-TB)"},
        {"code": "who-dak-tb-cond-xdr-tb", "name": "Extensively drug-resistant TB (XDR-TB)"},
        {"code": "who-dak-tb-cond-hiv", "name": "HIV"},
        {"code": "who-dak-tb-cond-diabetes", "name": "Diabetes mellitus"},
        {"code": "who-dak-tb-cond-viral-hepatitis", "name": "Viral hepatitis"},
        {"code": "who-dak-tb-cond-malnutrition", "name": "Malnutrition"},
        {"code": "who-dak-tb-cond-chronic-lung-disease", "name": "Chronic lung disease"},
        {"code": "who-dak-tb-cond-silicosis", "name": "Silica exposure"},
        {"code": "who-dak-tb-cond-alcohol-use", "name": "Alcohol use disorder"},
        {"code": "who-dak-tb-cond-drug-use", "name": "Drug use disorder"},
        {"code": "who-dak-tb-cond-smoking", "name": "Tobacco smoking"},
        {"code": "who-dak-tb-cond-dialysis", "name": "On dialysis"},
        {"code": "who-dak-tb-cond-anti-tnf", "name": "On anti-TNF treatment"},
        {"code": "who-dak-tb-cond-transplant", "name": "Preparing for transplantation"},
        {"code": "who-dak-tb-cond-fibrotic-lesions", "name": "Fibrotic lesions on chest X-ray"},
    ],
    # Tamanu hard-loads unknown / disproven / resolved / recordedInError into every registry and
    # merges spreadsheet rows over them. Those four alone cannot express a *confirmed* condition,
    # so the standard clinical progression is added. These codes are deliberately unprefixed:
    # Tamanu's UI carries labels for exactly these strings, and they are scoped per registry.
    "conditionCategories": [
        {"code": "suspected", "name": "Suspected"},
        {"code": "underInvestigation", "name": "Under investigation"},
        {"code": "confirmed", "name": "Confirmed"},
        {"code": "inRemission", "name": "In remission"},
    ],
}
