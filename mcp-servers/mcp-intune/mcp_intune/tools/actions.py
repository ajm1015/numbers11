"""Intune device action tools.

IMPORTANT: Destructive actions (retire, wipe) include explicit warnings
in their descriptions so the LLM surfaces confirmation to the user.
"""

from mcp_intune.server import intune_client, mcp


@mcp.tool()
async def intune_sync_device(device_id: str) -> str:
    """Trigger an Intune sync for a managed device.

    Non-destructive. Forces the device to check in with Intune and
    apply any pending policies or configuration changes.

    Args:
        device_id: The Intune device ID (GUID).
    """
    success = await intune_client.send_device_action(device_id, "syncDevice")
    if success:
        return f"Sync command sent to device {device_id}. The device will sync at next check-in."
    return f"Failed to send sync command to device {device_id}."


@mcp.tool()
async def intune_reboot_device(device_id: str) -> str:
    """Reboot an Intune managed device remotely.

    The device will reboot within approximately 5 minutes when online.

    Args:
        device_id: The Intune device ID (GUID).
    """
    success = await intune_client.send_device_action(device_id, "rebootNow")
    if success:
        return f"Reboot command sent to device {device_id}."
    return f"Failed to send reboot command to device {device_id}."


@mcp.tool()
async def intune_lock_device(device_id: str) -> str:
    """Remotely lock an Intune managed device.

    CAUTION: This immediately locks the device screen.

    Args:
        device_id: The Intune device ID (GUID).
    """
    success = await intune_client.send_device_action(device_id, "remoteLock")
    if success:
        return f"Lock command sent to device {device_id}."
    return f"Failed to send lock command to device {device_id}."


@mcp.tool()
async def intune_shutdown_device(device_id: str) -> str:
    """Shut down an Intune managed device remotely.

    Args:
        device_id: The Intune device ID (GUID).
    """
    success = await intune_client.send_device_action(device_id, "shutdown")
    if success:
        return f"Shutdown command sent to device {device_id}."
    return f"Failed to send shutdown command to device {device_id}."


@mcp.tool()
async def intune_retire_device(device_id: str) -> str:
    """**DESTRUCTIVE: Remove company data and MDM management from a device.**

    This removes all company apps, data, and the MDM management profile.
    Personal data is retained. This cannot be easily undone — the device
    would need to be re-enrolled. Only use when explicitly instructed.

    Args:
        device_id: The Intune device ID (GUID).
    """
    success = await intune_client.send_device_action(device_id, "retire")
    if success:
        return (
            f"RETIRE command sent to device {device_id}. "
            f"Company data and MDM management will be removed. "
            f"The device will need to be re-enrolled to manage again."
        )
    return f"Failed to send retire command to device {device_id}."


@mcp.tool()
async def intune_wipe_device(
    device_id: str,
    keep_user_data: bool = False,
) -> str:
    """**DESTRUCTIVE: Factory reset an Intune managed device.**

    This erases ALL data on the device (or optionally keeps user data)
    and cannot be undone. The device will be returned to factory settings.
    Only use when explicitly instructed.

    Args:
        device_id: The Intune device ID (GUID).
        keep_user_data: If True, preserves user data during wipe. Default: False.
    """
    payload = {
        "keepEnrollmentData": False,
        "keepUserData": keep_user_data,
    }
    success = await intune_client.send_device_action(device_id, "wipe", payload=payload)
    if success:
        data_note = "User data will be preserved." if keep_user_data else "ALL data will be erased."
        return (
            f"WIPE command sent to device {device_id}. "
            f"The device will be factory reset. {data_note} "
            f"This cannot be undone."
        )
    return f"Failed to send wipe command to device {device_id}."
