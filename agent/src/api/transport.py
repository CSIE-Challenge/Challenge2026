from __future__ import annotations

from websockets.asyncio.client import ClientConnection, connect

# The exact string the Godot server replies with on a successful handshake.
_AUTH_OK = "Connection OK."


class AuthError(ConnectionError):
    """Raised when the server rejects the token handshake."""


class Transport:
    def __init__(self, host: str = "127.0.0.1", port: int = 7749) -> None:
        self._uri = f"ws://{host}:{port}"
        self._ws: ClientConnection | None = None

    async def connect(self, token: str) -> None:
        self._ws = await connect(self._uri)
        await self._ws.send(token)
        reply = await self._ws.recv()
        if reply != _AUTH_OK:
            await self._ws.close()
            self._ws = None
            raise AuthError(f"handshake rejected: {reply!r}")

    async def send(self, text: str) -> None:
        assert self._ws is not None, "transport not connected"
        await self._ws.send(text)

    async def recv(self) -> str:
        assert self._ws is not None, "transport not connected"
        message = await self._ws.recv()
        # The server only sends text frames; normalize just in case.
        return message if isinstance(message, str) else message.decode("utf-8")

    async def close(self) -> None:
        if self._ws is not None:
            await self._ws.close()
            self._ws = None
