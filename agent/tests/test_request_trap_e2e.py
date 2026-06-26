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


def test_request_trap_accepts_numeric_id_and_resolves_to_official_name(
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


def test_request_trap_supports_new_trap_refactors(
    client: GameClientBase,
) -> None:
    init_result = client._call(
        protocol.Cmd.INIT_AGENT_SERVICES,
        {"team_ids": [0, 1, 2], "initial_energy": 300},
    )
    assert init_result == {"ok": True, "team_ids": [0, 1, 2]}

    electric_arc_result = client.request_trap(
        0,
        "electric_arc",
        {
            "start_position": [100.0, 100.0],
            "end_position": [200.0, 100.0],
        },
    )
    assert electric_arc_result == {
        "ok": True,
        "reason": "",
        "request_id": 0,
        "stage": "queued",
        "team_id": 0,
        "trap_id": "electric_arc",
    }

    assert client._call(protocol.Cmd.PROCESS_TRAP_REQUESTS, {}) == {"ok": True}
    energy_arc = client.get_team_energy(0)
    assert energy_arc["team_id"] == 0
    assert energy_arc["energy"] < energy_arc["max_energy"]

    scanline_result = client.request_trap(
        1,
        "scanline",
        {
            "direction": [0.0, -1.0],
        },
    )
    assert scanline_result == {
        "ok": True,
        "reason": "",
        "request_id": 1,
        "stage": "queued",
        "team_id": 1,
        "trap_id": "scanline",
    }

    assert client._call(protocol.Cmd.PROCESS_TRAP_REQUESTS, {}) == {"ok": True}
    energy_scanline = client.get_team_energy(1)
    assert energy_scanline["team_id"] == 1
    assert energy_scanline["energy"] < energy_scanline["max_energy"]

    mortar_result = client.request_trap(
        2,
        9,
        {
            "start_position": [300.0, 100.0],
            "end_position": [320.0, 100.0],
            "air_time": 0.5,
        },
    )
    assert mortar_result == {
        "ok": True,
        "reason": "",
        "request_id": 2,
        "stage": "queued",
        "team_id": 2,
        "trap_id": "mortar",
    }

    process_result = client._call(protocol.Cmd.PROCESS_TRAP_REQUESTS, {})
    assert process_result == {"ok": True}

    energy_mortar = client.get_team_energy(2)
    assert energy_mortar["team_id"] == 2
    assert energy_mortar["energy"] < energy_mortar["max_energy"]
