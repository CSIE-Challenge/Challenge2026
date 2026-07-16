import math
import random
import time
from dataclasses import dataclass, field

from api import ApiError, Direction, Vector2

FIELD_MIN = -220.0
FIELD_MAX = 220.0
EDGE = 275.0
SHOTGUN_EDGE = 258.0
MAX_HP = 5
LOOP_DELAY = 0.06
BURST_SIZE = 3
WAVE_BURST_SIZE = 12
LOG_EVERY = 1.0
MID_PHASE = 1
WAVE_MEMORY_SEC = 10.5
WALL_PUSH_DISTANCE = 145.0
MAX_ENERGY_BY_PHASE = [35, 50, 60, 70, 77, 85]
TRAP_COST = {
    2: 15,
    3: 13,
    4: 20,
    5: 4,
    6: 20,
    7: 20,
    8: 12,
    9: 12,
    10: 18,
}
TRAP_STOCK = {2: 1, 3: 2, 4: 1, 5: 3, 6: 2, 7: 2, 8: 2, 9: 2, 10: 2}
WAVE_TRAP_ID = 4
WAVE_POOLS_BY_PHASE = {
    1: [6, 2, 8, 9, 3, 10, 9, 3, 10, 3],
    2: [6, 2, 7, 8, 9, 10, 3, 9, 10, 3, 3, 6],
    3: [6, 2, 7, 8, 9, 10, 3, 10, 3, 9, 3, 6],
    4: [6, 7, 8, 9, 10, 3, 10, 3, 9, 6, 7, 3, 2],
    5: [6, 7, 8, 9, 10, 3, 10, 3, 9, 6, 7, 3, 6, 2],
}


@dataclass
class State:
    hp: int
    energy: int
    phase: int
    combo: int
    elapsed: float
    pos: Vector2
    vel: Vector2
    ball: Vector2
    available: set[int]
    stock: dict[int, int]


@dataclass
class WaveMemory:
    fired_at: float = -999.0
    direction: Direction = Direction.RIGHT
    pending_direction: Direction = Direction.RIGHT
    anchor: Vector2 = field(default_factory=Vector2)
    pending_anchor: Vector2 = field(default_factory=Vector2)
    combo_ids: list[int] = field(default_factory=list)
    pending_combo_ids: list[int] = field(default_factory=list)
    used_combo_counts: dict[int, int] = field(default_factory=dict)
    combo_spent: int = 0
    extra_ring: bool = False
    side_shotgun: bool = False
    bird_basket_sync: bool = True


def _clamp(value: float, low: float, high: float) -> float:
    return max(low, min(high, value))


def _field(v: Vector2, margin: float = 0.0) -> Vector2:
    return Vector2(
        _clamp(v.x, FIELD_MIN + margin, FIELD_MAX - margin),
        _clamp(v.y, FIELD_MIN + margin, FIELD_MAX - margin),
    )


def _box(v: Vector2, half: float) -> Vector2:
    return Vector2(_clamp(v.x, -half, half), _clamp(v.y, -half, half))


def _add(a: Vector2, b: Vector2) -> Vector2:
    return Vector2(a.x + b.x, a.y + b.y)


def _sub(a: Vector2, b: Vector2) -> Vector2:
    return Vector2(a.x - b.x, a.y - b.y)


def _mul(v: Vector2, n: float) -> Vector2:
    return Vector2(v.x * n, v.y * n)


def _length(v: Vector2) -> float:
    return math.hypot(v.x, v.y)


def _unit(v: Vector2, fallback: Vector2 = Vector2(1.0, 0.0)) -> Vector2:
    size = _length(v)
    if size < 0.001:
        return fallback
    return Vector2(v.x / size, v.y / size)


def _predict(s: State, seconds: float, margin: float = 0.0) -> Vector2:
    return _field(_add(s.pos, _mul(s.vel, seconds)), margin)


def _coconut_gate(s: State, seconds: float) -> Vector2:
    to_coconut = _sub(s.ball, s.pos)
    approach = _add(s.ball, _mul(_unit(to_coconut), -45.0))
    predicted = _predict(s, seconds, 4.0)
    if _length(to_coconut) <= 120.0:
        return _field(s.ball, 4.0)
    return _field(
        Vector2(
            approach.x * 0.75 + predicted.x * 0.25,
            approach.y * 0.75 + predicted.y * 0.25,
        ),
        4.0,
    )


