"""Fast unit tests for pure-Python client logic (no server needed)."""

from __future__ import annotations

import pytest

from api.client_base import ApiError, _unwrap


def test_unwrap_returns_data_on_ok() -> None:
    assert _unwrap({"status": "ok", "data": 42}) == 42


def test_unwrap_returns_none_when_ok_without_data() -> None:
    assert _unwrap({"status": "ok"}) is None


def test_unwrap_raises_apierror_on_error() -> None:
    with pytest.raises(ApiError) as excinfo:
        _unwrap({"status": "error", "code": 404})
    assert excinfo.value.code == 404
