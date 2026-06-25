"""A minimal stand-in for the Godot WebSocket server, for testing the runner.

Speaks the real handshake ("Connection OK. Have Fun!") and answers ping /
get_energy. Use as a context manager (picks a free port) or run as a script.
"""

from __future__ import annotations

import asyncio
import threading

from websockets.asyncio.server import serve

from api import serialization
from api.transport import _AUTH_OK

_ENERGY = 100


async def _handle(conn) -> None:
    token = await conn.recv()
    if not token:
        await conn.close()
        return
    await conn.send(_AUTH_OK)
    async for raw in conn:
        msg = serialization.decode(raw)
        req_id, cmd = msg.get("id"), msg.get("cmd")
        if cmd == "ping":
            reply = {"id": req_id, "status": "ok", "data": "pong"}
        elif cmd == "get_energy":
            reply = {"id": req_id, "status": "ok", "data": _ENERGY}
        else:
            reply = {"id": req_id, "status": "error", "code": 404}
        await conn.send(serialization.encode(reply))


class MockServer:
    """Run the mock in its own thread + event loop; port 0 picks a free port."""

    def __init__(self, host: str = "127.0.0.1", port: int = 0) -> None:
        self.host = host
        self.port = port
        self._thread = threading.Thread(target=self._run, daemon=True)
        self._ready = threading.Event()
        self._loop: asyncio.AbstractEventLoop | None = None
        self._stop: asyncio.Event | None = None

    def __enter__(self) -> MockServer:
        self._thread.start()
        if not self._ready.wait(timeout=5.0):
            raise RuntimeError("mock server failed to start")
        return self

    def __exit__(self, *exc: object) -> None:
        assert self._loop is not None and self._stop is not None
        self._loop.call_soon_threadsafe(self._stop.set)
        self._thread.join(timeout=5.0)

    def _run(self) -> None:
        self._loop = asyncio.new_event_loop()
        asyncio.set_event_loop(self._loop)
        self._loop.run_until_complete(self._main())

    async def _main(self) -> None:
        async with serve(_handle, self.host, self.port) as server:
            self.port = server.sockets[0].getsockname()[1]
            self._stop = asyncio.Event()
            self._ready.set()
            await self._stop.wait()


if __name__ == "__main__":
    import sys

    port = int(sys.argv[1]) if len(sys.argv) > 1 else 7749
    with MockServer(port=port) as srv:
        print(f"mock server on ws://{srv.host}:{srv.port} (ctrl-c to stop)")
        try:
            threading.Event().wait()
        except KeyboardInterrupt:
            pass
