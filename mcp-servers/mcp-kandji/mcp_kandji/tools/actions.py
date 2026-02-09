"""Kandji device action tools.

IMPORTANT: Destructive actions (erase) include explicit warnings in their
descriptions so the LLM surfaces confirmation to the user before execution.
"""

from typing import Optional

from mcp_kandji.server import kandji_client, mcp


@mcp.tool()
async def kandji_send_blankpush(device_id: str) -> str:
    """Send a blank push to trigger an MDM check-in on a Kandji device.

    This is non-destructive and simply verifies APNs connectivity.

    Args:
        device_id: The Kandji device UUID.
    """
    result = await kandji_client.send_device_action(device_id, "blankpush")
    return f"Blank push sent to device {device_id}. {result.message or ''}"


@mcp.tool()
async def kandji_update_inventory(device_id: str) -> str:
    """Trigger an inventory update for a Kandji device.

    Non-destructive. Forces the device to report updated inventory data.

    Args:
        device_id: The Kandji device UUID.
    """
    result = await kandji_client.send_device_action(device_id, "updateinventory")
    return f"Inventory update triggered for device {device_id}. {result.message or ''}"


@mcp.tool()
async def kandji_renew_mdm_profile(device_id: str) -> str:
    """Renew the root MDM profile on a Kandji device.

    Reinstalls the MDM management profile. Non-destructive but may briefly
    interrupt management connectivity.

    Args:
        device_id: The Kandji device UUID.
    """
    result = await kandji_client.send_device_action(device_id, "renewmdmprofile")
    return f"MDM profile renewal initiated for device {device_id}. {result.message or ''}"


@mcp.tool()
async def kandji_lock_device(device_id: str, pin: str) -> str:
    """Lock a Kandji device with a 6-digit PIN code.

    CAUTION: This will immediately lock the device. The user will need the PIN
    to unlock it. Use only when instructed.

    Args:
        device_id: The Kandji device UUID.
        pin: A 6-digit numeric PIN for unlocking the device.
    """
    if not pin.isdigit() or len(pin) != 6:
        return "Error: PIN must be exactly 6 digits."

    result = await kandji_client.send_device_action(
        device_id, "lock", payload={"PIN": pin}
    )
    unlock_info = f" Unlock PIN: {result.unlock_pin}" if result.unlock_pin else ""
    return f"Lock command sent to device {device_id}.{unlock_info}"


@mcp.tool()
async def kandji_restart_device(device_id: str) -> str:
    """Restart a Kandji device remotely.

    The device will restart at the next MDM check-in.

    Args:
        device_id: The Kandji device UUID.
    """
    result = await kandji_client.send_device_action(device_id, "restart")
    return f"Restart command sent to device {device_id}. {result.message or ''}"


@mcp.tool()
async def kandji_shutdown_device(device_id: str) -> str:
    """Shut down a Kandji device remotely.

    Args:
        device_id: The Kandji device UUID.
    """
    result = await kandji_client.send_device_action(device_id, "shutdown")
    return f"Shutdown command sent to device {device_id}. {result.message or ''}"


@mcp.tool()
async def kandji_erase_device(device_id: str, pin: str) -> str:
    """**DESTRUCTIVE: Factory reset a Kandji device.**

    This erases ALL data on the device and cannot be undone. The device will
    be completely wiped and returned to factory settings. Only use this when
    explicitly instructed by the user.

    A 6-digit PIN is required and will be set as the device lock screen PIN
    after the erase completes.

    Args:
        device_id: The Kandji device UUID.
        pin: A 6-digit numeric PIN for the device after erase.
    """
    if not pin.isdigit() or len(pin) != 6:
        return "Error: PIN must be exactly 6 digits."

    result = await kandji_client.send_device_action(
        device_id, "erase", payload={"PIN": pin}
    )
    return (
        f"ERASE command sent to device {device_id}. "
        f"The device will be factory reset. This cannot be undone. "
        f"{result.message or ''}"
    )
