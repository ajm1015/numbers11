"""Tests for the normalizer — the most critical module in the hub.

These tests verify the correctness of field mapping from Kandji and Intune
raw data into the unified device schema.
"""

import pytest
from datetime import datetime, timezone

from mdm_shared.models.kandji import KandjiDevice, KandjiDeviceDetails
from mdm_shared.models.intune import IntuneManagedDevice

from mcp_mdm_hub.models.unified import (
    ComplianceStatus,
    DevicePlatform,
    DeviceSource,
    OwnershipType,
)
from mcp_mdm_hub.normalizer import (
    normalize_kandji_device,
    normalize_intune_device,
    _normalize_kandji_platform,
    _normalize_intune_platform,
)


class TestPlatformNormalization:
    def test_kandji_mac(self) -> None:
        assert _normalize_kandji_platform("Mac") == DevicePlatform.MACOS

    def test_kandji_iphone(self) -> None:
        assert _normalize_kandji_platform("iPhone") == DevicePlatform.IOS

    def test_kandji_ipad(self) -> None:
        assert _normalize_kandji_platform("iPad") == DevicePlatform.IPADOS

    def test_kandji_appletv(self) -> None:
        assert _normalize_kandji_platform("AppleTV") == DevicePlatform.TVOS

    def test_kandji_unknown(self) -> None:
        assert _normalize_kandji_platform("SomethingElse") == DevicePlatform.UNKNOWN

    def test_kandji_none(self) -> None:
        assert _normalize_kandji_platform(None) == DevicePlatform.UNKNOWN

    def test_intune_windows(self) -> None:
        assert _normalize_intune_platform("Windows") == DevicePlatform.WINDOWS

    def test_intune_ios(self) -> None:
        assert _normalize_intune_platform("iOS") == DevicePlatform.IOS

    def test_intune_macos(self) -> None:
        assert _normalize_intune_platform("macOS") == DevicePlatform.MACOS

    def test_intune_android(self) -> None:
        assert _normalize_intune_platform("Android") == DevicePlatform.ANDROID

    def test_intune_unknown(self) -> None:
        assert _normalize_intune_platform("ChromeOS") == DevicePlatform.UNKNOWN


class TestNormalizeKandjiDevice:
    def test_basic_normalization(self) -> None:
        device = KandjiDevice(
            device_id="abc-123",
            device_name="Jack's Mac",
            serial_number="C02XYZ",
            platform="Mac",
            os_version="15.3",
            last_check_in="2026-02-09T10:00:00Z",
            blueprint_id="bp-1",
            blueprint_name="Standard",
            asset_tag="ASSET-001",
            mdm_enabled=True,
        )

        unified = normalize_kandji_device(device)

        assert unified.source == DeviceSource.KANDJI
        assert unified.source_id == "abc-123"
        assert unified.device_name == "Jack's Mac"
        assert unified.serial_number == "C02XYZ"
        assert unified.platform == DevicePlatform.MACOS
        assert unified.os_version == "15.3"
        assert unified.compliance_status == ComplianceStatus.NOT_APPLICABLE
        assert unified.source_metadata is not None
        assert unified.source_metadata["blueprint_name"] == "Standard"

    def test_with_details(self) -> None:
        device = KandjiDevice(
            device_id="abc-123",
            device_name="Mac",
            serial_number="C02XYZ",
            platform="Mac",
        )
        details = KandjiDeviceDetails(
            hardware_overview={
                "serial_number": "C02XYZ",
                "model_name": "MacBook Pro",
                "processor_name": "Apple M4",
            },
            network={
                "ip_address": "192.168.1.42",
                "local_hostname": "Jacks-Mac",
            },
            filevault={"filevault_enabled": True},
            security_information={"firewall_enabled": True},
            activation_lock={"activation_lock_enabled": False},
        )

        unified = normalize_kandji_device(device, details)

        assert unified.hardware is not None
        assert unified.hardware.model == "MacBook Pro"
        assert unified.hardware.processor == "Apple M4"
        assert unified.hardware.manufacturer == "Apple"

        assert unified.network is not None
        assert unified.network.ip_address == "192.168.1.42"
        assert unified.network.hostname == "Jacks-Mac"

        assert unified.security is not None
        assert unified.security.encryption_enabled is True
        assert unified.security.firewall_enabled is True
        assert unified.security.activation_lock_enabled is False

    def test_with_user(self) -> None:
        device = KandjiDevice(
            device_id="abc-123",
            device_name="Mac",
            user={"name": "Jack", "email": "jack@example.com"},
        )

        unified = normalize_kandji_device(device)

        assert unified.user is not None
        assert unified.user.name == "Jack"
        assert unified.user.email == "jack@example.com"

    def test_missing_optional_fields(self) -> None:
        device = KandjiDevice(device_id="minimal-device")

        unified = normalize_kandji_device(device)

        assert unified.source_id == "minimal-device"
        assert unified.device_name is None
        assert unified.platform == DevicePlatform.UNKNOWN
        assert unified.hardware is None
        assert unified.network is None
        assert unified.security is None


