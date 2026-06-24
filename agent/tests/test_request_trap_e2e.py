"""End-to-end request_trap flow for live Godot integration."""

from __future__ import annotations

import pytest

from api import protocol
from api.client_base import GameClientBase

pytestmark = pytest.mark.integration


def test_request_trap_reaches_approved_via_scheduler(
    client: GameClientBase,
) -> None:
    init_result = client._call(
        protocol.Cmd.INIT_AGENT_SERVICES,
        {"team_ids": [0], "initial_energy": 20},
    )
    assert init_result == {"ok": True, "team_ids": [0]}

    queue_result = client.request_trap(0, "mine", {"position": [120.0, 80.0]})
    assert queue_result == {
        "ok": True,
        "reason": "",
        "request_id": 0,
        "stage": "queued",
        "team_id": 0,
        "trap_id": "mine",
    }

    process_result = client._call(protocol.Cmd.PROCESS_TRAP_REQUESTS, {})
    assert process_result == {"ok": True}

    energy_result = client.get_team_energy(0)
    assert energy_result == {
        "ok": True,
        "team_id": 0,
        "energy": 10.0,
        "max_energy": 100.0,
        "reason": "",
    }


def test_request_trap_accepts_numeric_id_and_converts_to_canonical(
    client: GameClientBase,
) -> None:
    init_result = client._call(
        protocol.Cmd.INIT_AGENT_SERVICES,
        {"team_ids": [1], "initial_energy": 50},
    )
    assert init_result == {"ok": True, "team_ids": [1]}

    queue_result = client.request_trap(1, 1, {"position": [90.0, 60.0]})
    assert queue_result["ok"] is True
    assert queue_result["trap_id"] == "mine"
    assert queue_result["stage"] == "queued"

    process_result = client._call(protocol.Cmd.PROCESS_TRAP_REQUESTS, {})
    assert process_result == {"ok": True}
