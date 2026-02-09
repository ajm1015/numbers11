"""Device audit workflow prompt."""

from mcp_mdm_hub.server import mcp


@mcp.prompt()
def device_audit(serial_number: str) -> str:
    """Generate a step-by-step device audit workflow.

    Walks through a comprehensive security and compliance audit
    for a specific device identified by serial number.

    Args:
        serial_number: The hardware serial number to audit.
    """
    return (
        f"Perform a comprehensive audit of the device with serial number {serial_number}.\n\n"
        "Follow these steps:\n"
        "1. Look up the device using mdm_get_device_by_serial\n"
        "2. Check the compliance status — flag if non-compliant or unknown\n"
        "3. Verify encryption is enabled (FileVault for macOS, BitLocker for Windows)\n"
        "4. Check the last check-in time — flag if older than 7 days\n"
        "5. Verify user assignment is correct and matches expected records\n"
        "6. Check the device OS version — flag if it's behind the latest\n"
        "7. Review the security posture (firewall, supervised mode, jailbreak status)\n"
        "8. Summarize all findings with severity levels and recommended actions"
    )
