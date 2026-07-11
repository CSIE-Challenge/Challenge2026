from __future__ import annotations

import asyncio
import os
import sys
import threading
from collections.abc import Coroutine
from typing import Any, TypeVar
from urllib.parse import urlparse

from . import protocol
from .rpc import RpcClient
from .structures import Direction, Vector2
from .transport import Transport

T = TypeVar("T")


_CODE_MESSAGES = {
    protocol.Code.ILLFORMED: "malformed_request",
    protocol.Code.NOT_FOUND: "unknown_command",
    protocol.Code.REJECTED: "rejected",
    protocol.Code.INTERNAL: "internal_error",
}


class ApiError(Exception):
    """代表一次失敗的 API 呼叫。

    任何 API 失敗時都會回傳這個物件
    使用 ``if not result:`` 就能判斷失敗

    屬性：
        reason (str): 失敗原因，例如 ``"insufficient_energy"``、``"cooldown_active"``。
        code (int): 狀態碼（400 參數錯誤、404 未知指令/陷阱、409 遊戲規則拒絕、
            500 遊戲內部錯誤）。
        cmd (str | None): 觸發錯誤的指令名稱。

    ``str(err)`` 是可讀的完整訊息，例如
    ``"spawn_trap1 failed: insufficient_energy (409)"``。
    """

    def __init__(self, code: int, cmd: str | None = None, reason: str = "") -> None:
        self.code = code
        self.cmd = cmd
        self.reason = reason or _CODE_MESSAGES.get(code, "unknown_error")
        prefix = f"{cmd} failed: " if cmd else ""
        super().__init__(f"{prefix}{self.reason} ({code})")

    def __bool__(self) -> bool:
        return False


if sys.platform == "win32":
    os.system("")


def _print_warning(error: ApiError) -> None:
    text = f"[api] {error}"
    if sys.stdout.isatty():
        color = "33" if "insufficient" in error.reason else "31"
        text = f"\033[{color}m{text}\033[0m"
    print(text)


def _unwrap(response: dict, cmd: str | None = None, warn: bool = True) -> Any:
    """Return the response data, or a falsy ApiError."""
    if response.get("status") == protocol.Status.ERROR:
        error = ApiError(
            response.get("code", protocol.Code.ILLFORMED),
            cmd,
            response.get("reason", ""),
        )
        if warn:
            # Warn even when the caller never checks the return value.
            _print_warning(error)
        return error
    return response.get("data")


