"""Run the REAL built bundle exactly as the launcher will.

These tests spawn the bundled standalone interpreter on the bundled runner.py
against the mock WebSocket server. They catch packaging regressions that the
in-process runner tests cannot: a missing vendored .so, runner.py/agent.py not
copied into the bundle, or a broken standalone interpreter.

Skipped automatically when ``build/<platform>/`` is absent, so the fast unit
suite still runs on a fresh checkout. Build it first with
``./build_agent_bundle.sh``.
"""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))  # for tests package
from tests.mock_server import MockServer  # noqa: E402

_BUNDLE_ROOT = Path(__file__).resolve().parents[1] / "build"
_PYTHON_CANDIDATES = (
    "python/bin/python3.11",
    "python/bin/python3",
    "python/python.exe",
)


def _find_bundle() -> Path | None:
    """First build/<platform>/ dir that has a runner.py and an interpreter."""
    if not _BUNDLE_ROOT.is_dir():
        return None
    for sub in sorted(p for p in _BUNDLE_ROOT.iterdir() if p.is_dir()):
        if (sub / "runner.py").exists() and _bundle_python(sub) is not None:
            return sub
    return None


def _bundle_python(bundle: Path) -> Path | None:
    for rel in _PYTHON_CANDIDATES:
        candidate = bundle / rel
        if candidate.exists():
            return candidate
    return None


def _run_bundle(bundle: Path, extra_env: dict[str, str]) -> subprocess.CompletedProcess:
    """Invoke `<bundle>/python -s <bundle>/runner.py` the way the launcher does."""
    python = _bundle_python(bundle)
    assert python is not None
    env = {
        "PYTHONPATH": str(bundle / "libs"),
        "CHALLENGE_TOKEN": "deadbeef",
        "PATH": "/usr/bin:/bin",  # standalone interpreter; minimal clean env
        **extra_env,  # supplies CHALLENGE_WS_URL (+ optional CHALLENGE_AGENT_PATH)
    }
    return subprocess.run(
        [str(python), "-s", str(bundle / "runner.py")],
        env=env,
        capture_output=True,
        text=True,
        timeout=60,
    )


@pytest.fixture(scope="module")
def bundle() -> Path:
    found = _find_bundle()
    if found is None:
        pytest.skip("no agent bundle built (run ./build_agent_bundle.sh)")
    return found


@pytest.mark.bundle
def test_bundle_runs_baked_agent(bundle: Path) -> None:
    """No CHALLENGE_AGENT_PATH -> the agent.py baked into the bundle runs."""
    with MockServer() as srv:
        result = _run_bundle(
            bundle, {"CHALLENGE_WS_URL": f"ws://{srv.host}:{srv.port}"}
        )
    assert result.returncode == 0, result.stderr
    assert "agent connected: pong" in result.stdout


@pytest.mark.bundle
def test_bundle_runs_agent_path_override(bundle: Path, tmp_path: Path) -> None:
    """CHALLENGE_AGENT_PATH -> the launcher-selected file runs instead."""
    bot = tmp_path / "my_bot.py"
    bot.write_text(
        "def run(client):\n    print('BOT', client.ping(), client.get_energy())\n"
    )
    with MockServer() as srv:
        result = _run_bundle(
            bundle,
            {
                "CHALLENGE_WS_URL": f"ws://{srv.host}:{srv.port}",
                "CHALLENGE_AGENT_PATH": str(bot),
            },
        )
    assert result.returncode == 0, result.stderr
    assert "BOT pong 100" in result.stdout


@pytest.mark.bundle
def test_bundle_fails_fast_without_token(bundle: Path) -> None:
    """Missing CHALLENGE_TOKEN -> nonzero exit (from_env raises before connect)."""
    python = _bundle_python(bundle)
    assert python is not None
    result = subprocess.run(
        [str(python), "-s", str(bundle / "runner.py")],
        env={"PYTHONPATH": str(bundle / "libs"), "PATH": "/usr/bin:/bin"},
        capture_output=True,
        text=True,
        timeout=60,
    )
    assert result.returncode != 0
    assert "CHALLENGE_TOKEN" in result.stderr


if __name__ == "__main__":
    sys.exit(pytest.main([__file__, "-v", "-m", "bundle"]))
