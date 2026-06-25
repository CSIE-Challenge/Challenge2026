"""Starter agent. The bundle ships this as agent.py; players edit run().

run(client) is called once with a connected GameClientBase. Drive the game
through client (e.g. client.ping(), client.get_energy()) and return when done.
"""

from __future__ import annotations

from api.client_base import GameClientBase


def run(client: GameClientBase) -> None:
    print("agent connected:", client.ping())
    print("starting energy:", client.get_energy())