class GameClientBase:
    """與遊戲伺服器溝通的客戶端。

    ## 錯誤處理
    成功回傳結果；失敗「回傳」一個 `ApiError`。

    ```
    result = client.spawn_trap1(Vector2(120, 80))
    if not result:
        print(result.reason)  # 例如 insufficient_energy
    ```

    就算不檢查回傳值，每次失敗也會自動印出警告（例如
    ``[api] spawn_trap1 failed: insufficient_energy (409)``）。

    想自己處理錯誤、不要自動警告的話：

    ```
    client.print_api_errors = False
    ```

    ``print(...)`` 的輸出會顯示在執行 agent 的終端機（單人模式下也會寫到
    agent.py 旁邊的 ``agent.log``），所以印出來就能在 Python 端看到
    結果與錯誤訊息。
    """

    def __init__(self, token: str, host: str = "127.0.0.1", port: int = 7749) -> None:
        """設為 False 可關閉 API 失敗時的自動警告（預設 True）"""
        self.print_api_errors = True
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

    # ruff: disable[E501]
    def _call(self, cmd: str, args: dict[str, Any] | None = None) -> Any:
        """Send a command, block for the reply, and unwrap it.

        Returns the data on success, a ApiError on failure.
        """
        assert self._rpc is not None, "not connected"
        return _unwrap(
            self._submit(self._rpc.call(cmd, args)), cmd, self.print_api_errors
        )

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

    # --- APIs ---------------------------------------------------------------
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
        energy = client.get_my_energy()
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
        回傳一個 `Vector2`，表示對手玩家的座標；可直接用 `.x` / `.y` 取值。

        ## Example
        ```python
        pos = client.get_opponent_player_position()
        print(pos.x, pos.y)
        ```
        """
        data = self._call(protocol.Cmd.GET_OPPONENT_PLAYER_POSITION)
        if isinstance(data, ApiError):
            return data
        return Vector2.from_list(data)

    def get_opponent_energy_ball_position(self) -> Vector2:
        """
        # Get Opponent Energy Ball Position
        取得對手能量球的位置（單人模式下即為自己）。

        ## Parameters
        無參數

        ## Returns
        回傳一個 `Vector2`，表示能量球的座標；可直接用 `.x` / `.y` 取值。

        ## Example
        ```python
        ball = client.get_opponent_energy_ball_position()
        print(ball.x, ball.y)
        ```
        """
        data = self._call(protocol.Cmd.GET_OPPONENT_ENERGY_BALL_POSITION)
        if isinstance(data, ApiError):
            return data
        return Vector2.from_list(data)

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
        data = self._call(protocol.Cmd.GET_OPPONENT_PLAYER_VELOCITY)
        if isinstance(data, ApiError):
            return data
        return Vector2.from_list(data)

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

    def get_available_traps(self) -> list[int]:
        """
        # Get Available Traps
        取得目前可立即發送的陷阱清單（照目前能量、冷卻與排程狀態過濾）。

        ## Parameters
        無參數

        ## Returns
        陷阱編號陣列（例如 ``[1, 3, 6]``），編號對應 ``trap1`` ~ ``trap10``。

        ## Example
        ```python
        if 6 in client.get_available_traps():
            client.spawn_trap6(Direction.UP, 100)
        ```
        """
        return self._call(protocol.Cmd.GET_AVAILABLE_TRAPS)

    def get_cooldown_time(self, trap_id: int) -> float:
        """
        # Get Cooldown Time
        查詢指定陷阱剩餘冷卻秒數。

        ## Parameters
        - `trap_id` (int): 陷阱編號 1 ~ 10，對應 ``trap1`` ~ ``trap10``。

        ## Returns
        回傳剩餘冷卻秒數（0.0 表示可以發射）；編號無效時回傳 :class:`ApiError`。

        ## Example
        ```python
        cd = client.get_cooldown_time(1)
        if cd == 0.0:
            client.spawn_trap1(Vector2(120, 80))
        ```
        """
        return self._call(protocol.Cmd.GET_COOLDOWN_TIME, {"trap_id": trap_id})

    def heal(self) -> dict[str, Any]:
        """
        # Heal
        花費固定能量恢復固定生命值。治療量與能量花費由遊戲設定，呼叫時不需傳入參數。

        ## Parameters
        無參數

        ## Returns
        成功時回傳一個字典 (dict)，包含治療後的即時狀態：
        - `health` / `energy` / `heal_uses_left`

        失敗時回傳 `ApiError`，`reason` 例如
        `"insufficient_energy"`、`"no_heal_uses_left"`。

        ## Example
        ```python
        result = client.heal()
        if result:
            print(result["health"], result["heal_uses_left"])
        else:
            print(result.reason)
        ```
        """
        return self._call(protocol.Cmd.HEAL)

    def spawn_trap1(self, position: Vector2) -> bool:
        """
        # Spawn Trap 1（踩踏地雷）
        在指定位置放置一個「踩踏地雷」。

        ## Parameters
        - `position` (Vector2): 放置「踩踏地雷」的位置。

        ## Returns
        成功回傳 ``True``；失敗回傳 `ApiError`，
        `reason` 例如 ``"insufficient_energy"``、``"cooldown_active"``、
        ``"missing_position"``。

        ## Example
        ```python
        result = client.spawn_trap1(Vector2(120, 80))
        if not result:
            print(result.reason)
        ```
        """
        return self._call(protocol.Cmd.SPAWN_TRAP1, {"position": position})

    def spawn_trap2(self, delay_time: float, radius: float) -> bool:
        """
        # Spawn Trap 2 （追蹤電圈）
        放置一個「追蹤電圈」，經過 `delay_time` 秒後於半徑 `radius` 的範圍觸發。

        ## Parameters
        - `delay_time` (float): 觸發前的延遲秒數。
        - `radius` (float): 電環的半徑。

        ## Returns
        成功回傳 ``True``；失敗回傳 `ApiError`（同 `spawn_trap1`）。

        ## Example
        ```python
        client.spawn_trap2(1.5, 100)
        ```
        """
        return self._call(
            protocol.Cmd.SPAWN_TRAP2,
            {"delay_time": delay_time, "radius": radius},
        )

    def spawn_trap3(self, position: Vector2, direction: Vector2, speed: float) -> bool:
        """
        # Spawn Trap 3（追跡海鷗）
        從 `position` 以 `speed` 沿 `direction` 發射一隻「追跡海鷗」。

        ## Parameters
        - `position` (Vector2): 子彈的發射位置。
        - `direction` (Vector2): 子彈的初始方向。
        - `speed` (float): 子彈的速度。

        ## Returns
        成功回傳 ``True``；失敗回傳 `ApiError`（同 `spawn_trap1`）。

        ## Example
        ```python
        client.spawn_trap3(Vector2(100, 0), Vector2(0, -100), 200)
        ```
        """
        return self._call(
            protocol.Cmd.SPAWN_TRAP3,
            {"position": position, "direction": direction, "speed": speed},
        )

    def spawn_trap4(self, position: Vector2, direction: Direction) -> bool:
        """
        # Spawn Trap 4（大海嘯）
        在 `position` 放置一片「大海嘯」，把踩上去的玩家往 `direction` 推。

        ## Parameters
        - `position` (Vector2): 「大海嘯」的位置。
        - `direction` (Direction):推動方向，可傳 `Direction.UP/DOWN/LEFT/RIGHT`。

        ## Returns
        成功回傳 ``True``；失敗回傳 `ApiError`（同 `spawn_trap1`）。

        ## Example
        ```python
        client.spawn_trap4(Vector2(50, 50), Direction.RIGHT)
        ```
        """
        return self._call(
            protocol.Cmd.SPAWN_TRAP4,
            {"position": position, "direction": direction},
        )

    def spawn_trap5(self, position: Vector2) -> bool:
        """
        # Spawn Trap 5（小心地滑）
        在 `position` 放置一塊溼滑的地面。

        ## Parameters
        - `position` (Vector2): 「小心地滑」的位置。

        ## Returns
        成功回傳 ``True``；失敗回傳 `ApiError`（同 `spawn_trap1`）。

        ## Example
        ```python
        client.spawn_trap5(Vector2(150, 150))
        ```
        """
        return self._call(protocol.Cmd.SPAWN_TRAP5, {"position": position})

    def spawn_trap6(self, direction: Direction, speed: float) -> bool:
        """
        # Spawn Trap 6（熱情的迎賓舞）
        產生一支「熱情的迎賓舞」，沿 `direction` 以 `speed` 掃過場地。

        ## Parameters
        - `direction` (Direction):掃描方向，可傳 `Direction.UP/DOWN/LEFT/RIGHT`。
        - `speed` (float): 掃描線的移動速度。

        ## Returns
        成功回傳 ``True``；失敗回傳 `ApiError`（同 `spawn_trap1`）。

        ## Example
        ```python
        client.spawn_trap6(Direction.UP, 100)
        ```
        """
        return self._call(
            protocol.Cmd.SPAWN_TRAP6,
            {"direction": direction, "speed": speed},
        )

    def spawn_trap7(self, position: Vector2, expand_rate: float) -> bool:
        """
        # Spawn Trap 7（擴散漣漪）
        在 `position` 產生向外擴散的漣漪，擴散速率為 `expand_rate`。

        ## Parameters
        - `position` (Vector2): 漣漪的中心位置。
        - `expand_rate` (float): 漣漪的擴散速率。

        ## Returns
        成功回傳 ``True``；失敗回傳 `ApiError`（同 `spawn_trap1`）。

        ## Example
        ```python
        client.spawn_trap7(Vector2(300, 300), 150)
        ```
        """
        return self._call(
            protocol.Cmd.SPAWN_TRAP7,
            {"position": position, "expand_rate": expand_rate},
        )

    def spawn_trap8(self, start_position: Vector2, end_position: Vector2) -> bool:
        """
        # Spawn Trap 8（這是一條溝吧）
        在 `start_position` 與 `end_position` 之間產生一道「這是一條溝吧」。

        ## Parameters
        - `start_position` (Vector2): 「這是一條溝吧」的起點。
        - `end_position` (Vector2): 「這是一條溝吧」的終點。

        ## Returns
        成功回傳 ``True``；失敗回傳 `ApiError`（同 `spawn_trap1`）。

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
    ) -> bool:
        """
        # Spawn Trap 9（瓜瓜墜地）
        從 `start_position` 發射迫擊砲彈，經過 `air_time` 秒後落在 `end_position`。

        ## Parameters
        - `start_position` (Vector2): 「瓜瓜墜地」的發射點。
        - `end_position` (Vector2): 「瓜瓜」的落點。
        - `air_time` (float): 「瓜瓜」的滯空秒數。

        ## Returns
        成功回傳 ``True``；失敗回傳 `ApiError`（同 `spawn_trap1`）。

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
    ) -> bool:
        """
        # Spawn Trap 10（香蕉你個鳳梨）
        在 `position` 沿 `dir1`、`dir2`、`dir3` 三個方向同時發射「香蕉你個鳳梨」。

        ## Parameters
        - `position` (Vector2): 「香蕉你個鳳梨」的發射位置。
        - `dir1` (Vector2): 第一顆彈「香蕉」的方向。
        - `dir2` (Vector2): 第二顆彈「鳳梨」的方向。
        - `dir3` (Vector2): 第三顆彈「葡萄」的方向。

        ## Returns
        成功回傳 ``True``；失敗回傳 `ApiError`（同 `spawn_trap1`）。

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
