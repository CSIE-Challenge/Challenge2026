#!/usr/bin/env python3
"""Spawn every trap in a running Godot game through the Python API.

You start the game yourself and paste in the agent token it prints.

    # 1. Start the game (in a separate terminal, or from the editor with F5):
    godot --path . res://Scenes/main.tscn
    # It prints:  [API Server] agent 'Agent1' token: 1a2b3c4d

    # 2. Run this and give it that token:
    uv run python scripts/spawn_all_traps.py 1a2b3c4d
    # ...or run with no token and paste it when prompted.

Run from the `agent/` directorty so `uv run` resolves the `api` package.
"""

from __future__ import annotations

import argparse
import time

from api import protocol
from api.client_base import GameClientBase

# Every trap with a valid, fully-specified parameter set. Positions are spread
# out so the spawned traps don't all land on top of each other.
TRAPS: list[tuple[str, dict]] = [
    ("trap1-mine", {"position": [120.0, 80.0]}),
    ("trap2-electric_ring", {"delay_time": 1.5, "radius": 100.0}),
    (
        "trap3-tracing_bullet",
        {"position": [100.0, 0.0], "direction": [0.0, -100.0], "speed": 200.0},
    ),
    ("trap4-conveyor", {"position": [-150.0, 150.0], "direction": [1.0, 0.0]}),
    ("trap5-icefloor", {"position": [150.0, 150.0]}),
    ("trap6-scanline", {"direction": [0.0, -1.0], "speed": 100.0}),
    ("trap7-spreading_ripples", {"position": [300.0, 300.0], "expand_rate": 150.0}),
    (
        "trap8-electric_arc",
        {"start_position": [-100.0, -100.0], "end_position": [100.0, -100.0]},
    ),
    (
        "trap9-mortar",
        {
            "start_position": [200.0, 100.0],
            "end_position": [220.0, 100.0],
            "air_time": 1.0,
        },
    ),
    (
        "trap10-shotgun",
        {
            "position": [-250.0, 100.0],
            "dir1": [1.0, 0.2],
            "dir2": [1.0, 0.0],
            "dir3": [1.0, -0.2],
        },
    ),
]
# A team's energy is capped at max_energy (100), but the costliest trap is 100,
# so each trap gets its own fully-funded team and the whole set spawns.
INITIAL_ENERGY = 100.0


def _spawn_all(client: GameClientBase, delay: float) -> bool:
    # One team per trap so every trap is fully funded regardless of cost.
    team_ids = list(range(len(TRAPS)))
    init = client._call(
        protocol.Cmd.INIT_AGENT_SERVICES,
        {"team_ids": team_ids, "initial_energy": INITIAL_ENERGY},
    )
    if not init.get("ok"):
        print(f"init_agent_services failed: {init}")
        return False

    all_ok = True
    for team_id, (trap_id, params) in zip(team_ids, TRAPS):
        result = client.request_trap(team_id, trap_id, params)
        if not result.get("ok"):
            print(f"  ✗ {trap_id:18} rejected: {result.get('reason')}")
            all_ok = False
            continue
        # Scheduler processes one queued request per team per tick.
        client._call(protocol.Cmd.PROCESS_TRAP_REQUESTS, {})
        energy = client.get_team_energy(team_id)["energy"]
        print(f"  ✓ {trap_id:18} spawned   (team {team_id}, energy left: {energy:.0f})")
        time.sleep(delay)
    return all_ok


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "token",
        nargs="?",
        help="agent token printed by the running game (prompted if omitted)",
    )
    parser.add_argument(
        "--host", default="127.0.0.1", help="game host (default 127.0.0.1)"
    )
    parser.add_argument(
        "--port", type=int, default=7749, help="game port (default 7749)"
    )
    parser.add_argument(
        "--delay", type=float, default=1.2, help="seconds between traps (default 1.2)"
    )
    args = parser.parse_args()

    token = args.token or input("Agent token: ").strip()
    if not token:
        print("No token given.")
        return 2

    client = GameClientBase(token, host=args.host, port=args.port)
    try:
        client.connect()
    except Exception as exc:  # auth rejected / server not running
        print(f"Could not connect to {args.host}:{args.port} — {exc}")
        return 1

    try:
        print(f"Connected. Spawning {len(TRAPS)} traps...")
        all_ok = _spawn_all(client, args.delay)
        print(
            "\nAll traps spawned."
            if all_ok
            else "\nSome traps were rejected (see above)."
        )
        return 0 if all_ok else 1
    finally:
        client.close()


if __name__ == "__main__":
    raise SystemExit(main())
