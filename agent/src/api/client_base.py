from __future__ import annotations

import asyncio
import threading
from collections.abc import Coroutine
from typing import Any, TypeVar

from . import protocol
from .rpc import RpcClient
from .transport import Transport

T = TypeVar("T")


class ApiError(Exception):
    def __init__(self, code: int) -> None:
        super().__init__(f"server returned error code {code}")
        self.code = code


def _unwrap(response: dict) -> Any:
    if response.get("status") == protocol.Status.ERROR:
        raise ApiError(response.get("code", protocol.Code.ILLFORMED))
    return response.get("data")


class GameClientBase:
    def __init__(self, token: str, host: str = "127.0.0.1", port: int = 7749) -> None:
        self._token = token
        self._transport = Transport(host, port)
        self._rpc: RpcClient | None = None
        self._loop = asyncio.new_event_loop()
        self._thread = threading.Thread(
            target=self._run_loop, name="api-event-loop", daemon=True
        )

    # --- async loop plumbing -------------------------------------------------

    def _run_loop(self) -> None:
        asyncio.set_event_loop(self._loop)
        self._loop.run_forever()

    def _submit(self, coro: Coroutine[Any, Any, T]) -> T:
        """Run a coroutine on the background loop and block for its result."""
        return asyncio.run_coroutine_threadsafe(coro, self._loop).result()

    # --- lifecycle -----------------------------------------------------------

    def connect(self) -> None:
        self._thread.start()

        async def _setup() -> None:
            await self._transport.connect(self._token)
            self._rpc = RpcClient(self._transport)
            self._rpc.start()

        self._submit(_setup())

    def close(self) -> None:
        async def _teardown() -> None:
            if self._rpc is not None:
                self._rpc.stop()
            await self._transport.close()

        self._submit(_teardown())
        self._loop.call_soon_threadsafe(self._loop.stop)
        self._thread.join(timeout=2.0)

    # --- layer 6: game commands (skeleton) -----------------------------------

    def _call(self, cmd: str, args: dict[str, Any] | None = None) -> Any:
        """Send a command, block for the reply, and unwrap it (raises ApiError)."""
        assert self._rpc is not None, "not connected"
        return _unwrap(self._submit(self._rpc.call(cmd, args)))

    def ping(self) -> Any:
        """Round-trip through every layer; returns the server's "pong"."""
        return self._call(protocol.Cmd.PING)

    def get_energy(self) -> int:
        """Read the current energy amount from the game."""
        return self._call(protocol.Cmd.GET_ENERGY)

    def request_trap(
        self,
        team_id: int,
        trap_id: int,
        params: dict[str, Any] | None = None,
    ) -> dict[str, Any]:
        """Request to place a trap."""
        return self._call(
            protocol.Cmd.REQUEST_TRAP,
            {
                "team_id": team_id,
                "trap_id": trap_id,
                "params": params or {},
            },
        )

    def get_team_status(self, team_id: int = 0) -> dict[str, Any]:
        """Read full status for one team."""
        return self._call(
            protocol.Cmd.GET_TEAM_STATUS,
            {"team_id": team_id},
        )

    def get_team_energy(self, team_id: int = 0) -> dict[str, Any]:
        """Read one team's current/max energy."""
        return self._call(
            protocol.Cmd.GET_TEAM_ENERGY,
            {"team_id": team_id},
        )

    def get_team_health(self, team_id: int = 0) -> dict[str, Any]:
        """Read one team's current/max health and mode."""
        return self._call(
            protocol.Cmd.GET_TEAM_HEALTH,
            {"team_id": team_id},
        )

    def request_heal(
        self,
        team_id: int,
        heal_amount: float,
        energy_cost: float,
    ) -> dict[str, Any]:
        """Request an energy-costed heal action for one team."""
        return self._call(
            protocol.Cmd.REQUEST_HEAL,
            {
                "team_id": team_id,
                "heal_amount": heal_amount,
                "energy_cost": energy_cost,
            },
        )
