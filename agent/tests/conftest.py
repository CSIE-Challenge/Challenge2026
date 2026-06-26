"""Integration-test harness: boot the real Godot server once per session.

Tests that ask for the ``client`` fixture get a connected GameClientBase
pointed at a freshly-booted headless Godot instance. If no Godot binary is
found the integration tests skip (so the fast unit suite still runs anywhere).
"""

from __future__ import annotations

import os
import re
import shutil
import subprocess
import tempfile
import time
from collections.abc import Iterator
from pathlib import Path

import pytest

from api.client_base import GameClientBase

REPO_ROOT = Path(__file__).resolve().parents[2]
_TOKEN_RE = re.compile(r"token: ([0-9a-f]{8})")
_BOOT_TIMEOUT_SEC = 30.0


def _startup_scene() -> str | None:
    # Keep default behavior the same as original local runs unless explicitly
    # set for this integration-test harness.
    # Set GODOT_TEST_SCENE to force a specific startup scene.
    # For API integration tests that require GameAgent token output, use:
    #   GODOT_TEST_SCENE=res://Scenes/main.tscn
    return os.environ.get("GODOT_TEST_SCENE")


def _build_godot_cmd(godot_bin: str, is_import: bool = False) -> list[str]:
    cmd: list[str] = [godot_bin, "--headless"]
    if is_import:
        cmd.append("--import")
    cmd.extend(["--path", str(REPO_ROOT)])
    scene = _startup_scene()
    if scene:
        cmd.append(scene)
    return cmd


def _find_godot() -> str | None:
    for candidate in (os.environ.get("GODOT_BIN"), "godot", "~/godot"):
        if candidate:
            found = shutil.which(os.path.expanduser(candidate))
            if found:
                return found
    return None


def _wait_for_token(proc: subprocess.Popen, log_path: Path) -> str:
    deadline = time.monotonic() + _BOOT_TIMEOUT_SEC
    while time.monotonic() < deadline:
        if proc.poll() is not None:
            raise RuntimeError("Godot server exited before printing a token")
        match = _TOKEN_RE.search(log_path.read_text(encoding="utf-8", errors="ignore"))
        if match:
            return match.group(1)
        time.sleep(0.2)
    raise RuntimeError("Godot server did not print a token within timeout")


@pytest.fixture(scope="session")
def _server_token() -> Iterator[str]:
    godot = _find_godot()
    if godot is None:
        pytest.skip("Godot binary not found (set GODOT_BIN to run behaviour tests)")
    # Import pass first so class_name scripts resolve on a fresh checkout.
    subprocess.run(
        _build_godot_cmd(godot, is_import=True),
        capture_output=True,
        timeout=_BOOT_TIMEOUT_SEC,
        check=False,
    )
    fd, name = tempfile.mkstemp(suffix=".godot.log")
    os.close(fd)
    log_path = Path(name)
    log = log_path.open("w")
    proc = subprocess.Popen(
        _build_godot_cmd(godot),
        stdout=log,
        stderr=subprocess.STDOUT,
    )
    try:
        yield _wait_for_token(proc, log_path)
    finally:
        proc.terminate()
        try:
            proc.wait(timeout=5)
        except subprocess.TimeoutExpired:
            proc.kill()
        log.close()
        log_path.unlink(missing_ok=True)


@pytest.fixture(scope="session")
def client(_server_token: str) -> Iterator[GameClientBase]:
    agent = GameClientBase(_server_token)
    agent.connect()
    yield agent
    agent.close()