def _state(client) -> State:
    elapsed_fn = getattr(client, "get_elapsed_time", None)
    elapsed = elapsed_fn() if elapsed_fn else 0.0
    stock_fn = getattr(client, "get_current_stock", None)
    stock: dict[int, int] = {}
    for trap_id in TRAP_STOCK:
        if trap_id == 1:
            stock[trap_id] = TRAP_STOCK[trap_id]
        elif stock_fn:
            value = stock_fn(trap_id)
            stock[trap_id] = 0 if _failed(value) else int(value)
        else:
            stock[trap_id] = TRAP_STOCK[trap_id]
    return State(
        hp=client.get_my_health(),
        energy=client.get_my_energy(),
        phase=client.get_phase(),
        combo=client.get_opponent_combo(),
        elapsed=elapsed,
        pos=client.get_opponent_player_position(),
        vel=client.get_opponent_player_velocity(),
        ball=client.get_opponent_energy_ball_position(),
        available=set(client.get_available_traps()),
        stock=stock,
    )


def _failed(result: object) -> bool:
    return isinstance(result, ApiError)


def _nearest_edge_origin(target: Vector2) -> Vector2:
    if abs(target.x) >= abs(target.y):
        return Vector2(EDGE if target.x < 0.0 else -EDGE, target.y)
    return Vector2(target.x, EDGE if target.y < 0.0 else -EDGE)


def _shotgun_origin(target: Vector2) -> Vector2:
    if abs(target.x) >= abs(target.y):
        return Vector2(SHOTGUN_EDGE if target.x < 0.0 else -SHOTGUN_EDGE, target.y)
    return Vector2(target.x, SHOTGUN_EDGE if target.y < 0.0 else -SHOTGUN_EDGE)


def _shotgun_origin_for_dir(target: Vector2, direction: Direction) -> Vector2:
    if direction == Direction.RIGHT:
        return Vector2(-SHOTGUN_EDGE, target.y)
    if direction == Direction.LEFT:
        return Vector2(SHOTGUN_EDGE, target.y)
    if direction == Direction.DOWN:
        return Vector2(target.x, -SHOTGUN_EDGE)
    return Vector2(target.x, SHOTGUN_EDGE)


def _opposite_edge_origin(origin: Vector2) -> Vector2:
    if abs(origin.x) >= abs(origin.y):
        return Vector2(-origin.x, origin.y)
    return Vector2(origin.x, -origin.y)


def _arc_through(target: Vector2, velocity: Vector2) -> tuple[Vector2, Vector2]:
    p = _field(target)
    if abs(velocity.x) >= abs(velocity.y):
        return Vector2(p.x, -EDGE), Vector2(p.x, EDGE)
    return Vector2(-EDGE, p.y), Vector2(EDGE, p.y)


def _scan_dir(pos: Vector2) -> Direction:
    if abs(pos.x) >= abs(pos.y):
        return Direction.LEFT if pos.x >= 0.0 else Direction.RIGHT
    return Direction.UP if pos.y >= 0.0 else Direction.DOWN


def _push_dir(pos: Vector2) -> Direction:
    if abs(pos.x) >= abs(pos.y):
        return Direction.RIGHT if pos.x >= 0.0 else Direction.LEFT
    return Direction.DOWN if pos.y >= 0.0 else Direction.UP


def _opposite_dir(direction: Direction) -> Direction:
    if direction == Direction.RIGHT:
        return Direction.LEFT
    if direction == Direction.LEFT:
        return Direction.RIGHT
    if direction == Direction.DOWN:
        return Direction.UP
    return Direction.DOWN


def _perp_dir(direction: Direction, pos: Vector2) -> Direction:
    if direction in (Direction.LEFT, Direction.RIGHT):
        return Direction.DOWN if pos.y <= 0.0 else Direction.UP
    return Direction.RIGHT if pos.x <= 0.0 else Direction.LEFT


def _dir_vec(direction: Direction) -> Vector2:
    return Vector2(direction.value[0], direction.value[1])


def _wall_push_dir(s: State) -> Direction | None:
    predicted = _predict(s, 0.35, 0.0)
    candidates = [
        (FIELD_MAX - max(s.pos.x, predicted.x), Direction.RIGHT),
        (min(s.pos.x, predicted.x) - FIELD_MIN, Direction.LEFT),
        (FIELD_MAX - max(s.pos.y, predicted.y), Direction.DOWN),
        (min(s.pos.y, predicted.y) - FIELD_MIN, Direction.UP),
    ]
    distance, direction = min(candidates, key=lambda item: item[0])
    if distance <= WALL_PUSH_DISTANCE:
        return direction
    return None


