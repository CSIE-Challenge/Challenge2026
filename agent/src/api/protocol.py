"""
Envelopes:
    state push :  {"type": "state", "tick", "round", "self": {...}, "opponent": {...}}
    request    :  {"id", "cmd": "<name>", "args": {...}}
    response   :  {"id", "status": "ok"|"error", "code"?, "data"?}
"""

from __future__ import annotations

from typing import Any


class Cmd:
    """Legal command names.

    tests/test_contract_drift.py fails the build if the two ends diverge.
    """

    # Actions.
    PING = "ping"
    HEAL = "heal"

    # Traps (one command per trap; all params required).
    SPAWN_TRAP1 = "spawn_trap1"
    SPAWN_TRAP2 = "spawn_trap2"
    SPAWN_TRAP3 = "spawn_trap3"
    SPAWN_TRAP4 = "spawn_trap4"
    SPAWN_TRAP5 = "spawn_trap5"
    SPAWN_TRAP6 = "spawn_trap6"
    SPAWN_TRAP7 = "spawn_trap7"
    SPAWN_TRAP8 = "spawn_trap8"
    SPAWN_TRAP9 = "spawn_trap9"
    SPAWN_TRAP10 = "spawn_trap10"

    # Reads.
    GET_MY_ENERGY = "get_my_energy"
    GET_MY_HEALTH = "get_my_health"
    GET_OPPONENT_PLAYER_POSITION = "get_opponent_player_position"
    GET_OPPONENT_ENERGY_BALL_POSITION = "get_opponent_energy_ball_position"


class Status:
    """Response status field values."""

    OK = "ok"
    ERROR = "error"


class Code:
    """Status codes"""

    OK = 200
    ILLFORMED = 400
    NOT_FOUND = 404


def make_request(req_id: int, cmd: str, args: dict[str, Any] | None = None) -> dict:
    """Build a request envelope."""
    return {"id": req_id, "cmd": cmd, "args": args or {}}
