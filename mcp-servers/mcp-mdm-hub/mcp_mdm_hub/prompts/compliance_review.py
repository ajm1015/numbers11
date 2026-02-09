"""Fleet compliance review workflow prompt."""

from typing import Optional

from mcp_mdm_hub.server import mcp


@mcp.prompt()
def compliance_review(platform: Optional[str] = None) -> str:
    """Generate a fleet-wide compliance review workflow.

    Walks through aggregate compliance analysis across all connected
    MDM platforms with prioritized remediation recommendations.

    Args:
        platform: Optional platform filter (macOS, Windows, iOS, etc.). Defaults to all.
    """
    platform_note = f"(platform: {platform})" if platform else "(all platforms)"

    return (
        f"Review compliance status across the entire fleet {platform_note}.\n\n"
        "Follow these steps:\n"
        "1. Get the fleet summary using mdm_fleet_summary\n"
        "2. Identify all non-compliant devices using mdm_list_all_devices\n"
        "3. For each non-compliant device:\n"
        "   a. Check encryption status\n"
        "   b. Check last sync time (flag if >7 days)\n"
        "   c. Check OS version currency\n"
        "   d. Identify the specific compliance issue\n"
        "4. Group findings by platform and issue type\n"
        "5. Prioritize remediation:\n"
        "   - Critical: Unencrypted devices, jailbroken devices\n"
        "   - High: Stale devices (no check-in >30 days)\n"
        "   - Medium: Outdated OS versions\n"
        "   - Low: Missing user assignments\n"
        "6. Generate a summary report with:\n"
        "   - Overall compliance rate\n"
        "   - Top issues by frequency\n"
        "   - Specific remediation steps per device\n"
        "   - Recommended policy changes"
    )