class TestNormalizeIntuneDevice:
    def test_basic_normalization(self) -> None:
        device = IntuneManagedDevice(
            id="111-aaa",
            deviceName="DESKTOP-ABC",
            serialNumber="PF4WXYZ1",
            operatingSystem="Windows",
            osVersion="10.0.22631",
            model="Surface Laptop 5",
            manufacturer="Microsoft",
            complianceState="compliant",
            managedDeviceOwnerType="company",
            enrolledDateTime="2025-06-15T09:00:00Z",
            lastSyncDateTime="2026-02-09T08:45:00Z",
            userPrincipalName="jack@contoso.com",
            userDisplayName="Jack Morton",
            emailAddress="jack@contoso.com",
            isEncrypted=True,
            isSupervised=False,
        )

        unified = normalize_intune_device(device)

        assert unified.source == DeviceSource.INTUNE
        assert unified.source_id == "111-aaa"
        assert unified.device_name == "DESKTOP-ABC"
        assert unified.serial_number == "PF4WXYZ1"
        assert unified.platform == DevicePlatform.WINDOWS
        assert unified.os_version == "10.0.22631"
        assert unified.compliance_status == ComplianceStatus.COMPLIANT
        assert unified.ownership == OwnershipType.CORPORATE

    def test_user_mapping(self) -> None:
        device = IntuneManagedDevice(
            id="222",
            userPrincipalName="jack@contoso.com",
            userDisplayName="Jack Morton",
            emailAddress="jack@contoso.com",
        )

        unified = normalize_intune_device(device)

        assert unified.user is not None
        assert unified.user.name == "Jack Morton"
        assert unified.user.email == "jack@contoso.com"
        assert unified.user.principal_name == "jack@contoso.com"

    def test_hardware_mapping(self) -> None:
        device = IntuneManagedDevice(
            id="333",
            model="Surface Pro 9",
            manufacturer="Microsoft",
            serialNumber="SN123",
            totalStorageSpaceInBytes=512_000_000_000,
            freeStorageSpaceInBytes=256_000_000_000,
            physicalMemoryInBytes=16_000_000_000,
        )

        unified = normalize_intune_device(device)

        assert unified.hardware is not None
        assert unified.hardware.model == "Surface Pro 9"
        assert unified.hardware.manufacturer == "Microsoft"
        assert unified.hardware.total_storage_bytes == 512_000_000_000
        assert unified.hardware.memory_bytes == 16_000_000_000

    def test_noncompliant_mapping(self) -> None:
        device = IntuneManagedDevice(id="444", complianceState="noncompliant")
        unified = normalize_intune_device(device)
        assert unified.compliance_status == ComplianceStatus.NONCOMPLIANT

    def test_personal_ownership(self) -> None:
        device = IntuneManagedDevice(id="555", managedDeviceOwnerType="personal")
        unified = normalize_intune_device(device)
        assert unified.ownership == OwnershipType.PERSONAL

    def test_jailbroken_false(self) -> None:
        device = IntuneManagedDevice(id="666", jailBroken="False")
        unified = normalize_intune_device(device)
        assert unified.security is not None
        assert unified.security.jailbroken is False

    def test_jailbroken_true(self) -> None:
        device = IntuneManagedDevice(id="777", jailBroken="True")
        unified = normalize_intune_device(device)
        assert unified.security is not None
        assert unified.security.jailbroken is True

    def test_minimal_device(self) -> None:
        device = IntuneManagedDevice(id="minimal")
        unified = normalize_intune_device(device)

        assert unified.source_id == "minimal"
        assert unified.platform == DevicePlatform.UNKNOWN
        assert unified.compliance_status == ComplianceStatus.UNKNOWN
        assert unified.ownership == OwnershipType.UNKNOWN
