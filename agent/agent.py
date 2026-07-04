import time

# ruff: disable[F403]
# ruff: disable[F405]
from api import *

PLAN = [
    lambda c: c.spawn_trap1(Vector2(120.0, 80.0)),
    lambda c: c.spawn_trap2(1.5, 100.0),
    lambda c: c.spawn_trap3(Vector2(100.0, 0.0), Vector2(0.0, -100.0), 200.0),
    lambda c: c.spawn_trap4(Vector2(50.0, 50.0), Direction.RIGHT),
    lambda c: c.spawn_trap5(Vector2(150.0, 150.0)),
    lambda c: c.spawn_trap6(Direction.UP, 100.0),
    lambda c: c.spawn_trap7(Vector2(300.0, 300.0), 150.0),
    lambda c: c.spawn_trap8(Vector2(-100.0, -100.0), Vector2(100.0, -100.0)),
    lambda c: c.spawn_trap9(Vector2(200.0, 100.0), Vector2(220.0, 100.0), 1.0),
    lambda c: c.spawn_trap10(
        Vector2(-250.0, 100.0),
        Vector2(1.0, 0.2),
        Vector2(1.0, 0.0),
        Vector2(1.0, -0.2),
    ),
]


def run(client: GameClientBase):
    while True:
        for place_trap in PLAN:
            while True:
                result = place_trap(client)
                if result.get("ok"):
                    print(f"placed trap (energy left: {client.get_my_energy()})")
                    break
                if result.get("reason") != "insufficient_energy":
                    print(f"trap rejected: {result.get('reason')}")
                    break
                time.sleep(1.0)


# ruff: enable[F403]
# ruff: enable[F405]