def _wave_dir(s: State) -> Direction:
    wall_dir = _wall_push_dir(s)
    if wall_dir is not None:
        return wall_dir

    away_from_coconut = _sub(s.pos, s.ball)
    if _length(away_from_coconut) >= 20.0:
        if abs(away_from_coconut.x) >= abs(away_from_coconut.y):
            return Direction.RIGHT if away_from_coconut.x >= 0.0 else Direction.LEFT
        return Direction.DOWN if away_from_coconut.y >= 0.0 else Direction.UP
    return _push_dir(s.pos)


def _wave_combo_dir(s: State) -> Direction:
    direction = _wave_dir(s)
    return _opposite_dir(direction) if random.random() < 0.2 else direction


def _wave_anchor(s: State) -> Vector2:
    to_coconut = _sub(s.ball, s.pos)
    chase_distance = min(_length(to_coconut) * 0.35, 70.0)
    chase_point = _add(s.pos, _mul(_unit(to_coconut), chase_distance))
    predicted = _predict(s, 0.25, 0.0)
    anchor = Vector2(
        chase_point.x * 0.7 + predicted.x * 0.3,
        chase_point.y * 0.7 + predicted.y * 0.3,
    )
    return _box(anchor, 100.0)


def _wave_lane(anchor: Vector2, direction: Direction, distance: float) -> Vector2:
    return _field(_add(anchor, _mul(_dir_vec(direction), distance)), 4.0)


def _perp(v: Vector2) -> Vector2:
    return Vector2(-v.y, v.x)


def _phase_energy_cap(phase: int) -> int:
    index = max(0, min(phase, len(MAX_ENERGY_BY_PHASE) - 1))
    return MAX_ENERGY_BY_PHASE[index]


def _weighted_unique_candidates(phase: int) -> list[int]:
    pool = WAVE_POOLS_BY_PHASE.get(
        min(max(phase, MID_PHASE), 5), WAVE_POOLS_BY_PHASE[5]
    )
    candidates: list[int] = []
    for trap_id in pool:
        if trap_id not in candidates:
            candidates.append(trap_id)
    return candidates


def _stock_cap(trap_id: int) -> int:
    return TRAP_STOCK.get(trap_id, 1)


