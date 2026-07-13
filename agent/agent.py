# ruff: disable[F403]
# ruff: disable[F405]
from api import *

# 這是 Default Agent 的程式碼，這支程式的放陷阱邏輯如下
# - 如果玩家位在牆邊，Agent 會嘗試放置 trap 10
# - 否則，agent 會將場地切成 3x3 的網格，如下圖

# 	 --- --- ---
# 	| 1 | 2 | 3 |
# 	 --- --- ---
# 	| 4 | 5 | 6 |
# 	 --- --- ---
# 	| 7 | 8 | 9 |
# 	 --- --- ---
#    並放置玩家所在格子編號的陷阱

# 另外 Agent 會在血量 <=1 且回血額度尚未用完時，停止放置陷阱，等待回血

# 如果你想要調整 Default Agent 並進行測試，你可以將其複製到一份新的 .py 檔中，
# 並放在 /scripts 底下，鼓勵大家調整傳入陷阱中的各個參數看看效果如何！

MIN_COORDINATE = -220
MAX_COORDINATE = 220
PLAYER_RADIUS = 13.5
FIELD_SIZE = 440
MAX_HEALTH = 5
HEAL_THRESHOLD = 1
MAX_HEAL_COUNT = 2


def run(client):
    # client.print_api_errors = False
    # 如果你不想在輸出看到形如 [api] xxx 的訊息，你可以把上面這行反註解掉

    previous_print_time = 300.0 - client.get_elapsed_time()
    heal_count = 0
    while True:
        if client.get_my_health() <= HEAL_THRESHOLD and heal_count < MAX_HEAL_COUNT:
            if client.heal():
                heal_count = heal_count + 1
                print(f"Heal Success, Heal Count = {heal_count}")
                print(f"Remaining Energy : {client.get_my_energy()}")
                print("----------------------------")
            continue

        position = client.get_opponent_player_position()

        if (
            abs(position.x - MIN_COORDINATE) <= PLAYER_RADIUS
            or abs(position.x - MAX_COORDINATE) <= PLAYER_RADIUS
            or abs(position.y - MIN_COORDINATE) <= PLAYER_RADIUS
            or abs(position.y - MAX_COORDINATE) <= PLAYER_RADIUS
        ):
            # 如果玩家位在牆邊，Agent 會只嘗試放置 trap 10
            if client.get_cooldown_time(10) <= 0:
                client.spawn_trap10(
                    Vector2(-250.0, 100.0),
                    Vector2(1.0, 0.2),
                    Vector2(1.0, 0.0),
                    Vector2(1.0, -0.2),
                )  # 調整傳入它的參數！
        else:
            x_block = (position.x - MIN_COORDINATE) * 3 // FIELD_SIZE
            y_block = (position.y - MIN_COORDINATE) * 3 // FIELD_SIZE
            target_trap = y_block * 3 + x_block + 1
            # target_trap 為玩家位在九宮格哪一格

            if target_trap in client.get_available_traps():
                if target_trap == 1:
                    client.spawn_trap1(Vector2(-145.0, -145.0))  # 調整傳入它的參數！
                elif target_trap == 2:
                    client.spawn_trap2(1.0, 70.0)  # 調整傳入它的參數！
                elif target_trap == 3:
                    client.spawn_trap3(
                        Vector2(145.0, 220.0), Vector2(0.0, -1.0), 100.0
                    )  # 調整傳入它的參數！
                elif target_trap == 4:
                    client.spawn_trap4(
                        Vector2(-75.0, 0.0), Direction.RIGHT
                    )  # 調整傳入它的參數！
                elif target_trap == 5:
                    client.spawn_trap5(Vector2(0.0, 0.0))  # 調整傳入它的參數！
                elif target_trap == 6:
                    client.spawn_trap6(Direction.DOWN, 120.0)  # 調整傳入它的參數！
                elif target_trap == 7:
                    client.spawn_trap7(
                        Vector2(210.0, -210.0), 200.0
                    )  # 調整傳入它的參數！
                elif target_trap == 8:
                    client.spawn_trap8(
                        Vector2(-220.0, 145.0), Vector2(220.0, 145.0)
                    )  # 調整傳入它的參數！
                else:
                    client.spawn_trap9(
                        Vector2(-220.0, 145.0), Vector2(145.0, 145.0), 2.0
                    )  # 調整傳入它的參數！

        current_time = 300.0 - client.get_elapsed_time()
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
