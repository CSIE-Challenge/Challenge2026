# ruff: disable[F403]
# ruff: disable[F405]
from api import *

MIN_COORDINATE = -220
MAX_COORDINATE = 220
PLAYER_RADIUS = 13
FIELD_SIZE = 440


def run(client):
    previous_print_time = client.get_remaining_time()
    while True:
        position = client.get_opponent_player_position()

        if (
            abs(position.x - MIN_COORDINATE) <= PLAYER_RADIUS
            or abs(position.x - MAX_COORDINATE) <= PLAYER_RADIUS
            or abs(position.y - MIN_COORDINATE) <= PLAYER_RADIUS
            or abs(position.y - MAX_COORDINATE) <= PLAYER_RADIUS
        ):
            if client.get_cooldown_time(10) <= 0:
                client.spawn_trap10(
                    Vector2(-250.0, 100.0),
                    Vector2(1.0, 0.2),
                    Vector2(1.0, 0.0),
                    Vector2(1.0, -0.2),
                )
        else:
            x_block = (position.x - MIN_COORDINATE) * 3 // FIELD_SIZE
            y_block = (position.y - MIN_COORDINATE) * 3 // FIELD_SIZE
            target_trap = y_block * 3 + x_block + 1
            if target_trap in client.get_available_traps():
                if target_trap == 1:
                    client.spawn_trap1(Vector2(-145.0, -145.0))
                elif target_trap == 2:
                    client.spawn_trap2(1.0, 70.0)
                elif target_trap == 3:
                    client.spawn_trap3(Vector2(145.0, 220.0), Direction.UP, 100.0)
                elif target_trap == 4:
                    client.spawn_trap4(Vector2(-75.0, 0.0), Direction.RIGHT)
                elif target_trap == 5:
                    client.spawn_trap5(Vector2(0.0, 0.0))
                elif target_trap == 6:
                    client.spawn_trap6(Direction.DOWN, 120.0)
                elif target_trap == 7:
                    client.spawn_trap7(Vector2(210.0, -210.0), 200.0)
                elif target_trap == 8:
                    client.spawn_trap8(Vector2(-220.0, 145.0), Vector2(220.0, 145.0))
                else:
                    client.spawn_trap9(
                        Vector2(-220.0, 145.0), Vector2(145.0, 145.0), 2.0
                    )

        current_time = client.get_remaining_time()
        if current_time <= previous_print_time - 1.0:
            print(f"Remaining Time : {current_time}")
            print(f"Opponent Player Position : {client.get_opponent_player_position()}")
            print(f"Opponent Player Velocity : {client.get_opponent_player_velocity()}")
            print(
                f"Opponent Energy Ball Position : \
                {client.get_opponent_energy_ball_position()}"
            )
            print(f"Opponent Combo : {client.get_opponent_combo()}")
            print(f"Current Phase : {client.get_phase()}")
            print("----------------------------")
            previous_print_time = previous_print_time - 1.0


# ruff: enable[F403]
# ruff: enable[F405]