def _choose_wave_subset(s: State) -> list[int]:
    budget = _phase_energy_cap(s.phase) - TRAP_COST[WAVE_TRAP_ID]
    candidates = [
        trap_id
        for trap_id in WAVE_POOLS_BY_PHASE.get(
            min(max(s.phase, MID_PHASE), 5), WAVE_POOLS_BY_PHASE[5]
        )
        if s.stock.get(trap_id, 0) > 0
    ]
    random.shuffle(candidates)

    chosen: list[int] = []
    spent = 0

    def add_if_room(trap_id: int) -> bool:
        nonlocal spent
        if trap_id not in candidates:
            return False
        if trap_id == 8 and chosen.count(trap_id) >= 1:
            return False
        if chosen.count(trap_id) >= _stock_cap(trap_id):
            return False
        cost = TRAP_COST[trap_id]
        if spent + cost > budget:
            return False
        chosen.append(trap_id)
        spent += cost
        candidates.remove(trap_id)
        return True

    scan_chance = {1: 0.88, 2: 0.72, 3: 0.72, 4: 0.75, 5: 0.72}.get(s.phase, 0.78)
    ripple_chance = {2: 0.68, 3: 0.68, 4: 0.68, 5: 0.7}.get(s.phase, 0.72)
    arc_chance = {1: 0.28, 2: 0.34, 3: 0.44, 4: 0.52, 5: 0.48}.get(s.phase, 0.35)
    mortar_chance = {1: 0.68, 2: 0.58, 3: 0.52, 4: 0.72, 5: 0.85}.get(s.phase, 0.35)
    shotgun_chance = {1: 0.42, 2: 0.5, 3: 0.6, 4: 0.72, 5: 0.82}.get(s.phase, 0.25)
    bird_chance = {1: 0.74, 2: 0.68, 3: 0.68, 4: 0.78, 5: 0.84}.get(s.phase, 0.25)

    ring_chance = {1: 0.42, 2: 0.52, 3: 0.58, 4: 0.42, 5: 0.45}.get(s.phase, 0.0)
    if 2 in candidates and random.random() < ring_chance:
        add_if_room(2)

    shot_bird_chance = {2: 0.1, 3: 0.24, 4: 0.3, 5: 0.4}.get(s.phase, 0.0)
    if 10 in candidates and 3 in candidates and random.random() < shot_bird_chance:
        add_if_room(10)
        add_if_room(3)

    if s.phase in (2, 3, 4, 5) and 6 in candidates and 7 in candidates:
        pair_chance = {2: 0.16, 3: 0.16, 4: 0.16, 5: 0.3}[s.phase]
        roll = random.random()
        if roll < pair_chance:
            add_if_room(6)
            add_if_room(7)
        elif roll < pair_chance + (0.22 if s.phase == 2 else 0.3):
            add_if_room(6)
        elif s.phase not in (2, 5) or roll < pair_chance + 0.48:
            add_if_room(7)
    else:
        if 6 in candidates and random.random() < scan_chance:
            add_if_room(6)
        if 7 in candidates and random.random() < ripple_chance:
            add_if_room(7)
    second_scan_chance = {2: 0.28, 3: 0.42, 4: 0.5, 5: 0.48}.get(s.phase, 0.0)
    if chosen.count(6) == 1 and random.random() < second_scan_chance:
        add_if_room(6)
    if 8 in candidates and random.random() < arc_chance:
        add_if_room(8)
    if 9 in candidates and random.random() < mortar_chance:
        add_if_room(9)
    if 10 in candidates and random.random() < shotgun_chance:
        add_if_room(10)
    if 10 in chosen and 3 in candidates and random.random() < 0.5:
        add_if_room(3)
    if 3 in candidates and random.random() < bird_chance:
        add_if_room(3)

    duplicate_chance = {1: 0.34, 2: 0.42, 3: 0.48, 4: 0.5, 5: 0.6}.get(s.phase, 0.2)
    if random.random() < duplicate_chance:
        duplicate_pool = [6, 3, 10, 3, 9, 6, 7]
        random.shuffle(duplicate_pool)
        for trap_id in duplicate_pool:
            if chosen.count(trap_id) == 1 and add_if_room(trap_id):
                break

    if s.phase >= 5 and random.random() < 0.65:
        late_pool = [3, 10, 3, 9, 10, 3, 6, 7]
        random.shuffle(late_pool)
        for trap_id in late_pool:
            if add_if_room(trap_id):
                break
    if s.phase >= 4 and random.random() < 0.35:
        add_if_room(random.choice([3, 10, 9]))
    if s.phase >= 5 and random.random() < 0.45:
        add_if_room(9)

    target_size = min(len(candidates) + len(chosen), random.randint(3, 5))
    for trap_id in candidates[:]:
        if len(chosen) >= target_size:
            break
        add_if_room(trap_id)

    return chosen


def _wave_combo_cost(combo_ids: list[int]) -> int:
    return TRAP_COST[WAVE_TRAP_ID] + sum(TRAP_COST[trap_id] for trap_id in combo_ids)


def _use_side_shotgun(combo_ids: list[int], phase: int) -> bool:
    return 10 in combo_ids


def _combo_remaining(combo_ids: list[int], memory: WaveMemory, trap_id: int) -> bool:
    return memory.used_combo_counts.get(trap_id, 0) < combo_ids.count(trap_id)


def _combo_use_count(memory: WaveMemory, trap_id: int) -> int:
    return memory.used_combo_counts.get(trap_id, 0)


def _can_use_stock(s: State, used_counts: dict[int, int], trap_id: int) -> bool:
    remaining_stock = s.stock.get(trap_id, _stock_cap(trap_id)) - used_counts.get(
        trap_id, 0
    )
    return trap_id in s.available and remaining_stock > 0


def _has_stock_for_combo(s: State, combo_ids: list[int]) -> bool:
    for trap_id in set(combo_ids):
        if combo_ids.count(trap_id) > s.stock.get(trap_id, 0):
            return False
    return True


def _offset_lane(
    anchor: Vector2, direction: Direction, distance: float, lateral: float
) -> Vector2:
    forward = _dir_vec(direction)
    side = _perp(forward)
    return _field(_add(_add(anchor, _mul(forward, distance)), _mul(side, lateral)), 4.0)


