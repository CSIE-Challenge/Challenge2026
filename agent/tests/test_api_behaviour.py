"""Behaviour tests for the live API.

These boot a real Godot server (via the ``client`` fixture in conftest.py) and
talk to it the way a teammate's agent code would: through the high-level
GameClientBase methods. Run with ``pytest`` (needs Godot); skip with
``pytest -m 'not integration'``.
"""

from __future__ import annotations

import pytest

from api.client_base import ApiError, GameClientBase

pytestmark = pytest.mark.integration


def test_ping_returns_pong(client: GameClientBase) -> None:
    assert client.ping() == "pong"


def test_unknown_command_raises_not_found(client: GameClientBase) -> None:
    with pytest.raises(ApiError) as excinfo:
        client._call("does_not_exist")
    assert excinfo.value.code == 404
