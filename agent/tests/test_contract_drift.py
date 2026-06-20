from __future__ import annotations

import re
from pathlib import Path

from api import protocol

REPO_ROOT = Path(__file__).resolve().parents[2]
GODOT_SCRIPTS = REPO_ROOT / "Scripts"

# Matches:  register_command("get_energy", ...)
_REGISTER_RE = re.compile(r'register_command\(\s*"([^"]+)"')


def _python_commands() -> set[str]:
    return {
        value
        for name, value in vars(protocol.Cmd).items()
        if not name.startswith("_") and isinstance(value, str)
    }


def _godot_commands() -> set[str]:
    names: set[str] = set()
    for path in GODOT_SCRIPTS.rglob("*.gd"):
        text = path.read_text(encoding="utf-8")
        names.update(_REGISTER_RE.findall(text))
    return names


def test_no_command_drift() -> None:
    python = _python_commands()
    godot = _godot_commands()
    assert python == godot, (
        "contract drift between Python and Godot:\n"
        f"  only in protocol.Cmd: {sorted(python - godot)}\n"
        f"  only in Godot:        {sorted(godot - python)}"
    )
