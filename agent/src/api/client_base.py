from __future__ import annotations

import asyncio
import os
import threading
from collections.abc import Coroutine
from typing import Any, TypeVar
from urllib.parse import urlparse

from . import protocol
from .rpc import RpcClient
from .structures import Direction, Vector2
from .transport import Transport

T = TypeVar("T")


# Human-readable meaning for each status code. The server only sends the
# number, so this is the one place a readable message can be attached.
_CODE_MESSAGES = {
    protocol.Code.ILLFORMED: "malformed request or bad arguments",
    protocol.Code.NOT_FOUND: "unknown command",
}


class ApiError(Exception):
    """代表一次失敗的 API 呼叫。

    屬性：
        code (int): 狀態碼（400 表示格式/參數錯誤，404 表示未知指令）。
        cmd (str | None): 觸發錯誤的指令名稱。

    ``str(err)`` 是可讀的完整訊息，例如
    ``"get_my_energy failed: unknown command (404)"``。
    """

    def __init__(self, code: int, cmd: str | None = None) -> None:
        self.code = code
        self.cmd = cmd
        reason = _CODE_MESSAGES.get(code, "unknown error")
        prefix = f"{cmd} failed: " if cmd else ""
        super().__init__(f"{prefix}{reason} ({code})")


def _unwrap(response: dict, cmd: str | None = None) -> Any:
    if response.get("status") == protocol.Status.ERROR:
        raise ApiError(response.get("code", protocol.Code.ILLFORMED), cmd)
    return response.get("data")


