#!/usr/bin/env python3
"""Bundle entrypoint: connect to the game and hand the player's agent a client.

The agent contract is just `def run(client)` -- the player never touches the
token or the connection. This file does the connecting.

Two ways it runs, same entrypoint:
  * In-game (normal play): the game spawns the bundled interpreter on this file
    with CHALLENGE_WS_URL / CHALLENGE_TOKEN / CHALLENGE_AGENT_PATH in the env.
  * Manual test: start the game with `--console` (it prints a port and token),
    then point this at them:
        python runner.py --url ws://127.0.0.1:<port> --token <token> \
            --agent path/to/agent.py
"""

from __future__ import annotations

import argparse
import importlib.util
import os
import socket
import sys
import threading
import time
from pathlib import Path
from types import ModuleType

from api.client_base import GameClientBase

_PORT_WAIT_SEC = 30.0
_PROBE_INTERVAL_SEC = 0.3
_HEARTBEAT_SEC = 2.0


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


def _start_reaper(client: GameClientBase, stop: threading.Event) -> None:
    """Reap the agent when the game goes away, whatever run() is doing."""

    def _beat() -> None:
        while not stop.wait(_HEARTBEAT_SEC):
            try:
                client.ping()
            except Exception:
                print("[runner] game unreachable; stopping agent", file=sys.stderr)
                os._exit(0)

    threading.Thread(target=_beat, name="conn-reaper", daemon=True).start()


def _run_agent(client: GameClientBase, agent_path: Path) -> None:
    agent = _load_agent(agent_path)
    run = getattr(agent, "run", None)
    if not callable(run):
        raise AttributeError("agent.py must define a run(client) function")
    run(client)


def _agent_path(override: str | None = None) -> Path:
    """Player's file: --agent / CHALLENGE_AGENT_PATH, else the sibling agent.py."""
    chosen = override or os.environ.get("CHALLENGE_AGENT_PATH")
    if chosen:
        return Path(chosen)
    return Path(__file__).resolve().parent / "agent.py"


def _build_client(args: argparse.Namespace) -> GameClientBase:
    """Connection details: CLI flags win, else the env the game sets."""
    url = args.url or os.environ.get("CHALLENGE_WS_URL", "ws://127.0.0.1:7749")
    token = args.token or os.environ.get("CHALLENGE_TOKEN")
    if not token:
        raise RuntimeError(
            "no token: pass --token, or set CHALLENGE_TOKEN. "
            "For a manual run, start the game with --console to get a token."
        )
    return GameClientBase.from_url(url, token)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Run a player agent against the game.")
    parser.add_argument(
        "--url",
        help="ws://host:port (default: CHALLENGE_WS_URL or ws://127.0.0.1:7749)",
    )
    parser.add_argument("--token", help="agent token (default: CHALLENGE_TOKEN)")
    parser.add_argument(
        "--agent",
        help="agent .py path (default: CHALLENGE_AGENT_PATH or sibling agent.py)",
    )
    args = parser.parse_args(argv)

    client = _build_client(args)
    _wait_for_port(client.host, client.port, _PORT_WAIT_SEC)
    client.connect()
    stop = threading.Event()
    _start_reaper(client, stop)
    try:
        _run_agent(client, _agent_path(args.agent))
    finally:
        stop.set()
        client.close()
    return 0


if __name__ == "__main__":
    sys.exit(main())
