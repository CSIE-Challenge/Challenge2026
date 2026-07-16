import math
import random
import time
from dataclasses import dataclass, field

from api import ApiError, Direction, Vector2

FIELD_MIN = -220.0
FIELD_MAX = 220.0
EDGE = 275.0
ARC_FIELD_MARGIN = 48.0
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
ENERGY_REGEN_PERIOD = [0.5, 0.35, 0.28, 0.2, 0.13, 0.1]
COCONUT_EXPECTED_GAIN = [3, 5, 7, 8, 10, 18]
TRAP_COST = {
    2: 15,
    3: 13,
    4: 20,
    6: 20,
    7: 20,
    8: 12,
    10: 18,
}
TRAP_STOCK = {2: 1, 3: 2, 4: 1, 6: 2, 7: 2, 8: 1, 10: 2}
WAVE_TRAP_ID = 4
WAVE_POOLS_BY_PHASE = {
    1: [6, 2, 8, 10, 3, 10, 3, 10],
    2: [6, 2, 7, 8, 10, 3, 10, 3, 10, 6],
    3: [6, 2, 7, 8, 10, 3, 10, 3, 6, 7, 10],
    4: [6, 7, 8, 10, 3, 10, 3, 6, 7, 10, 2],
    5: [6, 7, 8, 10, 3, 10, 3, 6, 7, 10, 6, 2],
}

# Phase-indexed probabilities use [phase0, phase1, ..., phase5].
SCAN_CHANCE = [0.78, 0.88, 0.72, 0.72, 0.75, 0.72]
RIPPLE_CHANCE = [0.72, 0.72, 0.68, 0.68, 0.68, 0.7]
ARC_CHANCE = [0.35, 0.28, 0.34, 0.44, 0.52, 0.48]
SHOTGUN_CHANCE = [0.38, 0.62, 0.68, 0.78, 0.86, 0.92]
BIRD_CHANCE = [0.25, 0.74, 0.68, 0.68, 0.78, 0.84]
RING_CHANCE = [0.0, 0.42, 0.52, 0.58, 0.42, 0.45]
SHOT_BIRD_CHANCE = [0.0, 0.0, 0.1, 0.24, 0.3, 0.4]
SECOND_SCAN_CHANCE = [0.0, 0.18, 0.35, 0.34, 0.6, 0.64]
DOUBLE_SCAN_PRIORITY_CHANCE = [0.0, 0.0, 0.18, 0.18, 0.42, 0.45]
DUPLICATE_CHANCE = [0.2, 0.34, 0.42, 0.48, 0.5, 0.6]

# Single-value probabilities below are also intended as tuning knobs.
BIRD_AFTER_SHOTGUN_CHANCE = 0.6
WAVE_RANDOM_DIR_CHANCE = 0.12
WAVE_REVERSE_DIR_CHANCE = 0.2
BURST_FULL_ENERGY_BONUS_CHANCE = 0.55
BURST_SIZE_CHOICES = [2, 2, 3, 3, 4]
SCAN_RIPPLE_PAIR_CHANCE = [0.0, 0.0, 0.16, 0.16, 0.16, 0.3]
SCAN_ONLY_AFTER_PAIR_ROLL = [0.0, 0.0, 0.38, 0.46, 0.46, 0.6]
RIPPLE_AFTER_PAIR_ROLL = [0.0, 0.0, 0.64, 0.64, 0.64, 0.78]
LATE_POOL_CHANCE = 0.65
LATE_RANDOM_DAMAGE_CHANCE = 0.35
BIRD_BASKET_SYNC_CHANCE = 0.66
RIPPLE_CENTER_CHANCE = 0.25
ARC_BASE_AXIS_CHANCE = 0.5
ARC_DIAGONAL_CHANCE = 0.25
SCAN_FIRST_REVERSE_CHANCE = 0.72
SCAN_LATER_PERP_CHANCE = 0.62
SHOTGUN_FREE_AIM_CHANCE = 0.25
SHOTGUN_RANDOM_AXIS_CHANCE = 0.25
SHOTGUN_LATER_RANDOM_AXIS_CHANCE = 0.2
EARLY_PATH_JITTER_CHANCE = 0.35
EARLY_BIRD_OPPOSITE_CHANCE = 0.25

# Per-wave style weights. Increase a style weight to see that family more often.
COMBO_STYLE_WEIGHTS = [
    ("scan", 1.25),
    ("shotgun_bird", 1.45),
    ("anti_jump", 1.1),
    ("bird_ripple", 0.85),
    ("ripple_ring", 0.85),
    ("arc_ripple", 0.95),
    ("ring", 0.7),
    ("mixed", 1.0),
]
STYLE_OPENERS = {
    "scan": [6, 6],
    "shotgun_bird": [10, 3],
    "anti_jump": [6, 3, 10],
    "bird_ripple": [3, 3, 7, 7],
    "ripple_ring": [7, 7, 2],
    "arc_ripple": [8, 7, 10],
    "ring": [2, 7],
    "mixed": [],
}
STYLE_DUPLICATE_CANDIDATES = {
    "bird_ripple": [3, 7],
    "ripple_ring": [7],
}
MIN_SCAN_RIPPLE_BY_PHASE = [0, 0, 0, 2, 2, 3]
STYLE_EXTRA_CHANCE = {
    "scan": [(7, 0.35), (8, 0.3), (3, 0.25)],
    "shotgun_bird": [(10, 0.55), (3, 0.45), (8, 0.2)],
    "anti_jump": [(6, 0.45), (8, 0.35), (10, 0.6), (3, 0.35), (7, 0.25)],
    "bird_ripple": [(7, 0.55), (3, 0.45), (2, 0.25)],
    "ripple_ring": [(7, 0.55), (3, 0.35), (8, 0.25)],
    "arc_ripple": [(8, 0.35), (7, 0.4), (10, 0.55)],
    "ring": [(2, 0.25), (8, 0.35), (7, 0.35)],
    "mixed": [],
}
STYLE_IMMEDIATE_CHANCE = {
    "scan": 0.75,
    "shotgun_bird": 0.72,
    "anti_jump": 0.72,
    "bird_ripple": 0.7,
    "ripple_ring": 0.62,
    "arc_ripple": 0.45,
    "ring": 0.5,
    "mixed": 0.62,
}
STYLE_GAP_RANGE = {
    "scan": (0.04, 0.14),
    "shotgun_bird": (0.06, 0.2),
    "anti_jump": (0.04, 0.16),
    "bird_ripple": (0.05, 0.16),
    "ripple_ring": (0.06, 0.18),
    "arc_ripple": (0.08, 0.24),
    "ring": (0.08, 0.26),
    "mixed": (0.06, 0.22),
}
STYLE_BURST_CHOICES = {
    "scan": [2, 2, 3],
    "shotgun_bird": [3, 3, 4],
    "anti_jump": [2, 3, 3, 4],
    "bird_ripple": [3, 3, 4],
    "ripple_ring": [2, 3, 3],
    "arc_ripple": [2, 3, 4],
    "ring": [2, 3, 3],
    "mixed": [2, 3, 4],
}
FULL_ENERGY_IGNORE_TIMING_CHANCE = 0.7
NO_WAVE_COMBO_CHANCE = 0.08
NO_WAVE_MIN_GAP_SEC = 24.0
DELAYED_WAVE_COMBO_CHANCE = 0.0
DELAYED_WAVE_MIN_GAP_SEC = 0.0
DELAYED_WAVE_JITTER_RANGE = (-0.12, 0.18)
TEMPO_SCAN_DELAYS = (0.72, 1.02)
TEMPO_RIPPLE_DELAYS = (1.14, 1.4)
SCAN_TEMPO_MODE_WEIGHTS = [
    ("same", 0.3),
    ("pincer", 0.36),
    ("perp", 0.34),
]
AFTERSHOCK_DELAY_RANGE = (0.08, 0.28)
AFTERSHOCK_FULL_ENERGY_DELAY_RANGE = (0.03, 0.08)
AFTERSHOCK_ENDING_DELAY_RANGE = (0.03, 0.1)
AFTERSHOCK_STOP_AFTER_SEC = 7.4
AFTERSHOCK_ARC_STOP_AFTER_SEC = 4.7
AFTERSHOCK_ARC_ON_COCONUT_CHANCE = 0.42
WAVE_RECYCLE_ENERGY_MARGIN = 8
AFTERSHOCK_MAX_TRAPS = 12
AFTERSHOCK_MIN_ENERGY = 12
AFTERSHOCK_END_RESERVE_SEC = 0.25
AFTERSHOCK_SPEND_FRACTION = 1.3
AFTERSHOCK_COCONUT_GAIN_FRACTION = 0.8
AFTERSHOCK_RESERVE_SOFTEN = 0.45
AFTERSHOCK_GREED_MARGIN = 1
AFTERSHOCK_MAX_PER_TRAP = {}
AFTERSHOCK_SHOTGUN_FRONT_CHANCE = 0.78
AFTERSHOCK_TARGET_MODE_WEIGHTS = [
    ("player", 0.46),
    ("coconut", 0.34),
    ("intercept", 0.16),
    ("wave_noise", 0.04),
]
AFTERSHOCK_POOL_BY_STYLE = {
    "scan": [6, 10, 8, 3, 10, 7, 2],
    "shotgun_bird": [10, 3, 10, 8, 6, 7, 2],
    "anti_jump": [6, 10, 3, 10, 8, 7, 2],
    "bird_ripple": [3, 7, 10, 3, 7, 8, 2, 10],
    "ripple_ring": [7, 10, 2, 7, 3, 8, 6],
    "arc_ripple": [8, 10, 7, 3, 10, 6, 2],
    "ring": [2, 10, 8, 3, 10, 6, 7],
    "mixed": [10, 8, 3, 10, 6, 7, 2],
}
PlanItem = tuple[int, str, object]


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
    style: str = "mixed"
    pending_style: str = "mixed"
    next_ready_at: float = -999.0
    aftershock_used: int = 0
    aftershock_counts: dict[int, int] = field(default_factory=dict)
    aftershock_ready_at: float = -999.0
    last_no_wave_at: float = -999.0
    delayed_wave_pending: bool = False
    delayed_wave_ready_at: float = -999.0
    last_delayed_wave_at: float = -999.0
    delayed_wave_cue: tuple | None = None
    tempo_scan_mode: str = ""
    tempo_scan_first_dir: Direction = Direction.RIGHT
    last_ripple_target: Vector2 | None = None


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