def _wave_combo_variant_target(
    anchor: Vector2, direction: Direction, distance: float, use_count: int
) -> Vector2:
    lateral = 0.0 if use_count == 0 else random.choice([-1.0, 1.0]) * 42.0
    return _offset_lane(anchor, direction, distance + use_count * 38.0, lateral)


def _wave_combo_variant_wide_target(
    anchor: Vector2, direction: Direction, distance: float, use_count: int
) -> Vector2:
    lateral = 0.0 if use_count == 0 else random.choice([-1.0, 1.0]) * 65.0
    return _offset_lane(anchor, direction, distance + use_count * 45.0, lateral)


def _wave_ripple_target(
    anchor: Vector2, direction: Direction, use_count: int
) -> Vector2:
    if use_count == 0:
        distance = random.uniform(90.0, 165.0)
        lateral = random.choice([-1.0, 1.0]) * random.uniform(45.0, 95.0)
    else:
        distance = random.uniform(130.0, 215.0)
        lateral = random.choice([-1.0, 1.0]) * random.uniform(85.0, 145.0)
    return _offset_lane(anchor, direction, distance, lateral)


def _wave_arc_target(anchor: Vector2, direction: Direction, use_count: int) -> Vector2:
    if use_count == 0:
        distance = random.uniform(-35.0, 65.0)
        lateral = random.uniform(-55.0, 55.0)
    else:
        distance = random.uniform(-55.0, 75.0)
        lateral = random.uniform(-95.0, 95.0)
    lane_target = _offset_lane(anchor, direction, distance, lateral)
    return _field(
        Vector2(
            lane_target.x * 0.35 + random.uniform(-35.0, 35.0),
            lane_target.y * 0.35 + random.uniform(-35.0, 35.0),
        ),
        8.0,
    )


def _wave_arc_vec(direction: Direction, use_count: int) -> Vector2:
    forward = _dir_vec(direction)
    if use_count == 0:
        return forward
    return _perp(forward)


def _wave_combo_variant_scan_dir(
    direction: Direction, anchor: Vector2, use_count: int
) -> Direction:
    if use_count == 0:
        return _opposite_dir(direction)
    return _perp_dir(direction, anchor)


def _scan_speed(use_count: int) -> float:
    return 250.0 if use_count == 0 else 165.0


def _ripple_rate(use_count: int) -> float:
    return 165.0 if use_count == 0 else 120.0


def _mortar_air_time(speed: float, use_count: int) -> float:
    base = 1.5 if speed < 220.0 else 1.75
    return min(2.4, base + use_count * 0.45)


def _bird_speed(use_count: int) -> float:
    return 300.0 if use_count == 0 else 225.0


def _shotgun_spread(use_count: int) -> float:
    return 0.24 if use_count == 0 else 0.36


def _wave_ring_radius(speed: float) -> float:
    if speed > 180.0:
        return random.uniform(110.0, 150.0)
    return random.uniform(100.0, 140.0)


def _wave_memory_active(s: State, memory: WaveMemory) -> bool:
    return s.elapsed - memory.fired_at <= WAVE_MEMORY_SEC


def _combo_has_budget(s: State, memory: WaveMemory, trap_id: int) -> bool:
    cost = TRAP_COST[trap_id]
    return cost <= s.energy and memory.combo_spent + cost <= _phase_energy_cap(s.phase)


def _shotgun_dirs(
    origin: Vector2, target: Vector2, spread: float = 0.24
) -> tuple[Vector2, Vector2, Vector2]:
    main = _unit(_sub(target, origin))
    side = Vector2(-main.y, main.x)
    return (
        _unit(_add(main, _mul(side, spread))),
        main,
        _unit(_add(main, _mul(side, -spread))),
    )


def _wave_shotgun_setup(
    anchor: Vector2, direction: Direction, use_count: int, side_mode: bool = False
) -> tuple[Vector2, Vector2]:
    if side_mode:
        target = _wave_lane(anchor, direction, 0.0)
        shotgun_dir = _perp_dir(direction, target) if use_count % 2 == 0 else direction
        origin = _shotgun_origin_for_dir(target, shotgun_dir)
        if _length(_sub(target, origin)) < 220.0:
            origin = _shotgun_origin_for_dir(target, _opposite_dir(shotgun_dir))
        return origin, target
    if use_count == 0:
        origin_hint = _wave_lane(anchor, direction, 230.0)
        target = _wave_lane(anchor, direction, 35.0)
        return _shotgun_origin(origin_hint), target
    target = _wave_lane(anchor, direction, 170.0)
    shotgun_dir = _perp_dir(direction, target)
    return _shotgun_origin_for_dir(target, shotgun_dir), target


