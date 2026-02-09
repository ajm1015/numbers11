"""Pydantic models for Kandji API responses."""

from datetime import datetime
from typing import Any, Optional

from pydantic import BaseModel, Field


class KandjiDevice(BaseModel):
    """Summary device record from Kandji list endpoint (GET /v1/devices)."""

    device_id: str = Field(description="Unique Kandji device identifier")
    device_name: Optional[str] = Field(None, description="Device display name")
    serial_number: Optional[str] = Field(None, description="Hardware serial number")
    platform: Optional[str] = Field(None, description="Platform: Mac, iPhone, iPad, AppleTV")
    model: Optional[str] = Field(None, description="Device model name")
    os_version: Optional[str] = Field(None, description="Operating system version")
    last_check_in: Optional[str] = Field(None, description="Last MDM check-in timestamp")
    blueprint_id: Optional[str] = Field(None, description="Assigned blueprint UUID")
    blueprint_name: Optional[str] = Field(None, description="Assigned blueprint name")
    asset_tag: Optional[str] = Field(None, description="Asset tag")
    user: Optional[dict[str, Any]] = Field(None, description="Assigned user info")
    mdm_enabled: Optional[bool] = Field(None, description="Whether MDM is enabled")

    model_config = {"extra": "allow"}


class KandjiDeviceDetails(BaseModel):
    """Full device detail record from Kandji (GET /v1/devices/{id}/details).

    The details endpoint returns a nested structure with sections like
    hardware_overview, filevault, activation_lock, etc.
    We store the full response and provide typed access to key fields.
    """

    general: Optional[dict[str, Any]] = None
    hardware_overview: Optional[dict[str, Any]] = None
    volumes: Optional[list[dict[str, Any]]] = None
    network: Optional[dict[str, Any]] = None
    filevault: Optional[dict[str, Any]] = None
    activation_lock: Optional[dict[str, Any]] = None
    security_information: Optional[dict[str, Any]] = None
    recovery_information: Optional[dict[str, Any]] = None
    users: Optional[list[dict[str, Any]]] = None
    installed_profiles: Optional[list[dict[str, Any]]] = None
    kandji_agent: Optional[dict[str, Any]] = None
    automated_device_enrollment: Optional[dict[str, Any]] = None

    model_config = {"extra": "allow"}


class KandjiBlueprint(BaseModel):
    """Blueprint record from Kandji (GET /v1/blueprints)."""

    id: str = Field(description="Blueprint UUID")
    name: str = Field(description="Blueprint name")
    description: Optional[str] = Field(None, description="Blueprint description")
    enrollment_code_is_active: Optional[bool] = None
    enrollment_code: Optional[str] = None

    model_config = {"extra": "allow"}


class KandjiApp(BaseModel):
    """App record from device apps endpoint (GET /v1/devices/{id}/apps)."""

    app_name: Optional[str] = Field(None, description="Application name")
    version: Optional[str] = Field(None, description="Installed version")
    bundle_id: Optional[str] = Field(None, description="Bundle identifier")
    path: Optional[str] = Field(None, description="Install path")

    model_config = {"extra": "allow"}


class KandjiCustomApp(BaseModel):
    """Custom app library item from Kandji (GET /v1/library/custom-apps)."""

    id: Optional[str] = Field(None, description="Library item UUID")
    name: Optional[str] = Field(None, description="Custom app name")
    active: Optional[bool] = Field(None, description="Whether the app is active")
    install_type: Optional[str] = Field(None, description="Installation type")
    install_enforcement: Optional[str] = Field(None, description="Enforcement policy")
    show_in_self_service: Optional[bool] = None

    model_config = {"extra": "allow"}


class KandjiActionResponse(BaseModel):
    """Response from a device action endpoint."""

    success: Optional[bool] = None
    message: Optional[str] = None
    unlock_pin: Optional[str] = Field(None, description="Unlock PIN (returned by lock action)")

    model_config = {"extra": "allow"}
