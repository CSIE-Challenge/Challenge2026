from __future__ import annotations

import asyncio
import itertools
from typing import Any

from . import protocol, serialization
from .transport import Transport

_RESPONSE_TIMEOUT_SEC = 5.0


class RpcClient:
    def __init__(self, transport: Transport) -> None:
        self._transport = transport
        self._ids = itertools.count(1)
        self._pending: dict[int, asyncio.Future] = {}
        self._reader_task: asyncio.Task | None = None

    def start(self) -> None:
        """Spawn the background reader. Must run inside the event loop."""
        self._reader_task = asyncio.create_task(self._reader())

    async def _reader(self) -> None:
        try:
            while True:
                text = await self._transport.recv()
                msg = serialization.decode(text)
                req_id = msg.get("id")
                future = self._pending.pop(req_id, None)
                if future is not None and not future.done():
                    future.set_result(msg)
        except asyncio.CancelledError:
            raise
        except Exception as exc:  # connection closed / decode error
            self._fail_all(exc)

    def _fail_all(self, exc: Exception) -> None:
        for future in self._pending.values():
            if not future.done():
                future.set_exception(exc)
        self._pending.clear()

    async def call(self, cmd: str, args: dict[str, Any] | None = None) -> dict:
        req_id = next(self._ids)
        future: asyncio.Future = asyncio.get_running_loop().create_future()
        self._pending[req_id] = future

        request = protocol.make_request(req_id, cmd, args)
        await self._transport.send(serialization.encode(request))
        try:
            return await asyncio.wait_for(future, timeout=_RESPONSE_TIMEOUT_SEC)
        finally:
            self._pending.pop(req_id, None)

    def stop(self) -> None:
        if self._reader_task is not None:
            self._reader_task.cancel()
            self._reader_task = None