def _try(client, trap_id: int, name: str, action) -> tuple[bool, str]:
    result = action()
    if _failed(result):
        return False, ""
    return True, f"{trap_id}:{name}"


def _early_plan(
    client, s: State, used_counts: dict[int, int]
) -> list[tuple[int, str, object]]:
    gate = _coconut_gate(s, 1.3)
    path = _unit(_sub(s.ball, s.pos), _unit(s.vel))
    speed = _length(s.vel)
    plan = []

    if 9 in s.available and used_counts.get(9, 0) == 0:
        air_time = 1.5 if speed < 220.0 else 1.75
        target = _coconut_gate(s, air_time)
        origin = _nearest_edge_origin(target)
        plan.append(
            (
                9,
                "early-coconut-mortar",
                lambda origin=origin, target=target, air_time=air_time: (
                    client.spawn_trap9(origin, target, air_time)
                ),
            )
        )

    if 8 in s.available and used_counts.get(8, 0) == 0:
        start, end = _arc_through(gate, path)
        plan.append(
            (
                8,
                "early-coconut-arc",
                lambda start=start, end=end: client.spawn_trap8(start, end),
            )
        )

    if 3 in s.available and used_counts.get(3, 0) == 0:
        origin = _nearest_edge_origin(gate)
        direction = _unit(_sub(gate, origin))
        plan.append(
            (
                3,
                "early-coconut-bird",
                lambda origin=origin, direction=direction: client.spawn_trap3(
                    origin, direction, 300.0
                ),
            )
        )

    if 2 in s.available and used_counts.get(2, 0) == 0:
        radius = _wave_ring_radius(speed)
        plan.append(
            (2, "early-ring", lambda radius=radius: client.spawn_trap2(1.0, radius))
        )

    if 7 in s.available and used_counts.get(7, 0) == 0:
        target = Vector2(
            _clamp(gate.x, -400.0, 400.0),
            _clamp(gate.y, -280.0, 280.0),
        )
        plan.append(
            (
                7,
                "early-coconut-ripple",
                lambda target=target: client.spawn_trap7(target, 200.0),
            )
        )

    return plan


