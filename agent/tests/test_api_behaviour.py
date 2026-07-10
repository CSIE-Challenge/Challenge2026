"""Behaviour tests for the live API.

These boot a real Godot server (via the ``client`` fixture in conftest.py) and
talk to it the way a teammate's agent code would: through the high-level
GameClientBase methods. Run with ``pytest`` (needs Godot); skip with
``pytest -m 'not integration'``.
"""

from __future__ import annotations

import pytest

from api.client_base import ApiError, GameClientBase
from api.structures import Vector2

pytestmark = pytest.mark.integration


def test_ping_returns_pong(client: GameClientBase) -> None:
    assert client.ping() == "pong"


def test_unknown_command_returns_falsy_apierror(client: GameClientBase) -> None:
    result = client._call("does_not_exist")
    assert isinstance(result, ApiError)
    assert not result
    assert result.code == 404
    assert result.reason == "unknown_command"


def test_heal_refused_when_energy_too_low(client: GameClientBase) -> None:
    """A freshly booted game starts near-zero energy, so heal is refused for lack of it.

    Exercises the whole live path (Python -> API -> GameAgent -> AgentActionService ->
    NetworkManager) and proves heal reads the REAL energy, not the old phantom ledger.
    """
    result = client.heal()
    assert not result
    assert result.reason == "insufficient_energy"


def test_refused_heal_does_not_touch_health(client: GameClientBase) -> None:
    before = client.get_my_health()
    result = client.heal()
    assert not result
    assert client.get_my_health() == before


def test_get_opponent_velocity_shape(client: GameClientBase) -> None:
    velocity = client.get_opponent_player_velocity()
    assert isinstance(velocity, Vector2)
    assert list(velocity) == [velocity.x, velocity.y]


def test_get_remaining_time_and_phase(client: GameClientBase) -> None:
    remaining = client.get_remaining_time()
    phase = client.get_phase()
    assert isinstance(remaining, (int, float))
    assert remaining >= 0
    assert isinstance(phase, int)
    assert phase >= 0


def test_get_opponent_combo_and_available_traps(client: GameClientBase) -> None:
    combo = client.get_opponent_combo()
    assert isinstance(combo, int)
    assert combo >= 0

    traps = client.get_available_traps()
    assert isinstance(traps, list)
    for trap_id in traps:
        assert isinstance(trap_id, int)
        assert 1 <= trap_id <= 10


def test_get_cool_down_time(client: GameClientBase) -> None:
    result = client.get_cool_down_time(1)
    assert isinstance(result, (int, float))
    assert result >= 0.0


def test_get_cool_down_time_unknown_trap_is_apierror(client: GameClientBase) -> None:
    result = client.get_cool_down_time(99)
    assert isinstance(result, ApiError)
    assert not result
    assert result.code == 404
    assert result.reason == "unknown_trap"
