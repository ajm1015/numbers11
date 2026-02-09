"""Fleet-level analytics tools."""

from mcp_mdm_hub.server import aggregator, mcp


@mcp.tool()
async def mdm_fleet_summary() -> str:
    """Get aggregate fleet statistics across all connected MDMs.

    Returns total device count and breakdowns by source, platform,
    compliance status, and ownership type.
    """
    summary = await aggregator.fleet_summary()

    lines = [
        f"Fleet Summary ({summary.total_devices} total devices)",
        "=" * 50,
        "\nBy Source:",
    ]
    for source, count in sorted(summary.by_source.items()):
        lines.append(f"  {source}: {count}")

    lines.append("\nBy Platform:")
    for platform, count in sorted(summary.by_platform.items(), key=lambda x: -x[1]):
        lines.append(f"  {platform}: {count}")

    lines.append("\nBy Compliance:")
    for status, count in sorted(summary.by_compliance.items()):
        lines.append(f"  {status}: {count}")

    lines.append("\nBy Ownership:")
    for ownership, count in sorted(summary.by_ownership.items()):
        lines.append(f"  {ownership}: {count}")

    return "\n".join(lines)


@mcp.tool()
async def mdm_compare_platforms() -> str:
    """Compare device data across MDM platforms.

    Shows fleet-wide statistics comparing Kandji vs Intune coverage,
    platform distribution, and compliance rates.
    """
    summary = await aggregator.fleet_summary()

    lines = [
        "Cross-Platform Comparison",
        "=" * 50,
    ]

    # Source comparison
    kandji_count = summary.by_source.get("kandji", 0)
    intune_count = summary.by_source.get("intune", 0)
    lines.append(f"\nKandji: {kandji_count} devices")
    lines.append(f"Intune: {intune_count} devices")

    # Compliance comparison
    compliant = summary.by_compliance.get("compliant", 0)
    noncompliant = summary.by_compliance.get("noncompliant", 0)
    total = summary.total_devices

    if total > 0:
        compliance_rate = (compliant / total) * 100
        lines.append(f"\nCompliance Rate: {compliance_rate:.1f}%")
        lines.append(f"  Compliant: {compliant}")
        lines.append(f"  Non-compliant: {noncompliant}")
        lines.append(f"  Unknown/N/A: {total - compliant - noncompliant}")

    return "\n".join(lines)
