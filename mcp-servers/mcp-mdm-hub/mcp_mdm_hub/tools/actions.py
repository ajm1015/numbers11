"""Unified device action tools — routes commands to the correct MDM."""

from typing import Optional

from mcp_mdm_hub.models.unified import DeviceActionResult, DeviceSource
from mcp_mdm_hub.server import intune_client, kandji_client, mcp


async def _dispatch_kandji_action(
    source_id: str, action: str, payload: dict | None = None
) -> DeviceActionResult:
    """Send an action to a Kandji device."""
    result = await kandji_client.send_device_action(source_id, action, payload)
    return DeviceActionResult(
        source=DeviceSource.KANDJI,
        source_id=source_id,
        action=action,
        success=result.success or False,
        message=result.message or f"Action '{action}' sent.",
    )


async def _dispatch_intune_action(
    source_id: str, action: str, payload: dict | None = None
) -> DeviceActionResult:
    """Send an action to an Intune device."""
    success = await intune_client.send_device_action(source_id, action, payload)
    return DeviceActionResult(
        source=DeviceSource.INTUNE,
        source_id=source_id,
        action=action,
        success=success,
        message=f"Action '{action}' {'sent' if success else 'failed'}.",
    )


def _validate_source(source: str) -> DeviceSource:
    """Validate and return the DeviceSource enum."""
    try:
        return DeviceSource(source.lower())
    except ValueError:
        raise ValueError(f"Invalid source '{source}'. Must be 'kandji' or 'intune'.")


@mcp.tool()
async def mdm_sync_device(source: str, source_id: str) -> str:
    """Trigger an MDM sync/check-in on a device.

    Routes to the correct MDM: blankpush for Kandji, syncDevice for Intune.
    Non-destructive.

    Args:
        source: MDM source (kandji or intune).
        source_id: Device ID in the source MDM.
    """
    device_source = _validate_source(source)

    if device_source == DeviceSource.KANDJI:
        result = await _dispatch_kandji_action(source_id, "blankpush")
    else:
        result = await _dispatch_intune_action(source_id, "syncDevice")

    return f"[{result.source.value.upper()}] Sync: {result.message}"


@mcp.tool()
async def mdm_lock_device(
    source: str, source_id: str, pin: Optional[str] = None
) -> str:
    """Lock a device, routing to the correct MDM.

    PIN is required for Kandji (6-digit). Intune does not require a PIN.

    Args:
        source: MDM source (kandji or intune).
        source_id: Device ID in the source MDM.
        pin: 6-digit PIN (required for Kandji, ignored for Intune).
    """
    device_source = _validate_source(source)

    if device_source == DeviceSource.KANDJI:
        if not pin or not pin.isdigit() or len(pin) != 6:
            return "Error: Kandji lock requires a 6-digit PIN."
        result = await _dispatch_kandji_action(source_id, "lock", {"PIN": pin})
    else:
        result = await _dispatch_intune_action(source_id, "remoteLock")

    return f"[{result.source.value.upper()}] Lock: {result.message}"


@mcp.tool()
async def mdm_restart_device(source: str, source_id: str) -> str:
    """Restart a device, routing to the correct MDM.

    Args:
        source: MDM source (kandji or intune).
        source_id: Device ID in the source MDM.
    """
    device_source = _validate_source(source)

    if device_source == DeviceSource.KANDJI:
        result = await _dispatch_kandji_action(source_id, "restart")
    else:
        result = await _dispatch_intune_action(source_id, "rebootNow")

    return f"[{result.source.value.upper()}] Restart: {result.message}"


@mcp.tool()
async def mdm_erase_device(
    source: str, source_id: str, pin: Optional[str] = None
) -> str:
    """**DESTRUCTIVE: Factory reset a device via the correct MDM.**

    This erases ALL data on the device and cannot be undone. Only use
    when explicitly instructed by the user.

    Args:
        source: MDM source (kandji or intune).
        source_id: Device ID in the source MDM.
        pin: 6-digit PIN (required for Kandji, ignored for Intune).
    """
    device_source = _validate_source(source)

    if device_source == DeviceSource.KANDJI:
        if not pin or not pin.isdigit() or len(pin) != 6:
            return "Error: Kandji erase requires a 6-digit PIN."
        result = await _dispatch_kandji_action(source_id, "erase", {"PIN": pin})
    else:
        result = await _dispatch_intune_action(
            source_id, "wipe", {"keepEnrollmentData": False, "keepUserData": False}
        )

    return (
        f"[{result.source.value.upper()}] ERASE: {result.message} "
        f"The device will be factory reset. This cannot be undone."
    )
