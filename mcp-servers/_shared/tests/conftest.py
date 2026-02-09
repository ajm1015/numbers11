"""Shared test fixtures for mdm_shared tests."""

import json
from pathlib import Path

import pytest

FIXTURES_DIR = Path(__file__).parent / "fixtures"


@pytest.fixture
def kandji_devices_json() -> list[dict]:
    """Load Kandji device list fixture."""
    return json.loads((FIXTURES_DIR / "kandji_devices.json").read_text())


@pytest.fixture
def kandji_device_detail_json() -> dict:
    """Load Kandji device detail fixture."""
    return json.loads((FIXTURES_DIR / "kandji_device_detail.json").read_text())


@pytest.fixture
def intune_devices_json() -> dict:
    """Load Intune device list fixture (full Graph API response with @odata wrapper)."""
    return json.loads((FIXTURES_DIR / "intune_devices.json").read_text())


@pytest.fixture
def intune_device_detail_json() -> dict:
    """Load Intune device detail fixture."""
    return json.loads((FIXTURES_DIR / "intune_device_detail.json").read_text())