def _random_vec() -> Vector2:
    angle = random.uniform(0.0, math.tau)
    return Vector2(math.cos(angle), math.sin(angle))


def _all_dirs() -> list[Direction]:
    return [Direction.UP, Direction.DOWN, Direction.LEFT, Direction.RIGHT]


def _predict(s: State, seconds: float, margin: float = 0.0) -> Vector2:
    return _field(_add(s.pos, _mul(s.vel, seconds)), margin)


def _coconut_gate(s: State, seconds: float) -> Vector2:
    to_coconut = _sub(s.ball, s.pos)
    approach = _add(s.ball, _mul(_unit(to_coconut), -random.uniform(30.0, 62.0)))
    predicted = _predict(s, seconds, 4.0)
    if _length(to_coconut) <= 120.0:
        return _field(_add(s.ball, _mul(_random_vec(), random.uniform(0.0, 18.0))), 4.0)
    approach_weight = random.uniform(0.62, 0.84)
    return _field(
        Vector2(
            approach.x * approach_weight + predicted.x * (1.0 - approach_weight),
            approach.y * approach_weight + predicted.y * (1.0 - approach_weight),
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


def _ray_to_edge(p: Vector2, axis: Vector2) -> Vector2:
    ts = []
    if abs(axis.x) > 0.001:
        ts += [(EDGE - p.x) / axis.x, (-EDGE - p.x) / axis.x]
    if abs(axis.y) > 0.001:
        ts += [(EDGE - p.y) / axis.y, (-EDGE - p.y) / axis.y]
    return _add(p, _mul(axis, min(t for t in ts if t > 0.0)))


def _arc_through(target: Vector2, velocity: Vector2) -> tuple[Vector2, Vector2]:
    p = _field(target, ARC_FIELD_MARGIN)
    axis = _unit(velocity)
    if abs(axis.x) < 0.01 and abs(axis.y) < 0.01:
        axis = _random_vec()
    return _ray_to_edge(p, _mul(axis, -1.0)), _ray_to_edge(p, axis)


def _push_dir(pos: Vector2) -> Direction:
    if abs(pos.x) >= abs(pos.y):
        return Direction.RIGHT if pos.x >= 0.0 else Direction.LEFT
    return Direction.DOWN if pos.y >= 0.0 else Direction.UP


def _dir_toward(source: Vector2, target: Vector2) -> Direction:
    delta = _sub(target, source)
    if _length(delta) < 8.0:
        return _push_dir(source)
    return _push_dir(delta)


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
    if random.random() < WAVE_RANDOM_DIR_CHANCE:
        return random.choice(_all_dirs())
    if random.random() < WAVE_REVERSE_DIR_CHANCE:
        return _opposite_dir(direction)
    return direction


def _wave_anchor(s: State) -> Vector2:
    to_coconut = _sub(s.ball, s.pos)
    chase_distance = min(_length(to_coconut) * random.uniform(0.25, 0.45), 80.0)
    chase_point = _add(s.pos, _mul(_unit(to_coconut), chase_distance))
    predicted = _predict(s, random.uniform(0.12, 0.36), 0.0)
    chase_weight = random.uniform(0.6, 0.8)
    anchor = Vector2(
        chase_point.x * chase_weight + predicted.x * (1.0 - chase_weight),
        chase_point.y * chase_weight + predicted.y * (1.0 - chase_weight),
    )
    return _box(_add(anchor, _mul(_random_vec(), random.uniform(0.0, 18.0))), 100.0)


def _wave_lane(anchor: Vector2, direction: Direction, distance: float) -> Vector2:
    return _field(_add(anchor, _mul(_dir_vec(direction), distance)), 4.0)


def _perp(v: Vector2) -> Vector2:
    return Vector2(-v.y, v.x)


def _phase_energy_cap(phase: int) -> int:
    index = max(0, min(phase, len(MAX_ENERGY_BY_PHASE) - 1))
    return MAX_ENERGY_BY_PHASE[index]


def _phase_regen_rate(phase: int) -> float:
    index = max(0, min(phase, len(ENERGY_REGEN_PERIOD) - 1))
    return 1.0 / ENERGY_REGEN_PERIOD[index]


def _phase_coconut_gain(phase: int) -> int:
    index = max(0, min(phase, len(COCONUT_EXPECTED_GAIN) - 1))
    return COCONUT_EXPECTED_GAIN[index]


def _phase_value(values: list[float], phase: int) -> float:
    return values[max(0, min(phase, len(values) - 1))]


def _weighted_choice(items: list[tuple[str, float]]) -> str:
    total = sum(weight for _, weight in items)
    roll = random.uniform(0.0, total)
    upto = 0.0
    for name, weight in items:
        upto += weight
        if roll <= upto:
            return name
    return items[-1][0]


def _choose_combo_style() -> str:
    return _weighted_choice(COMBO_STYLE_WEIGHTS)


def _style_gap(style: str) -> float:
    low, high = STYLE_GAP_RANGE.get(style, STYLE_GAP_RANGE["mixed"])
    return random.uniform(low, high)


def _burst_size(s: State, memory: WaveMemory) -> int:
    if s.phase < MID_PHASE:
        return BURST_SIZE
    choices = STYLE_BURST_CHOICES.get(memory.style, BURST_SIZE_CHOICES)
    cap = _phase_energy_cap(s.phase)
    bonus = (
        1
        if s.energy >= cap - 8 and random.random() < BURST_FULL_ENERGY_BONUS_CHANCE
        else 0
    )
    return min(WAVE_BURST_SIZE, random.choice(choices) + bonus)


def _weighted_unique_candidates(phase: int) -> list[int]:
    phase = min(max(phase, MID_PHASE), 5)
    return list(dict.fromkeys(WAVE_POOLS_BY_PHASE.get(phase, WAVE_POOLS_BY_PHASE[5])))


def _stock_cap(trap_id: int) -> int:
    return TRAP_STOCK.get(trap_id, 1)


def _choose_wave_subset(
    s: State,
    include_wave: bool = True,
    style: str = "mixed",
    avoid_first: set[int] | None = None,
) -> list[int]:
    budget = _phase_energy_cap(s.phase)
    if include_wave:
        budget -= TRAP_COST[WAVE_TRAP_ID]
    phase = min(max(s.phase, MID_PHASE), 5)
    candidates = [
        trap_id
        for trap_id in WAVE_POOLS_BY_PHASE.get(phase, WAVE_POOLS_BY_PHASE[5])
        if s.stock.get(trap_id, 0) > 0
    ]
    for trap_id in STYLE_DUPLICATE_CANDIDATES.get(style, []):
        if s.stock.get(trap_id, 0) > candidates.count(trap_id):
            candidates.append(trap_id)
    random.shuffle(candidates)
    chosen: list[int] = []
    spent = 0

    def add_if_room(trap_id: int) -> bool:
        nonlocal spent
        if trap_id not in candidates:
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

    def roll_add(trap_id: int, chance: float) -> bool:
        return (
            trap_id in candidates and random.random() < chance and add_if_room(trap_id)
        )

    def scan_ripple_count() -> int:
        return chosen.count(6) + chosen.count(7)

    def remove_last_non_scan_ripple() -> bool:
        nonlocal spent
        for index in range(len(chosen) - 1, -1, -1):
            trap_id = chosen[index]
            if trap_id not in (6, 7):
                spent -= TRAP_COST[trap_id]
                candidates.append(trap_id)
                chosen.pop(index)
                return True
        return False

    def scan_ripple_order() -> list[int]:
        if chosen.count(6) > chosen.count(7):
            return [7, 6]
        if chosen.count(7) > chosen.count(6):
            return [6, 7]
        if style == "scan":
            return [6, 7]
        return [7, 6]

    def add_scan_or_ripple() -> bool:
        for trap_id in scan_ripple_order():
            if add_if_room(trap_id):
                return True
        return False

    def force_scan_ripple_floor() -> None:
        minimum = _phase_value(MIN_SCAN_RIPPLE_BY_PHASE, phase)
        if minimum <= 0:
            return
        attempts = 0
        while scan_ripple_count() < minimum and attempts < 12:
            attempts += 1
            if add_scan_or_ripple():
                continue
            if not remove_last_non_scan_ripple():
                return

    for trap_id in STYLE_OPENERS.get(style, []):
        add_if_room(trap_id)

    force_scan_ripple_floor()

    double_scan_chance = (
        0.9 if style == "scan" else _phase_value(DOUBLE_SCAN_PRIORITY_CHANCE, s.phase)
    )
    if candidates.count(6) >= 2 and random.random() < double_scan_chance:
        add_if_room(6)
        add_if_room(6)

    roll_add(2, _phase_value(RING_CHANCE, s.phase))

    if (
        10 in candidates
        and 3 in candidates
        and random.random() < _phase_value(SHOT_BIRD_CHANCE, s.phase)
    ):
        add_if_room(10)
        add_if_room(3)

    if phase >= 2 and 6 in candidates and 7 in candidates:
        pair_chance = _phase_value(SCAN_RIPPLE_PAIR_CHANCE, phase)
        roll = random.random()
        if roll < pair_chance:
            add_if_room(6)
            add_if_room(7)
        elif roll < _phase_value(SCAN_ONLY_AFTER_PAIR_ROLL, phase):
            add_if_room(6)
        elif roll < _phase_value(RIPPLE_AFTER_PAIR_ROLL, phase):
            add_if_room(7)
    else:
        roll_add(6, _phase_value(SCAN_CHANCE, s.phase))
        roll_add(7, _phase_value(RIPPLE_CHANCE, s.phase))

    if chosen.count(6) == 1:
        roll_add(6, _phase_value(SECOND_SCAN_CHANCE, s.phase))
    for trap_id, chances in (
        (8, ARC_CHANCE),
        (10, SHOTGUN_CHANCE),
    ):
        roll_add(trap_id, _phase_value(chances, s.phase))
    if 10 in chosen and random.random() < BIRD_AFTER_SHOTGUN_CHANCE:
        add_if_room(3)
    roll_add(3, _phase_value(BIRD_CHANCE, s.phase))

    for trap_id, chance in STYLE_EXTRA_CHANCE.get(style, []):
        roll_add(trap_id, chance)

    if random.random() < _phase_value(DUPLICATE_CHANCE, s.phase):
        duplicate_pool = [6, 8, 3, 10, 3, 6, 7, 8]
        random.shuffle(duplicate_pool)
        for trap_id in duplicate_pool:
            if chosen.count(trap_id) == 1 and add_if_room(trap_id):
                break

    if s.phase >= 5 and random.random() < LATE_POOL_CHANCE:
        late_pool = [3, 10, 3, 10, 3, 6, 7, 8]
        random.shuffle(late_pool)
        for trap_id in late_pool:
            if add_if_room(trap_id):
                break
    if s.phase >= 4 and random.random() < LATE_RANDOM_DAMAGE_CHANCE:
        add_if_room(random.choice([3, 10, 8]))

    if avoid_first is not None and chosen[:1] and chosen[0] in avoid_first:
        for index, trap_id in enumerate(chosen[1:], 1):
            if trap_id not in avoid_first:
                chosen[0], chosen[index] = chosen[index], chosen[0]
                break

    target_size = min(len(candidates) + len(chosen), random.randint(3, 5))
    for trap_id in candidates[:]:
        if len(chosen) >= target_size:
            break
        add_if_room(trap_id)

    force_scan_ripple_floor()

    if avoid_first is not None and chosen[:1] and chosen[0] in avoid_first:
        for index, trap_id in enumerate(chosen[1:], 1):
            if trap_id not in avoid_first:
                chosen[0], chosen[index] = chosen[index], chosen[0]
                break
        if chosen[0] in avoid_first:
            return []

    return chosen


def _combo_cost(combo_ids: list[int], include_wave: bool = True) -> int:
    wave_cost = TRAP_COST[WAVE_TRAP_ID] if include_wave else 0
    return wave_cost + sum(TRAP_COST[trap_id] for trap_id in combo_ids)


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
    return all(
        combo_ids.count(trap_id) <= s.stock.get(trap_id, 0)
        for trap_id in set(combo_ids)
    )


def _offset_lane(
    anchor: Vector2, direction: Direction, distance: float, lateral: float
) -> Vector2:
    forward = _dir_vec(direction)
    side = _perp(forward)
    return _field(_add(_add(anchor, _mul(forward, distance)), _mul(side, lateral)), 4.0)


def _wave_combo_variant_target(
    anchor: Vector2, direction: Direction, distance: float, use_count: int
) -> Vector2:
    lateral = random.uniform(-28.0, 28.0)
    if use_count > 0:
        lateral += random.choice([-1.0, 1.0]) * random.uniform(28.0, 58.0)
    lane_distance = distance + use_count * random.uniform(28.0, 52.0)
    lane_distance += random.uniform(-30.0, 30.0)
    return _offset_lane(anchor, direction, lane_distance, lateral)


def _wave_combo_variant_wide_target(
    anchor: Vector2, direction: Direction, distance: float, use_count: int
) -> Vector2:
    lateral = random.uniform(-45.0, 45.0)
    if use_count > 0:
        lateral += random.choice([-1.0, 1.0]) * random.uniform(45.0, 85.0)
    lane_distance = distance + use_count * random.uniform(35.0, 62.0)
    lane_distance += random.uniform(-45.0, 45.0)
    return _offset_lane(anchor, direction, lane_distance, lateral)


def _wave_ripple_target(
    anchor: Vector2, direction: Direction, use_count: int
) -> Vector2:
    if random.random() < RIPPLE_CENTER_CHANCE:
        target = _add(anchor, _mul(_random_vec(), random.uniform(30.0, 145.0)))
        return _field(Vector2(target.x * 0.45, target.y * 0.45), 4.0)
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
    side = _perp(forward)
    roll = random.random()
    if roll < ARC_BASE_AXIS_CHANCE:
        return forward if use_count == 0 else side
    if roll < ARC_BASE_AXIS_CHANCE + ARC_DIAGONAL_CHANCE:
        side_sign = random.choice([-1.0, 1.0])
        return _unit(_add(forward, _mul(side, side_sign)))
    return _random_vec()


def _wave_combo_variant_scan_dir(
    direction: Direction, anchor: Vector2, use_count: int
) -> Direction:
    if use_count == 0 and random.random() < SCAN_FIRST_REVERSE_CHANCE:
        return _opposite_dir(direction)
    if use_count > 0 and random.random() < SCAN_LATER_PERP_CHANCE:
        return _perp_dir(direction, anchor)
    return random.choice(_all_dirs())


def _scan_distance_to(pos: Vector2, direction: Direction) -> float:
    if direction == Direction.RIGHT:
        return pos.x - FIELD_MIN
    if direction == Direction.LEFT:
        return FIELD_MAX - pos.x
    if direction == Direction.DOWN:
        return pos.y - FIELD_MIN
    return FIELD_MAX - pos.y


def _scan_speed_for_delay(pos: Vector2, direction: Direction, desired: float) -> float:
    distance = max(30.0, _scan_distance_to(pos, direction))
    return _clamp(distance / max(0.25, desired), 120.0, 250.0)


def _best_scan_dir_for_delay(pos: Vector2, desired: float) -> Direction:
    options = []
    for direction in _all_dirs():
        distance = max(30.0, _scan_distance_to(pos, direction))
        speed = _scan_speed_for_delay(pos, direction, desired)
        arrival = distance / speed
        options.append((abs(arrival - desired), direction))
    return min(options, key=lambda item: item[0])[1]


def _perp_scan_dir_for_delay(
    pos: Vector2, base_dir: Direction, desired: float
) -> Direction:
    choices = (
        [Direction.UP, Direction.DOWN]
        if base_dir in (Direction.LEFT, Direction.RIGHT)
        else [Direction.LEFT, Direction.RIGHT]
    )
    return min(
        choices,
        key=lambda candidate: abs(
            _scan_distance_to(pos, candidate)
            / _scan_speed_for_delay(pos, candidate, desired)
            - desired
        ),
    )


def _tempo_scan_setup(
    s: State, memory: WaveMemory, use_count: int
) -> tuple[Direction, float]:
    target = _predict(s, 0.35 + use_count * 0.16, 0.0)
    desired = TEMPO_SCAN_DELAYS[min(use_count, 1)] + random.uniform(-0.08, 0.08)
    if use_count == 0 or not memory.tempo_scan_mode:
        memory.tempo_scan_mode = _weighted_choice(SCAN_TEMPO_MODE_WEIGHTS)
        memory.tempo_scan_first_dir = _best_scan_dir_for_delay(target, desired)
        direction = memory.tempo_scan_first_dir
    elif memory.tempo_scan_mode == "same":
        direction = memory.tempo_scan_first_dir
    elif memory.tempo_scan_mode == "pincer":
        direction = _opposite_dir(memory.tempo_scan_first_dir)
    else:
        direction = _perp_scan_dir_for_delay(
            target, memory.tempo_scan_first_dir, desired
        )
    return direction, _scan_speed_for_delay(target, direction, desired)


def _scan_speed(use_count: int) -> float:
    if use_count == 0:
        return random.uniform(220.0, 250.0)
    return random.uniform(120.0, 230.0)


def _ripple_rate(use_count: int) -> float:
    if use_count == 0:
        return random.uniform(145.0, 200.0)
    return random.uniform(100.0, 175.0)


def _spread_ripple_target(
    target: Vector2, memory: WaveMemory, use_count: int
) -> Vector2:
    previous = memory.last_ripple_target
    if use_count <= 0 or previous is None:
        return target

    gap = _length(_sub(target, previous))
    wanted = random.uniform(80.0, 155.0)
    if gap >= wanted:
        return target

    away = _unit(_sub(target, previous), _random_vec())
    side = _perp(away)
    offset = _add(
        _mul(away, wanted - gap + random.uniform(18.0, 44.0)),
        _mul(side, random.choice([-1.0, 1.0]) * random.uniform(22.0, 70.0)),
    )
    return _ripple_field(_add(target, offset))


def _tempo_ripple_setup(s: State, use_count: int) -> tuple[Vector2, float]:
    predicted = _predict(s, 0.3 + use_count * 0.15, 4.0)
    desired = TEMPO_RIPPLE_DELAYS[min(use_count, 1)] + random.uniform(-0.06, 0.08)
    rate = (
        random.uniform(175.0, 200.0) if use_count == 0 else random.uniform(105.0, 145.0)
    )
    travel = max(18.0, (desired - 1.0) * rate)
    center = _add(predicted, _mul(_random_vec(), travel))
    return _ripple_field(center), rate


def _bird_speed(use_count: int) -> float:
    if use_count == 0:
        return random.uniform(255.0, 300.0)
    return random.uniform(200.0, 280.0)


def _shotgun_spread(use_count: int) -> tuple[float, float]:
    low, high = (0.28, 0.68) if use_count == 0 else (0.72, 1.25)
    return random.uniform(low, high), random.uniform(low, high)


def _wave_ring_radius(speed: float) -> float:
    if speed > 180.0:
        return random.uniform(110.0, 150.0)
    return random.uniform(100.0, 140.0)


def _ring_delay() -> float:
    return random.uniform(1.0, 2.0)


def _wave_memory_active(s: State, memory: WaveMemory) -> bool:
    return s.elapsed - memory.fired_at <= WAVE_MEMORY_SEC


def _combo_has_budget(s: State, memory: WaveMemory, trap_id: int) -> bool:
    cost = TRAP_COST[trap_id]
    return cost <= s.energy and memory.combo_spent + cost <= _phase_energy_cap(s.phase)


def _can_combo_trap(
    s: State,
    used_counts: dict[int, int],
    memory: WaveMemory,
    combo_ids: list[int],
    trap_id: int,
) -> bool:
    if trap_id == 8 and memory.aftershock_counts.get(8, 0) > 0:
        return False
    return (
        _combo_remaining(combo_ids, memory, trap_id)
        and _can_use_stock(s, used_counts, trap_id)
        and _combo_has_budget(s, memory, trap_id)
    )


def _wave_time_left(s: State, memory: WaveMemory) -> float:
    return max(0.0, WAVE_MEMORY_SEC - (s.elapsed - memory.fired_at))


def _wave_age(s: State, memory: WaveMemory) -> float:
    return max(0.0, s.elapsed - memory.fired_at)


def _wave_spend_limit(s: State) -> int:
    cap = _phase_energy_cap(s.phase)
    wave_regen = WAVE_MEMORY_SEC * _phase_regen_rate(s.phase)
    coconut_gain = _phase_coconut_gain(s.phase) * AFTERSHOCK_COCONUT_GAIN_FRACTION
    return int(cap + wave_regen * AFTERSHOCK_SPEND_FRACTION + coconut_gain)


def _aftershock_energy_reserve(s: State, memory: WaveMemory) -> int:
    cap = _phase_energy_cap(s.phase)
    usable_time = max(0.0, _wave_time_left(s, memory) - AFTERSHOCK_END_RESERVE_SEC)
    expected_regen = usable_time * _phase_regen_rate(s.phase)
    coconut_gain = _phase_coconut_gain(s.phase) * AFTERSHOCK_COCONUT_GAIN_FRACTION
    reserve = cap - expected_regen - coconut_gain
    return max(0, math.ceil(reserve * AFTERSHOCK_RESERVE_SOFTEN))


def _aftershock_gap(s: State, memory: WaveMemory) -> float:
    cap = _phase_energy_cap(s.phase)
    if s.energy >= cap - 5:
        low, high = AFTERSHOCK_FULL_ENERGY_DELAY_RANGE
    elif _wave_time_left(s, memory) <= 2.0:
        low, high = AFTERSHOCK_ENDING_DELAY_RANGE
    else:
        low, high = AFTERSHOCK_DELAY_RANGE
    return random.uniform(low, high)


def _can_aftershock_trap(
    s: State, used_counts: dict[int, int], memory: WaveMemory, trap_id: int
) -> bool:
    if trap_id == 8 and (
        memory.used_combo_counts.get(8, 0) + memory.aftershock_counts.get(8, 0) >= 1
    ):
        return False
    cost = TRAP_COST[trap_id]
    reserve = _aftershock_energy_reserve(s, memory)
    greedy_ok = s.energy >= reserve + AFTERSHOCK_GREED_MARGIN
    trap_limit = AFTERSHOCK_MAX_PER_TRAP.get(trap_id, _stock_cap(trap_id))
    wave_age = _wave_age(s, memory)
    return (
        wave_age <= AFTERSHOCK_STOP_AFTER_SEC
        and (trap_id != 8 or wave_age <= AFTERSHOCK_ARC_STOP_AFTER_SEC)
        and memory.aftershock_counts.get(trap_id, 0) < trap_limit
        and _can_use_stock(s, used_counts, trap_id)
        and cost <= s.energy
        and (s.energy - cost >= reserve or greedy_ok)
        and memory.combo_spent + cost <= _wave_spend_limit(s)
    )


def _ripple_field(v: Vector2) -> Vector2:
    return Vector2(_clamp(v.x, -400.0, 400.0), _clamp(v.y, -280.0, 280.0))


def _combo_finished(memory: WaveMemory) -> bool:
    return bool(memory.combo_ids) and all(
        not _combo_remaining(memory.combo_ids, memory, trap_id)
        for trap_id in set(memory.combo_ids)
    )


def _clear_combo_memory(memory: WaveMemory) -> None:
    memory.fired_at = -999.0
    memory.combo_ids = []
    memory.pending_combo_ids = []
    memory.used_combo_counts = {}
    memory.combo_spent = 0
    memory.extra_ring = False
    memory.style = "mixed"
    memory.pending_style = "mixed"
    memory.next_ready_at = -999.0
    memory.aftershock_used = 0
    memory.aftershock_counts = {}
    memory.aftershock_ready_at = -999.0
    memory.delayed_wave_pending = False
    memory.delayed_wave_ready_at = -999.0
    memory.delayed_wave_cue = None
    memory.tempo_scan_mode = ""
    memory.tempo_scan_first_dir = Direction.RIGHT
    memory.last_ripple_target = None


def _start_combo_memory(
    memory: WaveMemory,
    s: State,
    direction: Direction,
    anchor: Vector2,
    combo_ids: list[int],
    spent: int,
    style: str,
) -> None:
    memory.fired_at = s.elapsed
    memory.direction = direction
    memory.anchor = anchor
    memory.combo_ids = combo_ids
    memory.pending_combo_ids = []
    memory.used_combo_counts = {}
    memory.combo_spent = spent
    memory.extra_ring = False
    memory.style = style
    memory.pending_style = "mixed"
    memory.aftershock_used = 0
    memory.aftershock_counts = {}
    memory.aftershock_ready_at = -999.0
    memory.delayed_wave_pending = False
    memory.delayed_wave_ready_at = -999.0
    memory.delayed_wave_cue = None
    memory.tempo_scan_mode = ""
    memory.tempo_scan_first_dir = Direction.RIGHT
    memory.last_ripple_target = None
    memory.next_ready_at = (
        s.elapsed
        if random.random() < STYLE_IMMEDIATE_CHANCE.get(style, 0.6)
        else s.elapsed + _style_gap(style)
    )
    memory.side_shotgun = _use_side_shotgun(combo_ids, s.phase)
    memory.bird_basket_sync = (
        3 not in combo_ids
        or 10 not in combo_ids
        or random.random() < BIRD_BASKET_SYNC_CHANCE
    )


def _shotgun_dirs(
    origin: Vector2, target: Vector2, spread: tuple[float, float] = (0.34, 0.34)
) -> tuple[Vector2, Vector2, Vector2]:
    main = _unit(_sub(target, origin))
    side = Vector2(-main.y, main.x)
    left_spread, right_spread = spread
    return (
        _unit(_add(main, _mul(side, left_spread))),
        main,
        _unit(_add(main, _mul(side, -right_spread))),
    )


def _shotgun_origin_along(target: Vector2, aim: Vector2) -> Vector2:
    options = []
    if abs(aim.x) > 0.01:
        for edge_x in (-SHOTGUN_EDGE, SHOTGUN_EDGE):
            t = (target.x - edge_x) / aim.x
            y = target.y - aim.y * t
            if t > 0.0 and abs(y) <= SHOTGUN_EDGE:
                options.append((t, Vector2(edge_x, y)))
    if abs(aim.y) > 0.01:
        for edge_y in (-SHOTGUN_EDGE, SHOTGUN_EDGE):
            t = (target.y - edge_y) / aim.y
            x = target.x - aim.x * t
            if t > 0.0 and abs(x) <= SHOTGUN_EDGE:
                options.append((t, Vector2(x, edge_y)))
    if not options:
        return _shotgun_origin(target)
    return min(options, key=lambda item: item[0])[1]


def _wave_shotgun_setup(
    anchor: Vector2, direction: Direction, use_count: int, side_mode: bool = False
) -> tuple[Vector2, Vector2]:
    if side_mode:
        target = _offset_lane(
            anchor,
            direction,
            random.uniform(-35.0, 55.0),
            random.uniform(-45.0, 45.0),
        )
        if random.random() < SHOTGUN_FREE_AIM_CHANCE:
            aim = _random_vec()
            return _shotgun_origin_along(target, aim), target
        shotgun_dir = _perp_dir(direction, target) if use_count % 2 == 0 else direction
        if random.random() < SHOTGUN_RANDOM_AXIS_CHANCE:
            shotgun_dir = random.choice(_all_dirs())
        origin = _shotgun_origin_for_dir(target, shotgun_dir)
        if _length(_sub(target, origin)) < 220.0:
            origin = _shotgun_origin_for_dir(target, _opposite_dir(shotgun_dir))
        return origin, target
    if use_count == 0:
        origin_hint = _wave_lane(anchor, direction, random.uniform(190.0, 245.0))
        target = _offset_lane(
            anchor,
            direction,
            random.uniform(10.0, 70.0),
            random.uniform(-35.0, 35.0),
        )
        return _shotgun_origin(origin_hint), target
    target = _offset_lane(
        anchor,
        direction,
        random.uniform(45.0, 125.0),
        random.choice([-1.0, 1.0]) * random.uniform(85.0, 145.0),
    )
    shotgun_dir = random.choice(
        [_perp_dir(direction, target), _opposite_dir(direction)]
    )
    if random.random() < SHOTGUN_LATER_RANDOM_AXIS_CHANCE:
        shotgun_dir = random.choice(_all_dirs())
    return _shotgun_origin_for_dir(target, shotgun_dir), target


def _try(client, trap_id: int, name: str, action) -> tuple[bool, str]:
    result = action()
    if _failed(result):
        return False, ""
    return True, f"{trap_id}:{name}"


def _add_plan(plan: list[PlanItem], trap_id: int, name: str, action, cue=None) -> None:
    if cue is not None:
        action.wave_cue = cue
    plan.append((trap_id, name, action))


def _early_plan(client, s: State, used_counts: dict[int, int]) -> list[PlanItem]:
    gate = _coconut_gate(s, random.uniform(0.85, 1.55))
    path = _unit(_sub(s.ball, s.pos), _unit(s.vel))
    if random.random() < EARLY_PATH_JITTER_CHANCE:
        path = _unit(_add(path, _mul(_random_vec(), random.uniform(0.25, 0.9))))
    speed = _length(s.vel)
    plan = []

    if 6 in s.available and used_counts.get(6, 0) == 0:
        sweep_dir = _push_dir(_sub(gate, s.pos))
        scan_speed = _scan_speed(0)
        _add_plan(
            plan,
            6,
            "early-coconut-scan",
            lambda direction=sweep_dir, scan_speed=scan_speed: client.spawn_trap6(
                direction, scan_speed
            ),
        )

    if 8 in s.available and used_counts.get(8, 0) == 0:
        start, end = _arc_through(gate, path)
        _add_plan(
            plan,
            8,
            "early-coconut-arc",
            lambda start=start, end=end: client.spawn_trap8(start, end),
        )

    if 3 in s.available and used_counts.get(3, 0) == 0:
        origin = _nearest_edge_origin(gate)
        if random.random() < EARLY_BIRD_OPPOSITE_CHANCE:
            origin = _opposite_edge_origin(origin)
        direction = _unit(_sub(gate, origin))
        bird_speed = _bird_speed(0)
        _add_plan(
            plan,
            3,
            "early-coconut-bird",
            lambda origin=origin, direction=direction, bird_speed=bird_speed: (
                client.spawn_trap3(origin, direction, bird_speed)
            ),
        )

    if 2 in s.available and used_counts.get(2, 0) == 0:
        radius = _wave_ring_radius(speed)
        delay = _ring_delay()
        _add_plan(
            plan,
            2,
            "early-ring",
            lambda delay=delay, radius=radius: client.spawn_trap2(delay, radius),
        )

    if 7 in s.available and used_counts.get(7, 0) == 0:
        gate = _add(gate, _mul(_random_vec(), random.uniform(0.0, 38.0)))
        target = Vector2(
            _clamp(gate.x, -400.0, 400.0),
            _clamp(gate.y, -280.0, 280.0),
        )
        expand_rate = _ripple_rate(0)
        _add_plan(
            plan,
            7,
            "early-coconut-ripple",
            lambda target=target, expand_rate=expand_rate: client.spawn_trap7(
                target, expand_rate
            ),
        )

    return plan


def _aftershock_possible(s: State, memory: WaveMemory) -> bool:
    return (
        _wave_age(s, memory) <= AFTERSHOCK_STOP_AFTER_SEC
        and memory.aftershock_used < AFTERSHOCK_MAX_TRAPS
        and s.energy >= AFTERSHOCK_MIN_ENERGY
        and memory.combo_spent < _wave_spend_limit(s)
    )


def _should_skip_wave(s: State, memory: WaveMemory) -> bool:
    return (
        s.elapsed - memory.last_no_wave_at >= NO_WAVE_MIN_GAP_SEC
        and random.random() < NO_WAVE_COMBO_CHANCE
    )


def _should_delay_wave(s: State, memory: WaveMemory) -> bool:
    return (
        s.elapsed - memory.last_delayed_wave_at >= DELAYED_WAVE_MIN_GAP_SEC
        and random.random() < DELAYED_WAVE_COMBO_CHANCE
    )


def _should_recycle_wave(s: State, memory: WaveMemory, has_fresh_wave: bool) -> bool:
    return (
        has_fresh_wave
        and not memory.delayed_wave_pending
        and _wave_age(s, memory) >= AFTERSHOCK_STOP_AFTER_SEC
        and s.energy >= _phase_energy_cap(s.phase) - WAVE_RECYCLE_ENERGY_MARGIN
    )


def _delayed_wave_delay(s: State, trap_id: int, name: str, action) -> float:
    cue = getattr(action, "wave_cue", None)
    if trap_id == 2 and cue and cue[0] == "ring":
        return max(0.28, cue[1] + random.uniform(-0.18, -0.06))
    base = {
        2: random.uniform(0.95, 1.3),
        3: random.uniform(0.65, 1.15),
        7: random.uniform(0.8, 1.25),
        8: random.uniform(1.25, 1.9),
        10: random.uniform(1.1, 1.55),
    }.get(trap_id, random.uniform(0.65, 1.05))
    if trap_id == 6 and "scan" in name:
        base = random.uniform(0.55, 1.25)
    jitter = random.uniform(*DELAYED_WAVE_JITTER_RANGE)
    return max(0.28, base + jitter)


def _align_delayed_wave(memory: WaveMemory, s: State, action) -> None:
    cue = getattr(action, "wave_cue", None)
    memory.delayed_wave_cue = (
        ("scan", cue[1], cue[2], s.elapsed) if cue and cue[0] == "scan" else cue
    )


def _delayed_wave_pose(memory: WaveMemory, s: State) -> tuple[Vector2, Direction]:
    cue = memory.delayed_wave_cue
    if cue and cue[0] == "scan":
        scan_dir = cue[1]
        scan_speed = cue[2]
        scan_started_at = cue[3]
        axis = _dir_vec(scan_dir)
        age = max(0.0, s.elapsed - scan_started_at - 0.25)
        line_pos = _mul(axis, -300.0 + scan_speed * age)
        delta = (
            Vector2(line_pos.x - s.pos.x, 0.0)
            if abs(axis.x) > 0.1
            else Vector2(0.0, line_pos.y - s.pos.y)
        )
        direction = _push_dir(delta)
        if abs(delta.x) < 18.0 and abs(delta.y) < 18.0:
            direction = _opposite_dir(scan_dir)
        return _box(_predict(s, 0.08, 0.0), 100.0), direction
    if cue and cue[0] == "target":
        target = cue[1]
        anchor = _box(
            Vector2(
                s.pos.x * 0.58 + target.x * 0.42,
                s.pos.y * 0.58 + target.y * 0.42,
            ),
            100.0,
        )
        return anchor, _dir_toward(s.pos, target)
    if cue and cue[0] == "ring":
        return _box(_predict(s, 0.06, 0.0), 100.0), _wave_dir(s)
    return _wave_anchor(s), _wave_dir(s)


def _aftershock_is_ready(s: State, memory: WaveMemory) -> bool:
    if not _aftershock_possible(s, memory):
        return False
    reserve = _aftershock_energy_reserve(s, memory)
    if s.energy >= reserve + AFTERSHOCK_GREED_MARGIN:
        return True
    if memory.aftershock_ready_at < memory.fired_at:
        memory.aftershock_ready_at = s.elapsed + _aftershock_gap(s, memory)
        return False
    return s.elapsed >= memory.aftershock_ready_at


def _aftershock_target(
    s: State,
    anchor: Vector2,
    direction: Direction,
    use_count: int,
    distance: float,
    lateral_width: float,
) -> Vector2:
    mode = _weighted_choice(AFTERSHOCK_TARGET_MODE_WEIGHTS)
    lane = _offset_lane(
        anchor,
        direction,
        distance + random.uniform(-45.0, 45.0),
        random.uniform(-lateral_width, lateral_width),
    )
    predicted = _predict(s, random.uniform(0.2, 0.72), 4.0)
    gate = _coconut_gate(s, random.uniform(0.28, 0.9))

    if mode == "player":
        target = predicted
        jitter = random.uniform(6.0, 30.0)
    elif mode == "coconut":
        target = gate
        jitter = random.uniform(4.0, 26.0)
    elif mode == "intercept":
        player_to_coconut = _sub(gate, predicted)
        side = _perp(_unit(player_to_coconut))
        mix = random.uniform(0.34, 0.66)
        target = Vector2(
            predicted.x * (1.0 - mix) + gate.x * mix,
            predicted.y * (1.0 - mix) + gate.y * mix,
        )
        target = _add(target, _mul(side, random.uniform(-42.0, 42.0)))
        jitter = random.uniform(4.0, 24.0)
    else:
        target = lane
        jitter = random.uniform(8.0, 34.0)

    if mode != "wave_noise":
        lane_weight = random.uniform(0.0, max(0.02, 0.08 - use_count * 0.01))
        target = Vector2(
            target.x * (1.0 - lane_weight) + lane.x * lane_weight,
            target.y * (1.0 - lane_weight) + lane.y * lane_weight,
        )
    return _field(_add(target, _mul(_random_vec(), jitter)), 4.0)


def _aftershock_scan_dir(s: State, anchor: Vector2, direction: Direction) -> Direction:
    target = (
        _coconut_gate(s, random.uniform(0.25, 0.75))
        if random.random() < 0.42
        else _predict(s, random.uniform(0.18, 0.58), 0.0)
    )
    if random.random() < 0.22:
        return random.choice(_all_dirs())
    if random.random() < 0.35:
        return _perp_dir(direction, target)
    return _opposite_dir(_push_dir(target))


def _aftershock_arc_target(
    s: State, anchor: Vector2, direction: Direction, use_count: int
) -> Vector2:
    if random.random() < AFTERSHOCK_ARC_ON_COCONUT_CHANCE:
        to_coconut = _sub(s.ball, s.pos)
        block = _add(
            s.ball,
            _mul(_unit(to_coconut), -random.uniform(0.0, 34.0)),
        )
        block = _add(block, _mul(_random_vec(), random.uniform(0.0, 18.0)))
        return _field(block, 8.0)
    return _aftershock_target(s, anchor, direction, use_count, 35.0, 80.0)


def _aftershock_shotgun_setup(
    s: State, anchor: Vector2, direction: Direction, use_count: int
) -> tuple[Vector2, Vector2]:
    target = _aftershock_target(s, anchor, direction, use_count, 80.0, 95.0)
    shotgun_dir = random.choice(
        [
            _perp_dir(direction, target),
            _opposite_dir(direction),
            random.choice(_all_dirs()),
        ]
    )
    origin = _shotgun_origin_for_dir(target, shotgun_dir)
    if _length(_sub(target, origin)) < 220.0:
        origin = _shotgun_origin_for_dir(target, _opposite_dir(shotgun_dir))
    return origin, target


def _aftershock_plan(
    client,
    s: State,
    used_counts: dict[int, int],
    memory: WaveMemory,
    anchor: Vector2,
    direction: Direction,
) -> list[PlanItem]:
    style_pool = AFTERSHOCK_POOL_BY_STYLE.get(
        memory.style, AFTERSHOCK_POOL_BY_STYLE["mixed"]
    )
    fallback_pool = [6, 8, 3, 10, 7, 2]
    offset = memory.aftershock_used % len(style_pool)
    pool = style_pool[offset:] + style_pool[:offset]
    pool += random.sample(fallback_pool, len(fallback_pool))
    if (
        memory.used_combo_counts.get(10, 0) + memory.aftershock_counts.get(10, 0) == 0
        and random.random() < AFTERSHOCK_SHOTGUN_FRONT_CHANCE
    ):
        pool.insert(0, 10)
    front = pool[:3]
    random.shuffle(front)
    pool = front + pool[3:]
    plan: list[PlanItem] = []
    speed = _length(s.vel)

    for trap_id in pool:
        use_count = memory.aftershock_used
        if not _can_aftershock_trap(s, used_counts, memory, trap_id):
            continue

        if trap_id == 6:
            sweep_dir = _aftershock_scan_dir(s, anchor, direction)
            scan_speed = _scan_speed(use_count)
            _add_plan(
                plan,
                6,
                "wave-aftershock-scan",
                lambda direction=sweep_dir, scan_speed=scan_speed: client.spawn_trap6(
                    direction, scan_speed
                ),
            )
        elif trap_id == 8:
            arc_target = _aftershock_arc_target(s, anchor, direction, use_count)
            arc_vec = _random_vec()
            start, end = _arc_through(arc_target, arc_vec)
            _add_plan(
                plan,
                8,
                "wave-aftershock-arc",
                lambda start=start, end=end: client.spawn_trap8(start, end),
            )
        elif trap_id == 3:
            target = _aftershock_target(s, anchor, direction, use_count, 95.0, 115.0)
            origin = _nearest_edge_origin(target)
            if use_count % 2:
                origin = _opposite_edge_origin(origin)
            bird_dir = _unit(_sub(target, origin))
            bird_speed = _bird_speed(use_count)
            _add_plan(
                plan,
                3,
                "wave-aftershock-bird",
                lambda origin=origin, direction=bird_dir, bird_speed=bird_speed: (
                    client.spawn_trap3(origin, direction, bird_speed)
                ),
            )
        elif trap_id == 10:
            origin, target = _aftershock_shotgun_setup(s, anchor, direction, use_count)
            dirs = _shotgun_dirs(origin, target, _shotgun_spread(use_count))
            _add_plan(
                plan,
                10,
                "wave-aftershock-shotgun",
                lambda origin=origin, dirs=dirs: client.spawn_trap10(origin, *dirs),
            )
        elif trap_id == 7:
            target = _ripple_field(
                _aftershock_target(s, anchor, direction, use_count, 70.0, 150.0)
            )
            target = _spread_ripple_target(
                target, memory, memory.aftershock_counts.get(7, 0)
            )
            expand_rate = _ripple_rate(use_count)
            _add_plan(
                plan,
                7,
                "wave-aftershock-ripple",
                lambda target=target, expand_rate=expand_rate: client.spawn_trap7(
                    target, expand_rate
                ),
                ("target", target),
            )
        elif trap_id == 2:
            delay = _ring_delay()
            radius = _wave_ring_radius(speed)
            _add_plan(
                plan,
                2,
                "wave-aftershock-ring",
                lambda delay=delay, radius=radius: client.spawn_trap2(delay, radius),
            )

        if plan:
            return plan
    return plan


def _wave_combo_plan(
    client, s: State, used_counts: dict[int, int], memory: WaveMemory
) -> list[PlanItem]:
    has_fresh_wave = _can_use_stock(s, used_counts, 4)
    direction = memory.direction
    anchor = memory.anchor
    speed = _length(s.vel)
    plan = []

    if _wave_memory_active(s, memory) and _should_recycle_wave(
        s, memory, has_fresh_wave
    ):
        _clear_combo_memory(memory)
        direction = memory.direction
        anchor = memory.anchor

    if not _wave_memory_active(s, memory):
        direction = _wave_combo_dir(s)
        anchor = _wave_anchor(s)
        style = _choose_combo_style()
        skip_wave = _should_skip_wave(s, memory)
        delay_wave = not skip_wave and has_fresh_wave and _should_delay_wave(s, memory)
        if not skip_wave and not has_fresh_wave:
            return plan
        include_wave = not skip_wave
        combo_ids = _choose_wave_subset(
            s,
            include_wave=include_wave,
            style=style,
            avoid_first={3, 10} if delay_wave else None,
        )
        if not combo_ids:
            return plan
        if not _has_stock_for_combo(s, combo_ids):
            return plan
        if s.energy < _combo_cost(combo_ids, include_wave=include_wave):
            return plan
        if skip_wave:
            _start_combo_memory(memory, s, direction, anchor, combo_ids, 0, style)
            memory.last_no_wave_at = s.elapsed
            direction = memory.direction
            anchor = memory.anchor
        elif delay_wave:
            _start_combo_memory(memory, s, direction, anchor, combo_ids, 0, style)
            memory.delayed_wave_pending = True
            memory.last_delayed_wave_at = s.elapsed
            memory.next_ready_at = s.elapsed
            direction = memory.direction
            anchor = memory.anchor
        else:
            memory.pending_direction = direction
            memory.pending_anchor = anchor
            memory.pending_combo_ids = combo_ids
            memory.pending_style = style
            memory.side_shotgun = _use_side_shotgun(combo_ids, s.phase)
            _add_plan(
                plan,
                4,
                "wave-combo-start",
                lambda target=anchor, direction=direction: client.spawn_trap4(
                    target, direction
                ),
            )
            return plan

    cap = _phase_energy_cap(s.phase)
    if s.elapsed < memory.next_ready_at and (
        s.energy < cap - 5 or random.random() > FULL_ENERGY_IGNORE_TIMING_CHANCE
    ):
        return plan

    combo_ids = (
        memory.combo_ids if memory.combo_ids else _weighted_unique_candidates(s.phase)
    )
    partners = []

    if (
        memory.delayed_wave_pending
        and memory.used_combo_counts
        and s.elapsed < memory.delayed_wave_ready_at
    ):
        return plan

    if (
        memory.delayed_wave_pending
        and memory.used_combo_counts
        and s.elapsed >= memory.delayed_wave_ready_at
        and _can_use_stock(s, used_counts, 4)
        and TRAP_COST[4] <= s.energy
        and memory.combo_spent + TRAP_COST[4] <= _phase_energy_cap(s.phase)
    ):
        wave_anchor, wave_direction = _delayed_wave_pose(memory, s)
        memory.anchor = wave_anchor
        memory.direction = wave_direction
        memory.pending_anchor = wave_anchor
        memory.pending_direction = wave_direction
        _add_plan(
            partners,
            4,
            "wave-delayed-start",
            lambda target=wave_anchor, direction=wave_direction: client.spawn_trap4(
                target, direction
            ),
        )

    if (
        not memory.extra_ring
        and not _combo_remaining(combo_ids, memory, 2)
        and not (memory.delayed_wave_pending and not memory.used_combo_counts)
        and _can_use_stock(s, used_counts, 2)
        and _combo_has_budget(s, memory, 2)
    ):
        radius = _wave_ring_radius(speed)
        delay = _ring_delay()
        _add_plan(
            partners,
            2,
            "wave-bonus-ring",
            lambda delay=delay, radius=radius: client.spawn_trap2(delay, radius),
        )

    if _can_combo_trap(s, used_counts, memory, combo_ids, 8):
        arc_count = _combo_use_count(memory, 8)
        arc_target = _wave_arc_target(anchor, direction, arc_count)
        arc_vec = _wave_arc_vec(direction, arc_count)
        start, end = _arc_through(arc_target, arc_vec)
        _add_plan(
            partners,
            8,
            "wave-into-arc",
            lambda start=start, end=end: client.spawn_trap8(start, end),
            ("target", arc_target),
        )

    if _can_combo_trap(s, used_counts, memory, combo_ids, 7):
        ripple_count = _combo_use_count(memory, 7)
        if combo_ids.count(7) >= 2:
            target, expand_rate = _tempo_ripple_setup(s, ripple_count)
        else:
            ripple_target = _wave_ripple_target(anchor, direction, ripple_count)
            target = _ripple_field(ripple_target)
            expand_rate = _ripple_rate(ripple_count)
        target = _spread_ripple_target(target, memory, ripple_count)
        _add_plan(
            partners,
            7,
            "wave-into-ripple",
            lambda target=target, expand_rate=expand_rate: client.spawn_trap7(
                target, expand_rate
            ),
            ("target", target),
        )

    if _can_combo_trap(s, used_counts, memory, combo_ids, 2):
        radius = 100.0 if memory.delayed_wave_pending else _wave_ring_radius(speed)
        delay = _ring_delay()
        _add_plan(
            partners,
            2,
            "wave-pressure-ring",
            lambda delay=delay, radius=radius: client.spawn_trap2(delay, radius),
            ("ring", delay),
        )

    if _can_combo_trap(s, used_counts, memory, combo_ids, 6):
        scan_count = _combo_use_count(memory, 6)
        if combo_ids.count(6) >= 2:
            sweep_dir, scan_speed = _tempo_scan_setup(s, memory, scan_count)
        else:
            sweep_dir = _wave_combo_variant_scan_dir(direction, anchor, scan_count)
            scan_speed = _scan_speed(scan_count)
        _add_plan(
            partners,
            6,
            "wave-tail-sweep",
            lambda direction=sweep_dir, scan_speed=scan_speed: client.spawn_trap6(
                direction, scan_speed
            ),
            ("scan", sweep_dir, scan_speed),
        )

    if _can_combo_trap(s, used_counts, memory, combo_ids, 3):
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
        _add_plan(
            partners,
            3,
            "wave-into-bird",
            lambda origin=origin, direction=bird_dir, bird_speed=bird_speed: (
                client.spawn_trap3(origin, direction, bird_speed)
            ),
            ("target", bird_target),
        )

    if _can_combo_trap(s, used_counts, memory, combo_ids, 10):
        use_count = _combo_use_count(memory, 10)
        origin, shotgun_target = _wave_shotgun_setup(
            anchor, direction, use_count, memory.side_shotgun
        )
        dirs = _shotgun_dirs(origin, shotgun_target, _shotgun_spread(use_count))
        _add_plan(
            partners,
            10,
            "wave-tail-shotgun",
            lambda origin=origin, dirs=dirs: client.spawn_trap10(origin, *dirs),
            ("target", shotgun_target),
        )

    id_order: dict[int, int] = {}
    for index, trap_id in enumerate(combo_ids):
        id_order.setdefault(trap_id, index)

    def partner_priority(item: tuple[int, str, object]) -> float:
        trap_id = item[0]
        name = item[1]
        if name == "wave-delayed-start":
            return -0.5
        if (
            memory.delayed_wave_pending
            and not memory.used_combo_counts
            and trap_id in (3, 10)
            and any(other_id not in (3, 10) for other_id in combo_ids)
        ):
            return 998.0
        if trap_id == 10 and 3 in combo_ids:
            return float(id_order.get(10, 997))
        if trap_id == 3 and 10 in combo_ids:
            return float(id_order.get(10, 997)) + 0.1
        if trap_id == 2 and _combo_remaining(combo_ids, memory, 2):
            return 0.05 if s.phase <= 3 else min(float(id_order.get(2, 997)), 2.2)
        if trap_id == 2 and not _combo_remaining(combo_ids, memory, 2):
            return 0.25 if s.phase <= 3 else 3.2
        return float(id_order.get(trap_id, 997))

    if not partners and _combo_finished(memory):
        if not _aftershock_is_ready(s, memory):
            return plan
        partners.extend(
            _aftershock_plan(client, s, used_counts, memory, anchor, direction)
        )

    partners.sort(key=partner_priority)
    return plan + partners


def _attack_plan(
    client, s: State, used_counts: dict[int, int], memory: WaveMemory
) -> list[PlanItem]:
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
    burst_size = _burst_size(s, memory)

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
                cue = getattr(action, "wave_cue", None)
                if trap_id == 7 and cue and cue[0] == "target":
                    memory.last_ripple_target = cue[1]
                if trap_id == 4 and name == "wave-delayed-start":
                    memory.combo_spent += TRAP_COST[trap_id]
                    memory.delayed_wave_pending = False
                    memory.delayed_wave_ready_at = -999.0
                    memory.fired_at = s.elapsed
                    memory.next_ready_at = s.elapsed + _style_gap(memory.style)
                    memory.aftershock_ready_at = -999.0
                elif trap_id == 4:
                    combo_ids = memory.pending_combo_ids or _choose_wave_subset(s)
                    _start_combo_memory(
                        memory,
                        s,
                        memory.pending_direction,
                        memory.pending_anchor,
                        combo_ids,
                        TRAP_COST[trap_id],
                        memory.pending_style,
                    )
                    fired[-1] = f"{label}[{','.join(map(str, memory.combo_ids))}]"
                elif name.startswith("wave-aftershock"):
                    memory.combo_spent += TRAP_COST[trap_id]
                    memory.aftershock_used += 1
                    memory.aftershock_counts[trap_id] = (
                        memory.aftershock_counts.get(trap_id, 0) + 1
                    )
                    memory.aftershock_ready_at = s.elapsed + _aftershock_gap(s, memory)
                    memory.next_ready_at = s.elapsed + _style_gap(memory.style)
                elif trap_id == 2 and trap_id not in memory.combo_ids:
                    memory.combo_spent += TRAP_COST[trap_id]
                    memory.extra_ring = True
                    memory.next_ready_at = s.elapsed + _style_gap(memory.style)
                elif s.phase >= MID_PHASE:
                    memory.combo_spent += TRAP_COST[trap_id]
                    if memory.delayed_wave_pending and not memory.used_combo_counts:
                        _align_delayed_wave(memory, s, action)
                    memory.used_combo_counts[trap_id] = (
                        memory.used_combo_counts.get(trap_id, 0) + 1
                    )
                    if (
                        memory.delayed_wave_pending
                        and memory.delayed_wave_ready_at < memory.fired_at
                    ):
                        memory.delayed_wave_ready_at = s.elapsed + _delayed_wave_delay(
                            s, trap_id, name, action
                        )
                    has_tempo_pair = trap_id in (6, 7) and _combo_remaining(
                        memory.combo_ids, memory, trap_id
                    )
                    memory.next_ready_at = (
                        s.elapsed
                        if memory.delayed_wave_pending or has_tempo_pair
                        else s.elapsed + _style_gap(memory.style)
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
