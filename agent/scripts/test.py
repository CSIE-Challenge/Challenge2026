import itertools
import math
import time

from api import Direction, Vector2

LOOP_DELAY_SEC = 1.0
HEAL_HP_FRACTION = 0.95
SAFE_RADIUS = 400.0
MAP_CENTER = Vector2(0.0, 0.0)
DEFAULT_MAX_HP = 100
SCANLINE_SPEED = 100.0
SCAN_DIRECTIONS = [Direction.UP, Direction.RIGHT, Direction.DOWN, Direction.LEFT]


def _distance(a: Vector2, b: Vector2) -> float:
    return math.hypot(a.x - b.x, a.y - b.y)


def _spawn_scanline(client, direction: Direction) -> None:
    result = client.spawn_trap6(direction, SCANLINE_SPEED)
    if result.get("ok"):
        print(f"  scanline {direction.name} spawned")
    else:
        print(f"  scanline refused: {result.get('reason')}")


def _try_heal(client, max_hp: int) -> int:
    result = client.heal()
    if result.get("ok"):
        print(
            f"  healed -> hp={result.get('health')}/{result.get('max_health')} "
            f"energy={result.get('energy')} uses_left={result.get('heal_uses_left')}"
        )
    else:
        print(f"  heal refused: {result.get('reason')}")
        _spawn_scanline(client, Direction.UP)
    return int(result.get("max_health", max_hp))


def run(client) -> None:
    max_hp = DEFAULT_MAX_HP
    directions = itertools.cycle(SCAN_DIRECTIONS)
    while True:
        hp = client.get_my_health()
        energy = client.get_my_energy()
        pos = Vector2.from_list(client.get_opponent_player_position())
        eball_pos = Vector2.from_list(client.get_opponent_energy_ball_position())

        # ruff: disable[E501]
        print(
            f"hp={hp}/{max_hp} energy={energy} pos=({pos.x:.0f},{pos.y:.0f}), energy ball pos = ({eball_pos.x:.0f}, {eball_pos.y:.0f})"
        )
        # ruff: enable[E501]

        want_heal = hp < 95
        if want_heal:
            max_hp = _try_heal(client, max_hp)
        else:
            _spawn_scanline(client, next(directions))

        time.sleep(LOOP_DELAY_SEC)