def _wave_combo_plan(
    client, s: State, used_counts: dict[int, int], memory: WaveMemory
) -> list[tuple[int, str, object]]:
    has_fresh_wave = _can_use_stock(s, used_counts, 4)
    direction = memory.direction
    anchor = memory.anchor
    speed = _length(s.vel)
    plan = []

    if has_fresh_wave:
        direction = _wave_combo_dir(s)
        anchor = _wave_anchor(s)
        combo_ids = _choose_wave_subset(s)
        if not combo_ids:
            return plan
        if not _has_stock_for_combo(s, combo_ids):
            return plan
        if s.energy < _wave_combo_cost(combo_ids):
            return plan
        memory.pending_direction = direction
        memory.pending_anchor = anchor
        memory.pending_combo_ids = combo_ids
        memory.side_shotgun = _use_side_shotgun(combo_ids, s.phase)
        plan.append(
            (
                4,
                "wave-combo-start",
                lambda target=anchor, direction=direction: client.spawn_trap4(
                    target, direction
                ),
            )
        )
        return plan
    elif not _wave_memory_active(s, memory):
        memory.pending_combo_ids = []
        return plan

    combo_ids = (
        memory.combo_ids if memory.combo_ids else _weighted_unique_candidates(s.phase)
    )
    partners = []

    if (
        not memory.extra_ring
        and not _combo_remaining(combo_ids, memory, 2)
        and _can_use_stock(s, used_counts, 2)
        and _combo_has_budget(s, memory, 2)
    ):
        radius = _wave_ring_radius(speed)
        partners.append(
            (
                2,
                "wave-bonus-ring",
                lambda radius=radius: client.spawn_trap2(1.0, radius),
            )
        )

    if (
        _combo_remaining(combo_ids, memory, 8)
        and _can_use_stock(s, used_counts, 8)
        and _combo_has_budget(s, memory, 8)
    ):
        arc_count = _combo_use_count(memory, 8)
        arc_target = _wave_arc_target(anchor, direction, arc_count)
        arc_vec = _wave_arc_vec(direction, arc_count)
        start, end = _arc_through(arc_target, arc_vec)
        partners.append(
            (
                8,
                "wave-into-arc",
                lambda start=start, end=end: client.spawn_trap8(start, end),
            )
        )

    if (
        _combo_remaining(combo_ids, memory, 7)
        and _can_use_stock(s, used_counts, 7)
        and _combo_has_budget(s, memory, 7)
    ):
        ripple_target = _wave_ripple_target(
            anchor, direction, _combo_use_count(memory, 7)
        )
        target = Vector2(
            _clamp(ripple_target.x, -400.0, 400.0),
            _clamp(ripple_target.y, -280.0, 280.0),
        )
        expand_rate = _ripple_rate(_combo_use_count(memory, 7))
        partners.append(
            (
                7,
                "wave-into-ripple",
                lambda target=target, expand_rate=expand_rate: client.spawn_trap7(
                    target, expand_rate
                ),
            )
        )

    if (
        _combo_remaining(combo_ids, memory, 9)
        and _can_use_stock(s, used_counts, 9)
        and _combo_has_budget(s, memory, 9)
    ):
        mortar_target = _wave_combo_variant_wide_target(
            anchor, direction, 170.0, _combo_use_count(memory, 9)
        )
        air_time = _mortar_air_time(speed, _combo_use_count(memory, 9))
        origin = _nearest_edge_origin(mortar_target)
        partners.append(
            (
                9,
                "wave-into-mortar",
                lambda origin=origin, target=mortar_target, air_time=air_time: (
                    client.spawn_trap9(origin, target, air_time)
                ),
            )
        )

    if (
        _combo_remaining(combo_ids, memory, 2)
        and _can_use_stock(s, used_counts, 2)
        and _combo_has_budget(s, memory, 2)
    ):
        radius = _wave_ring_radius(speed)
        partners.append(
            (
                2,
                "wave-pressure-ring",
                lambda radius=radius: client.spawn_trap2(1.0, radius),
            )
        )

    if (
        _combo_remaining(combo_ids, memory, 6)
        and _can_use_stock(s, used_counts, 6)
        and _combo_has_budget(s, memory, 6)
    ):
        sweep_dir = _wave_combo_variant_scan_dir(
            direction, anchor, _combo_use_count(memory, 6)
        )
        scan_speed = _scan_speed(_combo_use_count(memory, 6))
        partners.append(
            (
                6,
                "wave-tail-sweep",
                lambda direction=sweep_dir, scan_speed=scan_speed: client.spawn_trap6(
                    direction, scan_speed
                ),
            )
        )

    if (
        _combo_remaining(combo_ids, memory, 3)
        and _can_use_stock(s, used_counts, 3)
        and _combo_has_budget(s, memory, 3)
    ):
        bird_count = _combo_use_count(memory, 3)
        if 10 in combo_ids and bird_count == 0 and memory.bird_basket_sync:
            shotgun_use = max(0, _combo_use_count(memory, 10) - 1)
            origin, bird_target = _wave_shotgun_setup(
                anchor, direction, shotgun_use, memory.side_shotgun
            )
        else:
            bird_target = _wave_combo_variant_target(
                anchor, direction, 125.0, bird_count
            )
            origin = _nearest_edge_origin(bird_target)
            if bird_count > 0:
                origin = _opposite_edge_origin(origin)
        bird_dir = _unit(_sub(bird_target, origin))
        bird_speed = _bird_speed(bird_count)
        partners.append(
            (
                3,
                "wave-into-bird",
                lambda origin=origin, direction=bird_dir, bird_speed=bird_speed: (
                    client.spawn_trap3(origin, direction, bird_speed)
                ),
            )
        )

    if (
        _combo_remaining(combo_ids, memory, 10)
        and _can_use_stock(s, used_counts, 10)
        and _combo_has_budget(s, memory, 10)
    ):
        use_count = _combo_use_count(memory, 10)
        origin, shotgun_target = _wave_shotgun_setup(
            anchor, direction, use_count, memory.side_shotgun
        )
        dirs = _shotgun_dirs(origin, shotgun_target, _shotgun_spread(use_count))
        partners.append(
            (
                10,
                "wave-tail-shotgun",
                lambda origin=origin, dirs=dirs: client.spawn_trap10(origin, *dirs),
            )
        )

    id_order: dict[int, int] = {}
    for index, trap_id in enumerate(combo_ids):
        id_order.setdefault(trap_id, index)

    def partner_priority(item: tuple[int, str, object]) -> float:
        trap_id = item[0]
        if trap_id == 10 and 3 in combo_ids:
            return float(id_order.get(10, 997))
        if trap_id == 3 and 10 in combo_ids:
            return float(id_order.get(10, 997)) + 0.1
        if trap_id == 2 and _combo_remaining(combo_ids, memory, 2):
            return 0.05 if s.phase <= 3 else min(float(id_order.get(2, 997)), 2.2)
        if trap_id == 2 and not _combo_remaining(combo_ids, memory, 2):
            return 0.25 if s.phase <= 3 else 3.2
        if trap_id == 5:
            return 998.0
        return float(id_order.get(trap_id, 997))

    partners.sort(key=partner_priority)
    return plan + partners


