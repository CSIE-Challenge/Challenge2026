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

    PING = "ping"
    GET_ENERGY = "get_energy"
    REQUEST_TRAP = "request_trap"


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
