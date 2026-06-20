from __future__ import annotations

import asyncio
import threading
from collections.abc import Coroutine
from typing import Any, TypeVar

from . import protocol
from .rpc import RpcClient
from .transport import Transport

T = TypeVar("T")


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

    def ping(self) -> Any:
        """Round-trip through every layer; returns the server's "pong"."""
        assert self._rpc is not None, "not connected"
        response = self._submit(self._rpc.call(protocol.Cmd.PING))
        return response.get("data")

    def get_energy(self) -> int:
        """Read the current energy amount from the game."""
        assert self._rpc is not None, "not connected"
        response = self._submit(self._rpc.call(protocol.Cmd.GET_ENERGY))
        return response.get("data")
