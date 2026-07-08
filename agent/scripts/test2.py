import time
from math import sqrt

# ruff: disable[F403]
# ruff: disable[F405]
from api import Direction, Vector2

LOOP_DELAY_SEC = 1.0
TARGET_ENERGY = 100
MAP_MIN = -220.0
MAP_MAX = 220.0
SIDE_X = 190.0
NEAR_OFFSET = 45.0
ARC_HALF_LENGTH = 170.0
MORTAR_AIR_TIME = 1.5


def _clamp(
    value: float, min_value: float = MAP_MIN, max_value: float = MAP_MAX
) -> float:
    return max(min_value, min(max_value, value))


def _inside_map(pos: Vector2) -> Vector2:
    return Vector2(_clamp(pos.x), _clamp(pos.y))


def _add(pos: Vector2, x: float, y: float) -> Vector2:
    return _inside_map(Vector2(pos.x + x, pos.y + y))


def _left_side(y: float) -> Vector2:
    return _inside_map(Vector2(-SIDE_X, y))


def _right_side(y: float) -> Vector2:
    return _inside_map(Vector2(SIDE_X, y))


def _direction_from_to(start: Vector2, end: Vector2) -> Vector2:
    x = end.x - start.x
    y = end.y - start.y
    length = sqrt(x * x + y * y)
    if length == 0.0:
        return Vector2(1.0, 0.0)
    return Vector2(x / length, y / length)


def _scan_from_nearer_side(player_pos: Vector2) -> Direction:
    if player_pos.x >= 0.0:
        return Direction.LEFT
    return Direction.RIGHT


def _spawn_trap3_from_left(client, player_pos: Vector2) -> dict:
    spawn_pos = _left_side(player_pos.y)
    return client.spawn_trap3(
        spawn_pos, _direction_from_to(spawn_pos, player_pos), 300.0
    )


def _spawn_trap8_through_player(client, player_pos: Vector2) -> dict:
    start_pos = _add(player_pos, -ARC_HALF_LENGTH, 0.0)
    end_pos = _add(player_pos, ARC_HALF_LENGTH, 0.0)
    return client.spawn_trap8(start_pos, end_pos)


def _spawn_trap9_to_player(client, player_pos: Vector2) -> dict:
    start_pos = _right_side(player_pos.y)
    return client.spawn_trap9(start_pos, player_pos, MORTAR_AIR_TIME)


def _spawn_trap10_from_right(client, player_pos: Vector2) -> dict:
    spawn_pos = _right_side(player_pos.y)
    aim = _direction_from_to(spawn_pos, player_pos)
    return client.spawn_trap10(
        spawn_pos,
        Vector2(aim.x - aim.y * 0.25, aim.y + aim.x * 0.25),
        aim,
        Vector2(aim.x + aim.y * 0.25, aim.y - aim.x * 0.25),
    )


def _make_trap_plan(player_pos: Vector2):
    player_pos = _inside_map(player_pos)
    left_pos = _left_side(player_pos.y - NEAR_OFFSET)
    right_pos = _right_side(player_pos.y + NEAR_OFFSET)
    return [
        ("trap2", lambda client: client.spawn_trap2(1.0, 70.0)),
        ("trap3", lambda client: _spawn_trap3_from_left(client, player_pos)),
        ("trap9", lambda client: _spawn_trap9_to_player(client, player_pos)),
        ("trap1", lambda client: client.spawn_trap1(left_pos)),
        ("trap4", lambda client: client.spawn_trap4(left_pos, Direction.RIGHT)),
        (
            "trap6",
            lambda client: client.spawn_trap6(
                _scan_from_nearer_side(player_pos), 250.0
            ),
        ),
        ("trap7", lambda client: client.spawn_trap7(right_pos, 200.0)),
        ("trap8", lambda client: _spawn_trap8_through_player(client, player_pos)),
        ("trap10", lambda client: _spawn_trap10_from_right(client, player_pos)),
    ]


def _spawn_traps(client, player_pos: Vector2) -> None:
    for trap_name, spawn_trap in _make_trap_plan(player_pos):
        result = spawn_trap(client)
        if result.get("ok"):
            print(f"{trap_name} spawned")
        else:
            print(f"{trap_name} refused: {result.get('reason')}")


def run(client) -> None:
    while True:
        energy = client.get_my_energy()
        print(f"energy={energy}")

        if energy >= TARGET_ENERGY:
            player_pos = Vector2.from_list(client.get_opponent_player_position())
            print(
                "energy reached 100, spawning traps from both sides "
                f"near player at ({player_pos.x:.0f}, {player_pos.y:.0f})"
            )
            _spawn_traps(client, player_pos)

        time.sleep(LOOP_DELAY_SEC)


# ruff: enable[F403]
# ruff: enable[F405]
