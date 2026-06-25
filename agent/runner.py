#!/usr/bin/env python3
"""Bundle entrypoint: connect to the game and hand the player's agent a client.

The launcher spawns the bundled interpreter on this file with CHALLENGE_WS_URL
and CHALLENGE_TOKEN in the environment. We wait for the server port to open,
connect, import the player's agent.py (next to this file), and call run(client).
"""

from __future__ import annotations

import importlib.util
import os
import socket
import sys
import time
from pathlib import Path
from types import ModuleType

from api.client_base import GameClientBase

_PORT_WAIT_SEC = 30.0
_PROBE_INTERVAL_SEC = 0.3


def _wait_for_port(host: str, port: int, timeout: float) -> None:
    """Block until host:port accepts a TCP connection, or raise on timeout."""
    deadline = time.monotonic() + timeout
    while True:
        try:
            with socket.create_connection((host, port), timeout=1.0):
                return
        except OSError:
            if time.monotonic() >= deadline:
                raise TimeoutError(
                    f"game server at {host}:{port} not reachable within {timeout:.0f}s"
                ) from None
            time.sleep(_PROBE_INTERVAL_SEC)


def _load_agent(path: Path) -> ModuleType:
    spec = importlib.util.spec_from_file_location("agent", path)
    if spec is None or spec.loader is None:
        raise ImportError(f"cannot load agent module from {path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def _run_agent(client: GameClientBase, agent_path: Path) -> None:
    agent = _load_agent(agent_path)
    run = getattr(agent, "run", None)
    if not callable(run):
        raise AttributeError("agent.py must define a run(client) function")
    run(client)


def _agent_path() -> Path:
    """Player's file: CHALLENGE_AGENT_PATH (launcher-set) or the sibling agent.py."""
    override = os.environ.get("CHALLENGE_AGENT_PATH")
    if override:
        return Path(override)
    return Path(__file__).resolve().parent / "agent.py"


def main() -> int:
    client = GameClientBase.from_env()
    _wait_for_port(client.host, client.port, _PORT_WAIT_SEC)
    client.connect()
    try:
        _run_agent(client, _agent_path())
    finally:
        client.close()
    return 0


if __name__ == "__main__":
    sys.exit(main())
