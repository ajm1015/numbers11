"""Pydantic models for Microsoft Intune (Graph API) responses."""

from datetime import datetime
from enum import Enum
from typing import Any, Optional

from pydantic import BaseModel, Field


class ComplianceState(str, Enum):
    """Intune device compliance states."""

    UNKNOWN = "unknown"
    COMPLIANT = "compliant"
    NONCOMPLIANT = "noncompliant"
    CONFLICT = "conflict"
    ERROR = "error"
    IN_GRACE_PERIOD = "inGracePeriod"
    CONFIG_MANAGER = "configManager"


class ManagementAgent(str, Enum):
    """Intune management agent types."""

    EAS = "eas"
    MDM = "mdm"
    EAS_MDM = "easMdm"
    INTUNE_CLIENT = "intuneClient"
    EAS_INTUNE_CLIENT = "easIntuneClient"
    CONFIG_MANAGER_CLIENT = "configurationManagerClient"
    UNKNOWN = "unknown"
    JAMF = "jamf"
    GOOGLE_CLOUD = "googleCloudDevicePolicyController"


class OwnerType(str, Enum):
    """Device ownership types."""

    UNKNOWN = "unknown"
    COMPANY = "company"
    PERSONAL = "personal"


class IntuneManagedDevice(BaseModel):
    """Managed device from Intune (GET /deviceManagement/managedDevices)."""

    id: str = Field(description="Intune device ID (GUID)")
    device_name: Optional[str] = Field(None, alias="deviceName")
    serial_number: Optional[str] = Field(None, alias="serialNumber")
    operating_system: Optional[str] = Field(None, alias="operatingSystem")
    os_version: Optional[str] = Field(None, alias="osVersion")
    model: Optional[str] = None
    manufacturer: Optional[str] = None
    compliance_state: Optional[ComplianceState] = Field(None, alias="complianceState")
    management_agent: Optional[ManagementAgent] = Field(None, alias="managementAgent")
    owner_type: Optional[OwnerType] = Field(None, alias="managedDeviceOwnerType")
    enrolled_date_time: Optional[datetime] = Field(None, alias="enrolledDateTime")
    last_sync_date_time: Optional[datetime] = Field(None, alias="lastSyncDateTime")
    user_principal_name: Optional[str] = Field(None, alias="userPrincipalName")
    user_display_name: Optional[str] = Field(None, alias="userDisplayName")
    email_address: Optional[str] = Field(None, alias="emailAddress")
    azure_ad_device_id: Optional[str] = Field(None, alias="azureADDeviceId")
    is_encrypted: Optional[bool] = Field(None, alias="isEncrypted")
    is_supervised: Optional[bool] = Field(None, alias="isSupervised")
    imei: Optional[str] = None
    phone_number: Optional[str] = Field(None, alias="phoneNumber")
    wifi_mac_address: Optional[str] = Field(None, alias="wiFiMacAddress")
    total_storage_bytes: Optional[int] = Field(None, alias="totalStorageSpaceInBytes")
    free_storage_bytes: Optional[int] = Field(None, alias="freeStorageSpaceInBytes")
    physical_memory_bytes: Optional[int] = Field(None, alias="physicalMemoryInBytes")
    jail_broken: Optional[str] = Field(None, alias="jailBroken")
    device_enrollment_type: Optional[str] = Field(None, alias="deviceEnrollmentType")
    device_category_display_name: Optional[str] = Field(
        None, alias="deviceCategoryDisplayName"
    )
    notes: Optional[str] = None
    management_certificate_expiration_date: Optional[datetime] = Field(
        None, alias="managementCertificateExpirationDate"
    )

    model_config = {"populate_by_name": True, "extra": "allow"}


class IntuneCompliancePolicy(BaseModel):
    """Device compliance policy from Intune."""

    id: str = Field(description="Policy ID (GUID)")
    display_name: Optional[str] = Field(None, alias="displayName")
    description: Optional[str] = None
    created_date_time: Optional[datetime] = Field(None, alias="createdDateTime")
    last_modified_date_time: Optional[datetime] = Field(
        None, alias="lastModifiedDateTime"
    )
    version: Optional[int] = None

    model_config = {"populate_by_name": True, "extra": "allow"}


class IntuneDeviceConfiguration(BaseModel):
    """Device configuration profile from Intune."""

    id: str = Field(description="Configuration profile ID (GUID)")
    display_name: Optional[str] = Field(None, alias="displayName")
    description: Optional[str] = None
    created_date_time: Optional[datetime] = Field(None, alias="createdDateTime")
    last_modified_date_time: Optional[datetime] = Field(
        None, alias="lastModifiedDateTime"
    )
    version: Optional[int] = None
    odata_type: Optional[str] = Field(None, alias="@odata.type")

    model_config = {"populate_by_name": True, "extra": "allow"}


class IntuneMobileApp(BaseModel):
    """Mobile app from Intune (GET /deviceAppManagement/mobileApps)."""

    id: str = Field(description="App ID (GUID)")
    display_name: Optional[str] = Field(None, alias="displayName")
    description: Optional[str] = None
    publisher: Optional[str] = None
    created_date_time: Optional[datetime] = Field(None, alias="createdDateTime")
    last_modified_date_time: Optional[datetime] = Field(
        None, alias="lastModifiedDateTime"
    )
    is_featured: Optional[bool] = Field(None, alias="isFeatured")
    is_assigned: Optional[bool] = Field(None, alias="isAssigned")
    odata_type: Optional[str] = Field(None, alias="@odata.type")

    model_config = {"populate_by_name": True, "extra": "allow"}


class IntuneActionResult(BaseModel):
    """Result tracking for a device remote action."""

    action_name: Optional[str] = Field(None, alias="actionName")
    action_state: Optional[str] = Field(None, alias="actionState")
    start_date_time: Optional[datetime] = Field(None, alias="startDateTime")
    last_updated_date_time: Optional[datetime] = Field(
        None, alias="lastUpdatedDateTime"
    )

    model_config = {"populate_by_name": True, "extra": "allow"}
