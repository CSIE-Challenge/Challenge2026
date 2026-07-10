"""Behaviour tests for the live API.

These boot a real Godot server (via the ``client`` fixture in conftest.py) and
talk to it the way a teammate's agent code would: through the high-level
GameClientBase methods. Run with ``pytest`` (needs Godot); skip with
``pytest -m 'not integration'``.
"""

from __future__ import annotations

import pytest

from api.client_base import ApiError, GameClientBase

pytestmark = pytest.mark.integration


def test_ping_returns_pong(client: GameClientBase) -> None:
    assert client.ping() == "pong"


def test_unknown_command_raises_not_found(client: GameClientBase) -> None:
    with pytest.raises(ApiError) as excinfo:
        client._call("does_not_exist")
    assert excinfo.value.code == 404


def test_heal_refused_when_energy_too_low(client: GameClientBase) -> None:
    """A freshly booted game starts near-zero energy, so heal is refused for lack of it.

    Exercises the whole live path (Python -> API -> GameAgent -> AgentActionService ->
    NetworkManager) and proves heal reads the REAL energy, not the old phantom ledger.
    """
    result = client.heal()
    assert result["ok"] is False
    assert result["reason"] == "insufficient_energy"


def test_heal_reports_real_player_health(client: GameClientBase) -> None:
    """A refused heal must not touch health, and must report the same live player.health
    that get_my_health() returns."""
    before = client.get_my_health()
    result = client.heal()
    assert result["health"] == before
    assert client.get_my_health() == before


def test_get_opponent_velocity_shape(client: GameClientBase) -> None:
    velocity = client.get_opponent_player_velocity()
    assert isinstance(velocity, list)
    assert len(velocity) == 2


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
        assert isinstance(trap_id, str)
        assert trap_id.startswith("trap")


def test_get_cool_down_time(client: GameClientBase) -> None:
    result = client.get_cool_down_time("trap1-mine")
    assert isinstance(result, (int, float))
    assert result >= 0.0


def test_get_cool_down_time_invalid_trap_id_is_negative(client: GameClientBase) -> None:
    result = client.get_cool_down_time("not-a-trap")
    assert isinstance(result, (int, float))
    assert result < 0
