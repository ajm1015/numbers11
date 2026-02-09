"""Tests for Azure AD OAuth2 authentication."""

import pytest
import httpx
import respx

from mdm_shared.auth.azure import AzureADAuth, AzureAuthError


TENANT_ID = "test-tenant-id"
CLIENT_ID = "test-client-id"
CLIENT_SECRET = "test-client-secret"
TOKEN_URL = f"https://login.microsoftonline.com/{TENANT_ID}/oauth2/v2.0/token"


@pytest.fixture
def auth() -> AzureADAuth:
    return AzureADAuth(
        tenant_id=TENANT_ID,
        client_id=CLIENT_ID,
        client_secret=CLIENT_SECRET,
    )


@pytest.mark.asyncio
class TestAzureADAuth:
    @respx.mock
    async def test_acquire_token_success(self, auth: AzureADAuth) -> None:
        respx.post(TOKEN_URL).mock(
            return_value=httpx.Response(
                200,
                json={
                    "access_token": "test-token-123",
                    "token_type": "Bearer",
                    "expires_in": 3600,
                },
            )
        )

        async with httpx.AsyncClient() as client:
            token = await auth.get_token(client)

        assert token == "test-token-123"
        assert auth.is_token_valid

    @respx.mock
    async def test_cached_token_reused(self, auth: AzureADAuth) -> None:
        route = respx.post(TOKEN_URL).mock(
            return_value=httpx.Response(
                200,
                json={
                    "access_token": "cached-token",
                    "token_type": "Bearer",
                    "expires_in": 3600,
                },
            )
        )

        async with httpx.AsyncClient() as client:
            token1 = await auth.get_token(client)
            token2 = await auth.get_token(client)

        assert token1 == token2 == "cached-token"
        assert route.call_count == 1  # Only one HTTP call

    @respx.mock
    async def test_token_acquisition_failure(self, auth: AzureADAuth) -> None:
        respx.post(TOKEN_URL).mock(
            return_value=httpx.Response(
                401,
                json={"error": "invalid_client", "error_description": "Bad credentials"},
            )
        )

        async with httpx.AsyncClient() as client:
            with pytest.raises(AzureAuthError) as exc_info:
                await auth.get_token(client)

        assert exc_info.value.status_code == 401

    @respx.mock
    async def test_token_acquisition_network_error(self, auth: AzureADAuth) -> None:
        respx.post(TOKEN_URL).mock(side_effect=httpx.ConnectError("Connection refused"))

        async with httpx.AsyncClient() as client:
            with pytest.raises(AzureAuthError, match="Token request failed"):
                await auth.get_token(client)

    def test_invalidate_clears_token(self, auth: AzureADAuth) -> None:
        assert not auth.is_token_valid
        auth.invalidate()
        assert not auth.is_token_valid

    def test_initial_state_is_invalid(self, auth: AzureADAuth) -> None:
        assert not auth.is_token_valid