def _attack_plan(
    client, s: State, used_counts: dict[int, int], memory: WaveMemory
) -> list[tuple[int, str, object]]:
    if s.phase < MID_PHASE:
        return _early_plan(client, s, used_counts)
    return _wave_combo_plan(client, s, used_counts, memory)


def _heal_if_desperate(client, s: State) -> bool:
    if s.hp > 1 or s.energy < 25:
        return False
    result = client.heal()
    if _failed(result):
        return False
    print(f"[agent] emergency heal hp={result['health']} energy={result['energy']}")
    return True


def _burst(client, s: State, memory: WaveMemory) -> str:
    fired = []
    used_counts: dict[int, int] = {}
    burst_size = WAVE_BURST_SIZE if s.phase >= MID_PHASE else BURST_SIZE

    for _ in range(burst_size):
        accepted = False
        for trap_id, name, action in _attack_plan(client, s, used_counts, memory):
            ok, label = _try(client, trap_id, name, action)
            if ok:
                fired.append(label)
                used_counts[trap_id] = used_counts.get(trap_id, 0) + 1
                s.energy = max(0, s.energy - TRAP_COST.get(trap_id, 0))
                if used_counts[trap_id] >= _stock_cap(trap_id):
                    s.available.discard(trap_id)
                if trap_id == 4:
                    memory.fired_at = s.elapsed
                    memory.direction = memory.pending_direction
                    memory.anchor = memory.pending_anchor
                    memory.combo_ids = memory.pending_combo_ids or _choose_wave_subset(
                        s
                    )
                    memory.pending_combo_ids = []
                    memory.used_combo_counts = {}
                    memory.combo_spent = TRAP_COST[trap_id]
                    memory.extra_ring = False
                    memory.side_shotgun = _use_side_shotgun(memory.combo_ids, s.phase)
                    memory.bird_basket_sync = (
                        3 not in memory.combo_ids
                        or 10 not in memory.combo_ids
                        or random.random() < 0.66
                    )
                    fired[-1] = f"{label}[{','.join(map(str, memory.combo_ids))}]"
                elif trap_id == 2 and trap_id not in memory.combo_ids:
                    memory.combo_spent += TRAP_COST[trap_id]
                    memory.extra_ring = True
                elif s.phase >= MID_PHASE:
                    memory.combo_spent += TRAP_COST[trap_id]
                    memory.used_combo_counts[trap_id] = (
                        memory.used_combo_counts.get(trap_id, 0) + 1
                    )
                accepted = True
                break
        if not accepted:
            break

    return " + ".join(fired) if fired else "nothing"


def run(client) -> None:
    client.print_api_errors = False
    last_log = -999.0
    wave_memory = WaveMemory()

    while True:
        try:
            s = _state(client)
            action = (
                "heal"
                if _heal_if_desperate(client, s)
                else _burst(client, s, wave_memory)
            )

            if s.elapsed - last_log >= LOG_EVERY:
                print(
                    "[agent] "
                    f"t={s.elapsed:6.1f} hp={s.hp}/{MAX_HP} e={s.energy:2d} "
                    f"p={s.phase} c={s.combo} "
                    f"pos=({s.pos.x:6.1f},{s.pos.y:6.1f}) "
                    f"vel=({s.vel.x:6.1f},{s.vel.y:6.1f}) -> {action}"
                )
                last_log = s.elapsed
        except Exception as exc:
            print(f"[agent] loop recovered: {exc}")

        time.sleep(LOOP_DELAY)
