"""Fast unit tests for pure-Python client logic (no server needed)."""

from __future__ import annotations

import pytest

from api.client_base import ApiError, _normalize_trap_id, _unwrap


def test_unwrap_returns_data_on_ok() -> None:
    assert _unwrap({"status": "ok", "data": 42}) == 42


def test_unwrap_returns_none_when_ok_without_data() -> None:
    assert _unwrap({"status": "ok"}) is None


def test_unwrap_raises_apierror_on_error() -> None:
    with pytest.raises(ApiError) as excinfo:
        _unwrap({"status": "error", "code": 404})
    assert excinfo.value.code == 404


def test_normalize_trap_id_accepts_number_or_string() -> None:
    assert _normalize_trap_id(1) == "mine"
    assert _normalize_trap_id(9) == "mortar"
    assert _normalize_trap_id("mine") == "mine"
    assert _normalize_trap_id("scanline") == "scanline"
    assert _normalize_trap_id("10") == "shotgun"


def test_normalize_trap_id_rejects_unknown_inputs() -> None:
    with pytest.raises(ValueError):
        _normalize_trap_id(99)

    with pytest.raises(TypeError):
        _normalize_trap_id({})

    with pytest.raises(TypeError):
        _normalize_trap_id([])

    with pytest.raises(TypeError):
        _normalize_trap_id("trap8-electric_arc")
