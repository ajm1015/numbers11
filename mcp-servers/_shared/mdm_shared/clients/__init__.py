"""API clients for MDM platforms."""

from mdm_shared.clients.kandji import KandjiClient
from mdm_shared.clients.intune import IntuneClient

__all__ = ["KandjiClient", "IntuneClient"]