class GameClientBase:
    """與遊戲伺服器溝通的客戶端，你的 ``run(client)`` 會收到一個實例。

    ``print(...)`` 的輸出會顯示在執行 agent 的終端機（單人模式下也會寫到
    ``agent.log``），所以印出來就能在 Python 端看到結果與錯誤訊息。
    """

    def __init__(self, token: str, host: str = "127.0.0.1", port: int = 7749) -> None:
        self._token = token
        self.host = host
        self.port = port
        self._transport = Transport(host, port)
        self._rpc: RpcClient | None = None
        self._loop = asyncio.new_event_loop()
        self._thread = threading.Thread(
            target=self._run_loop, name="api-event-loop", daemon=True
        )

    @classmethod
    def from_url(cls, url: str, token: str) -> GameClientBase:
        """Build a client from a ws:// URL and an agent token."""
        parsed = urlparse(url)
        return cls(token, host=parsed.hostname or "127.0.0.1", port=parsed.port or 7749)

    @classmethod
    def from_env(cls) -> GameClientBase:
        """Build a client from CHALLENGE_WS_URL + CHALLENGE_TOKEN (launcher-set env)."""
        url = os.environ.get("CHALLENGE_WS_URL", "ws://127.0.0.1:7749")
        token = os.environ.get("CHALLENGE_TOKEN")
        if not token:
            raise RuntimeError("CHALLENGE_TOKEN is not set")
        return cls.from_url(url, token)

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

    # --- APIs ---------------------------------------------------------------
    # ruff: disable[E501]
    def _call(self, cmd: str, args: dict[str, Any] | None = None) -> Any:
        """Send a command, block for the reply, and unwrap it (raises ApiError)."""
        assert self._rpc is not None, "not connected"
        return _unwrap(self._submit(self._rpc.call(cmd, args)), cmd)

    def ping(self) -> Any:
        """
        # Ping
        測試與遊戲伺服器的連線，訊息會經過所有傳輸層並收到伺服器回傳的 "pong"。

        ## Parameters
        無參數

        ## Returns
        回傳字串 `"pong"`。

        ## Example
        ```python
        print(client.ping())  # pong
        ```
        """
        return self._call(protocol.Cmd.PING)

    # Read-only
    def get_my_energy(self) -> int:
        """
        # Get My Energy
        取得我方目前的能量值。

        ## Parameters
        無參數

        ## Returns
        回傳一個整數，表示我方目前的能量。

        ## Example
        ```python
        energy = client.get_my_energy()  # 取得目前能量
        ```
        """
        return self._call(protocol.Cmd.GET_MY_ENERGY)

    def get_my_health(self) -> int:
        """
        # Get My Health
        取得我方玩家目前的生命值。

        ## Parameters
        無參數

        ## Returns
        回傳一個整數，表示我方玩家目前的生命值。

        ## Example
        ```python
        hp = client.get_my_health()
        ```
        """
        return self._call(protocol.Cmd.GET_MY_HEALTH)

    def get_opponent_player_position(self) -> Vector2:
        """
        # Get Opponent Player Position
        取得對手玩家的位置（單人模式下即為自己）。

        ## Parameters
        無參數

        ## Returns
        回傳一個 `Vector2`，表示對手玩家的座標；可直接用 `.x`／`.y` 取值。

        ## Example
        ```python
        pos = client.get_opponent_player_position()
        print(pos.x, pos.y)
        ```
        """
        return Vector2.from_list(self._call(protocol.Cmd.GET_OPPONENT_PLAYER_POSITION))

    def get_opponent_energy_ball_position(self) -> Vector2:
        """
        # Get Opponent Energy Ball Position
        取得對手能量球的位置（單人模式下即為自己）。

        ## Parameters
        無參數

        ## Returns
        回傳一個 `Vector2`，表示能量球的座標；可直接用 `.x`／`.y` 取值。

        ## Example
        ```python
        ball = client.get_opponent_energy_ball_position()
        print(ball.x, ball.y)
        ```
        """
        return Vector2.from_list(
            self._call(protocol.Cmd.GET_OPPONENT_ENERGY_BALL_POSITION)
        )

    def get_opponent_player_velocity(self) -> Vector2:
        """
        # Get Opponent Player Velocity
        取得對手玩家的當前速度向量（單人模式下即為自己）。

        ## Parameters
        無參數

        ## Returns
        回傳一個 `Vector2`（速度向量）。

        ## Example
        ```python
        vel = client.get_opponent_player_velocity()
        print(vel.x, vel.y)
        ```
        """
        return Vector2.from_list(self._call(protocol.Cmd.GET_OPPONENT_PLAYER_VELOCITY))

    def get_remaining_time(self) -> float:
        """
        # Get Remaining Time
        取得目前關卡剩餘秒數（非負）。

        ## Parameters
        無參數

        ## Returns
        以秒為單位的 float。
        """
        return self._call(protocol.Cmd.GET_REMAINING_TIME)

    def get_opponent_combo(self) -> int:
        """
        # Get Opponent Combo
        取得對手能量球combo數（單人模式下即為自己）。

        ## Parameters
        無參數

        ## Returns
        回傳一個整數。
        """
        return self._call(protocol.Cmd.GET_OPPONENT_COMBO)

    def get_phase(self) -> int:
        """
        # Get Phase
        取得目前關卡難度等級。

        ## Parameters
        無參數

        ## Returns
        回傳整數關卡等級。
        """
        return self._call(protocol.Cmd.GET_PHASE)

    def get_available_traps(self) -> list[str]:
        """
        # Get Available Traps
        取得目前可立即發送的陷阱清單（照目前能量、冷卻與排程狀態過濾）。

        ## Parameters
        無參數

        ## Returns
        陷阱 ID 字串陣列（例如 ``["trap1-mine", ...]``）。
        """
        return self._call(protocol.Cmd.GET_AVAILABLE_TRAPS)

    def get_cool_down_time(self, trap_id: str) -> float:
        """
        # Get Cooldown Time
        查詢指定陷阱剩餘冷卻秒數。

        ## Parameters
        - `trap_id` (str): 陷阱 ID，例如 ``"trap1-mine"``。

        ## Returns
        回傳剩餘冷卻秒數；若參數或陷阱 ID 無效，回傳`-1.0`
        """
        return self._call(protocol.Cmd.GET_COOL_DOWN_TIME, {"trap_id": trap_id})

    def heal(self) -> dict[str, Any]:
        """
        # Heal
        花費固定能量恢復固定生命值。治療量與能量花費由遊戲設定，呼叫時不需傳入參數。

        ## Parameters
        無參數

        ## Returns
        回傳一個字典 (dict)，包含此次治療的結果：
        - `ok` (bool): 是否成功治療。
        - `reason` (str): 失敗原因（成功時為空字串），例如 `"insufficient_energy"`、`"no_heal_uses_left"`。
        - `health` / `max_health` / `energy` / `heal_uses_left`: 治療後的即時狀態。

        ## Example
        ```python
        result = client.heal()
        if not result["ok"]:
            print(result["reason"])
        ```
        """
        return self._call(protocol.Cmd.HEAL)

    def spawn_trap1(self, position: Vector2) -> dict[str, Any]:
        """
        # Spawn Trap 1 (Mine)
        在指定位置放置一個地雷。

        ## Parameters
        - `position` (Vector2): 放置地雷的位置。

        ## Returns
        回傳一個字典 (dict)，表示此次陷阱請求的結果：
        - `ok` (bool): 請求是否成功送出（進入佇列）。
        - `stage` (str): `"queued"`（已排入）或 `"rejected"`（被拒絕）。
        - `reason` (str): 被拒絕時的原因，例如 `"insufficient_energy"`、`"cooldown_active"`、`"missing_position"`。
        - `request_id` (int): 請求編號（被拒絕時為 -1）。
        - `trap_id` (str): 陷阱代號。

        ## Example
        ```python
        client.spawn_trap1(Vector2(120, 80))
        ```
        """
        return self._call(protocol.Cmd.SPAWN_TRAP1, {"position": position})

    def spawn_trap2(self, delay_time: float, radius: float) -> dict[str, Any]:
        """
        # Spawn Trap 2 (Electric Ring)
        放置一個電環，經過 `delay_time` 秒後於半徑 `radius` 的範圍觸發。

        ## Parameters
        - `delay_time` (float): 觸發前的延遲秒數。
        - `radius` (float): 電環的半徑。

        ## Returns
        回傳陷阱請求結果字典（欄位同 `spawn_trap1`：`ok`、`stage`、`reason`、`request_id`、`trap_id`）。

        ## Example
        ```python
        client.spawn_trap2(1.5, 100)
        ```
        """
        return self._call(
            protocol.Cmd.SPAWN_TRAP2,
            {"delay_time": delay_time, "radius": radius},
        )

    def spawn_trap3(
        self, position: Vector2, direction: Vector2, speed: float
    ) -> dict[str, Any]:
        """
        # Spawn Trap 3 (Tracing Bullet)
        從 `position` 以 `speed` 沿 `direction` 發射一顆追蹤子彈。

        ## Parameters
        - `position` (Vector2): 子彈的發射位置。
        - `direction` (Vector2): 子彈的初始方向。
        - `speed` (float): 子彈的速度。

        ## Returns
        回傳陷阱請求結果字典（欄位同 `spawn_trap1`）。

        ## Example
        ```python
        client.spawn_trap3(Vector2(100, 0), Vector2(0, -100), 200)
        ```
        """
        return self._call(
            protocol.Cmd.SPAWN_TRAP3,
            {"position": position, "direction": direction, "speed": speed},
        )

    def spawn_trap4(self, position: Vector2, direction: Direction) -> dict[str, Any]:
        """
        # Spawn Trap 4 (Conveyor)
        在 `position` 放置一塊履帶，把踩上去的玩家往 `direction` 推。

        ## Parameters
        - `position` (Vector2): 履帶的位置。
        - `direction` (Direction):推動方向，可傳 `Direction.UP/DOWN/LEFT/RIGHT`。

        ## Returns
        回傳陷阱請求結果字典（欄位同 `spawn_trap1`）。

        ## Example
        ```python
        client.spawn_trap4(Vector2(50, 50), Direction.RIGHT)
        ```
        """
        return self._call(
            protocol.Cmd.SPAWN_TRAP4,
            {"position": position, "direction": direction},
        )

    def spawn_trap5(self, position: Vector2) -> dict[str, Any]:
        """
        # Spawn Trap 5 (Ice Floor)
        在 `position` 放置一塊冰面。

        ## Parameters
        - `position` (Vector2): 冰面的位置。

        ## Returns
        回傳陷阱請求結果字典（欄位同 `spawn_trap1`）。

        ## Example
        ```python
        client.spawn_trap5(Vector2(150, 150))
        ```
        """
        return self._call(protocol.Cmd.SPAWN_TRAP5, {"position": position})

    def spawn_trap6(self, direction: Direction, speed: float) -> dict[str, Any]:
        """
        # Spawn Trap 6 (Scanline)
        產生一條掃描線，沿 `direction` 以 `speed` 掃過場地。

        ## Parameters
        - `direction` (Direction):掃描方向，可傳 `Direction.UP/DOWN/LEFT/RIGHT`。
        - `speed` (float): 掃描線的移動速度。

        ## Returns
        回傳陷阱請求結果字典（欄位同 `spawn_trap1`）。

        ## Example
        ```python
        client.spawn_trap6(Direction.UP, 100)
        ```
        """
        return self._call(
            protocol.Cmd.SPAWN_TRAP6,
            {"direction": direction, "speed": speed},
        )

    def spawn_trap7(self, position: Vector2, expand_rate: float) -> dict[str, Any]:
        """
        # Spawn Trap 7 (Spreading Ripples)
        在 `position` 產生向外擴散的漣漪，擴散速率為 `expand_rate`。

        ## Parameters
        - `position` (Vector2): 漣漪的中心位置。
        - `expand_rate` (float): 漣漪的擴散速率。

        ## Returns
        回傳陷阱請求結果字典（欄位同 `spawn_trap1`）。

        ## Example
        ```python
        client.spawn_trap7(Vector2(300, 300), 150)
        ```
        """
        return self._call(
            protocol.Cmd.SPAWN_TRAP7,
            {"position": position, "expand_rate": expand_rate},
        )

    def spawn_trap8(
        self, start_position: Vector2, end_position: Vector2
    ) -> dict[str, Any]:
        """
        # Spawn Trap 8 (Electric Arc)
        在 `start_position` 與 `end_position` 之間產生一道電弧。

        ## Parameters
        - `start_position` (Vector2): 電弧的起點。
        - `end_position` (Vector2): 電弧的終點。

        ## Returns
        回傳陷阱請求結果字典（欄位同 `spawn_trap1`）。

        ## Example
        ```python
        client.spawn_trap8(Vector2(-100, -100), Vector2(100, -100))
        ```
        """
        return self._call(
            protocol.Cmd.SPAWN_TRAP8,
            {"start_position": start_position, "end_position": end_position},
        )

    def spawn_trap9(
        self, start_position: Vector2, end_position: Vector2, air_time: float
    ) -> dict[str, Any]:
        """
        # Spawn Trap 9 (Mortar)
        從 `start_position` 發射迫擊砲彈，經過 `air_time` 秒後落在 `end_position`。

        ## Parameters
        - `start_position` (Vector2): 迫擊砲的發射點。
        - `end_position` (Vector2): 砲彈的落點。
        - `air_time` (float): 砲彈的滯空秒數。

        ## Returns
        回傳陷阱請求結果字典（欄位同 `spawn_trap1`）。

        ## Example
        ```python
        client.spawn_trap9(Vector2(200, 100), Vector2(220, 100), 1.0)
        ```
        """
        return self._call(
            protocol.Cmd.SPAWN_TRAP9,
            {
                "start_position": start_position,
                "end_position": end_position,
                "air_time": air_time,
            },
        )

    def spawn_trap10(
        self, position: Vector2, dir1: Vector2, dir2: Vector2, dir3: Vector2
    ) -> dict[str, Any]:
        """
        # Spawn Trap 10 (Shotgun)
        在 `position` 沿 `dir1`、`dir2`、`dir3` 三個方向同時發射霰彈。

        ## Parameters
        - `position` (Vector2): 霰彈的發射位置。
        - `dir1` (Vector2): 第一顆彈的方向。
        - `dir2` (Vector2): 第二顆彈的方向。
        - `dir3` (Vector2): 第三顆彈的方向。

        ## Returns
        回傳陷阱請求結果字典（欄位同 `spawn_trap1`）。

        ## Example
        ```python
        client.spawn_trap10(Vector2(-250, 100), Vector2(1, 0.2), Vector2(1, 0), Vector2(1, -0.2))
        ```
        """
        return self._call(
            protocol.Cmd.SPAWN_TRAP10,
            {
                "position": position,
                "dir1": dir1,
                "dir2": dir2,
                "dir3": dir3,
            },
        )

    # ruff: enable[E501]
