"""Fast unit tests for pure-Python client logic (no server needed)."""

from __future__ import annotations

import pytest

from api import serialization
from api.client_base import ApiError, _unwrap
from api.structures import Direction, Vector2


def test_unwrap_returns_data_on_ok() -> None:
    assert _unwrap({"status": "ok", "data": 42}) == 42


def test_unwrap_returns_none_when_ok_without_data() -> None:
    assert _unwrap({"status": "ok"}) is None


def test_unwrap_returns_falsy_apierror_on_error() -> None:
    result = _unwrap(
        {"status": "error", "code": 409, "reason": "insufficient_energy"},
        "spawn_trap1",
    )
    assert isinstance(result, ApiError)
    assert not result  # falsy: `if not result:` is the documented pattern
    assert result.code == 409
    assert result.cmd == "spawn_trap1"
    assert result.reason == "insufficient_energy"


def test_unwrap_never_raises() -> None:
    result = _unwrap({"status": "error", "code": 404})
    assert isinstance(result, ApiError)


def test_unwrap_prints_warning_by_default(capsys: pytest.CaptureFixture) -> None:
    _unwrap({"status": "error", "code": 409, "reason": "insufficient_energy"}, "heal")
    assert "[api] heal failed: insufficient_energy (409)" in capsys.readouterr().out


def test_unwrap_warn_false_is_silent(capsys: pytest.CaptureFixture) -> None:
    result = _unwrap({"status": "error", "code": 409}, "heal", warn=False)
    assert isinstance(result, ApiError)
    assert capsys.readouterr().out == ""


def test_apierror_message_is_readable_and_names_the_command() -> None:
    err = ApiError(409, "spawn_trap1", "insufficient_energy")
    assert str(err) == "spawn_trap1 failed: insufficient_energy (409)"


def test_apierror_reason_falls_back_to_code_message() -> None:
    err = ApiError(404, "get_my_energy")
    assert err.reason == "unknown_command"
    assert str(err) == "get_my_energy failed: unknown_command (404)"


def test_encode_serializes_vector2_and_direction_as_xy() -> None:
    import json

    payload = {"position": Vector2(1.0, 2.0), "direction": Direction.RIGHT}
    assert json.loads(serialization.encode(payload)) == {
        "position": [1.0, 2.0],
        "direction": [1.0, 0.0],
    }


def test_encode_rejects_unknown_types() -> None:
    with pytest.raises(TypeError):
        serialization.encode({"bad": object()})


def test_vector2_from_list_round_trips() -> None:
    vec = Vector2.from_list([5.0, 6.0])
    assert (vec.x, vec.y) == (5.0, 6.0)
    assert list(vec) == [5.0, 6.0]
