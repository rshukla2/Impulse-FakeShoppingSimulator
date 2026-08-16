"""Shared, policy-aware HTTP client for public catalog providers."""

from __future__ import annotations

import asyncio
import random
from email.utils import parsedate_to_datetime
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Mapping, Optional

import httpx

from backend.app.config import settings


class ExternalAPIError(RuntimeError):
    def __init__(self, code: str, message: str, status_code: Optional[int] = None):
        super().__init__(message[:500])
        self.code = code
        self.status_code = status_code


def user_agent(component: str) -> str:
    return f"Impulse/1.0 ({component}; {settings.EXTERNAL_API_CONTACT})"


def _retry_delay(response: Optional[httpx.Response], attempt: int) -> float:
    if response is not None:
        value = response.headers.get("retry-after")
        if value:
            try:
                return min(float(value), 60.0)
            except ValueError:
                try:
                    parsed = parsedate_to_datetime(value)
                    return max(0.0, min((parsed - datetime.now(timezone.utc)).total_seconds(), 60.0))
                except (TypeError, ValueError):
                    value = None
    return min(2**attempt + random.random(), 30.0)


class ExternalHTTPClient:
    def __init__(self, component: str, client: Optional[httpx.AsyncClient] = None):
        self._owned = client is None
        self.client = client or httpx.AsyncClient(
            timeout=settings.EXTERNAL_API_TIMEOUT_SECONDS,
            follow_redirects=True,
            headers={"User-Agent": user_agent(component)},
        )

    async def __aenter__(self):
        return self

    async def __aexit__(self, *_args):
        if self._owned:
            await self.client.aclose()

    async def request(
        self,
        method: str,
        url: str,
        *,
        params: Optional[Mapping[str, Any]] = None,
        headers: Optional[Mapping[str, str]] = None,
        auth: Optional[httpx.Auth] = None,
    ) -> httpx.Response:
        response: Optional[httpx.Response] = None
        for attempt in range(settings.EXTERNAL_API_MAX_RETRIES + 1):
            try:
                response = await self.client.request(
                    method, url, params=params, headers=headers, auth=auth
                )
            except (httpx.TimeoutException, httpx.NetworkError) as exc:
                if attempt >= settings.EXTERNAL_API_MAX_RETRIES:
                    raise ExternalAPIError("network_error", type(exc).__name__) from exc
                await asyncio.sleep(_retry_delay(None, attempt))
                continue

            if response.status_code < 400:
                return response
            if response.status_code not in {408, 425, 429, 500, 502, 503, 504}:
                raise ExternalAPIError("http_error", f"Provider returned HTTP {response.status_code}", response.status_code)
            if attempt >= settings.EXTERNAL_API_MAX_RETRIES:
                raise ExternalAPIError("provider_unavailable", f"Provider returned HTTP {response.status_code}", response.status_code)
            await asyncio.sleep(_retry_delay(response, attempt))

        raise ExternalAPIError("provider_unavailable", "Provider request failed")

    async def get_json(self, url: str, **kwargs) -> Any:
        response = await self.request("GET", url, **kwargs)
        try:
            return response.json()
        except ValueError as exc:
            raise ExternalAPIError("invalid_json", "Provider returned invalid JSON") from exc

    async def download(self, url: str, destination: Path, **kwargs) -> None:
        """Stream a large response to disk with the same retry policy."""
        response: Optional[httpx.Response] = None
        for attempt in range(settings.EXTERNAL_API_MAX_RETRIES + 1):
            request = self.client.build_request("GET", url, **kwargs)
            try:
                response = await self.client.send(request, stream=True, follow_redirects=True)
                if response.status_code < 400:
                    with destination.open("wb") as output:
                        async for chunk in response.aiter_bytes():
                            output.write(chunk)
                    await response.aclose()
                    return
                retryable = response.status_code in {408, 425, 429, 500, 502, 503, 504}
                if not retryable or attempt >= settings.EXTERNAL_API_MAX_RETRIES:
                    status = response.status_code
                    await response.aclose()
                    raise ExternalAPIError("http_error", f"Provider returned HTTP {status}", status)
                delay = _retry_delay(response, attempt)
                await response.aclose()
                await asyncio.sleep(delay)
            except (httpx.TimeoutException, httpx.NetworkError) as exc:
                if response is not None:
                    await response.aclose()
                if attempt >= settings.EXTERNAL_API_MAX_RETRIES:
                    raise ExternalAPIError("network_error", type(exc).__name__) from exc
                await asyncio.sleep(_retry_delay(None, attempt))
        raise ExternalAPIError("provider_unavailable", "Provider download failed")
