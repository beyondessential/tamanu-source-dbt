"""Guards the data sources of the standard reports that run on the central server only.

BL-004 (see specs/reports/report-facility-options.md): these reports offer "All facilities" only,
because their rows have no facility link or a facility server holds only part of their data.
"""

import json
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
CONFIGS = ROOT / "models" / "reports" / "config" / "standard"

ALL_FACILITIES_ONLY = [
    "registered-patients-line-list",
    "registered-patients-by-dob-line-list",
    "audit-patient-details-edit",
    "usage-quality-metrics-patient-details",
    "usage-quality-metrics-patient-registrations",
    "upcoming-vaccinations-line-list",
]


@pytest.mark.parametrize("report", ALL_FACILITIES_ONLY)
def test_ac_003_report_offers_all_facilities_only(report):
    config = json.loads((CONFIGS / f"{report}.json").read_text(encoding="utf-8"))
    assert config["queryOptions"]["dataSources"] == ["allFacilities"]
