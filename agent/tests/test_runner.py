"""Layer 1 tests: from_env + runner against the mock WebSocket server (no Godot)."""

from __future__ import annotations

import sys
from pathlib import Path

import pytest

from api.client_base import GameClientBase

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))  # for runner.py
import runner  # noqa: E402
from tests.mock_server import MockServer  # noqa: E402


def test_from_env_parses_url_and_token(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("CHALLENGE_WS_URL", "ws://10.0.0.5:9000")
    monkeypatch.setenv("CHALLENGE_TOKEN", "deadbeef")
    client = GameClientBase.from_env()
    assert (client.host, client.port, client._token) == ("10.0.0.5", 9000, "deadbeef")


def test_from_env_requires_token(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.delenv("CHALLENGE_TOKEN", raising=False)
    with pytest.raises(RuntimeError):
        GameClientBase.from_env()


def test_runner_connects_and_runs_agent(
    monkeypatch: pytest.MonkeyPatch, tmp_path: Path
) -> None:
    agent_file = tmp_path / "agent.py"
    agent_file.write_text(
        "def run(client):\n    client.seen = (client.ping(), client.get_energy())\n"
    )
    with MockServer() as srv:
        monkeypatch.setenv("CHALLENGE_WS_URL", f"ws://{srv.host}:{srv.port}")
        monkeypatch.setenv("CHALLENGE_TOKEN", "deadbeef")
        client = GameClientBase.from_env()
        runner._wait_for_port(client.host, client.port, timeout=5.0)
        client.connect()
        try:
            runner._run_agent(client, agent_file)
        finally:
            client.close()
    assert client.seen == ("pong", 100)


def test_run_agent_rejects_missing_run(tmp_path: Path) -> None:
    bad = tmp_path / "agent.py"
    bad.write_text("x = 1\n")
    with pytest.raises(AttributeError):
        runner._run_agent(object(), bad)  # type: ignore[arg-type]


def test_wait_for_port_times_out() -> None:
    with pytest.raises(TimeoutError):
        runner._wait_for_port("127.0.0.1", 1, timeout=0.5)


def test_agent_path_defaults_to_sibling(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.delenv("CHALLENGE_AGENT_PATH", raising=False)
    assert runner._agent_path() == Path(runner.__file__).resolve().parent / "agent.py"


def test_agent_path_uses_env_override(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("CHALLENGE_AGENT_PATH", "/teams/red/my_bot.py")
    assert runner._agent_path() == Path("/teams/red/my_bot.py")
