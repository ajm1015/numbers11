"""Azure AD OAuth2 client credentials authentication for Microsoft Graph API."""

import logging
import time

import httpx

logger = logging.getLogger(__name__)

TOKEN_URL_TEMPLATE = "https://login.microsoftonline.com/{tenant_id}/oauth2/v2.0/token"
GRAPH_SCOPE = "https://graph.microsoft.com/.default"
TOKEN_EXPIRY_BUFFER_SECONDS = 60


class AzureAuthError(Exception):
    """Raised when Azure AD token acquisition fails."""

    def __init__(self, message: str, status_code: int | None = None) -> None:
        super().__init__(message)
        self.status_code = status_code


class AzureADAuth:
    """OAuth2 client credentials flow for Microsoft Graph API.

    Acquires and caches access tokens, auto-refreshing before expiry.
    """

    def __init__(
        self,
        tenant_id: str,
        client_id: str,
        client_secret: str,
    ) -> None:
        self._tenant_id = tenant_id
        self._client_id = client_id
        self._client_secret = client_secret
        self._token_url = TOKEN_URL_TEMPLATE.format(tenant_id=tenant_id)
        self._access_token: str | None = None
        self._token_expiry: float = 0.0

    @property
    def is_token_valid(self) -> bool:
        """Check if the current token is still valid (with buffer)."""
        return (
            self._access_token is not None
            and time.monotonic() < self._token_expiry
        )

    async def get_token(self, client: httpx.AsyncClient) -> str:
        """Get a valid access token, refreshing if needed."""
        if self.is_token_valid:
            return self._access_token  # type: ignore[return-value]

        return await self._acquire_token(client)

    async def _acquire_token(self, client: httpx.AsyncClient) -> str:
        """Acquire a new access token from Azure AD."""
        logger.info("Acquiring new Azure AD access token for tenant %s", self._tenant_id)

        data = {
            "client_id": self._client_id,
            "scope": GRAPH_SCOPE,
            "client_secret": self._client_secret,
            "grant_type": "client_credentials",
        }

        try:
            response = await client.post(
                self._token_url,
                data=data,
                headers={"Content-Type": "application/x-www-form-urlencoded"},
            )
        except httpx.HTTPError as exc:
            raise AzureAuthError(f"Token request failed: {exc}") from exc

        if response.status_code != 200:
            body = response.text
            raise AzureAuthError(
                f"Token acquisition failed (HTTP {response.status_code}): {body}",
                status_code=response.status_code,
            )

        token_data = response.json()
        self._access_token = token_data["access_token"]
        expires_in = int(token_data.get("expires_in", 3600))
        self._token_expiry = time.monotonic() + expires_in - TOKEN_EXPIRY_BUFFER_SECONDS

        logger.info(
            "Azure AD token acquired, expires in %d seconds (buffered to %d)",
            expires_in,
            expires_in - TOKEN_EXPIRY_BUFFER_SECONDS,
        )
        return self._access_token

    def invalidate(self) -> None:
        """Force token refresh on next request."""
        self._access_token = None
        self._token_expiry = 0.0
