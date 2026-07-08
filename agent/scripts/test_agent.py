"""Ice-anchored barrage test agent for the 2026 dodge-the-trap game.

Same contract as the default ``agent.py`` (expose ``run(client)``).

--------------------------------------------------------------------------------
Idea: use the ice floor as an anchor, then mix in many different traps
--------------------------------------------------------------------------------
Three facts from the trap scripts drive this:

  * A jump zeroes ``player.collision_layer`` for ~0.55s, so ANY single collision
    trap is beaten by one jump. Pressure must come from overlapping many hazards
    AND from punishing the jump itself.
  * Each trap TYPE has its own cooldown (0.2s..3s -- see COOLDOWN below), but
    different types are independent. So we can't fire two shotguns quickly, but
    we CAN fire shotgun + mortar + arc + ripple + scanline + ring + bullet back
    to back.
  * ICE FLOOR / CONVEYOR do no damage; ice drops the player's accel 100 -> 5
    (very slippery) and the conveyor shoves them. On their own they're wasted
    energy -- they only pay off if strikes land while the player can't reposition.

So the loop is: BANK energy, then when we can afford a real barrage, drop ICE
under the player and, for the ice's lifetime (~5s), rain a rotating MIX of
different trap types at them while a CONVEYOR shoves them back toward the kill
zone. The ice means every time they land from a jump-dodge they're stuck
slippery as the next hazard arrives.

Anti-jump layer: MINES are sprinkled around (not under) the player. A jump-dodge
that lands on one detonates it; walking over one grounded just disarms it. So the
one universal escape -- jumping -- now carries a landing risk.

Energy discipline: if we can't afford a barrage we do NOTHING and bank -- except
once the bank is full and the ice is still cooling down, we use the wait to
pre-arm mines so they're live the instant the barrage opens.

Tune the knobs below (esp. BARRAGE_MIN_ENERGY for how often barrages fire, and
MIX for which traps to include).

--------------------------------------------------------------------------------
Run it
--------------------------------------------------------------------------------
    godot --path . -- --console
    # then, from the agent/ dir:
    uv run python runner.py --url ws://127.0.0.1:<PORT> --token <TOKEN> \
        --agent scripts/test_agent.py
"""

from __future__ import annotations

import math
import random
import time

# ruff: disable[F403]
from api import Direction, Vector2

# --- knobs -------------------------------------------------------------------

TICK_SEC = 0.2
STATUS_EVERY_SEC = 1.0
VEL_SMOOTHING = 0.4  # EMA weight kept from the previous velocity estimate
PLAYER_MAX_SPEED = 300.0  # Data/game.json move_speed; clips noisy estimates

ARENA = 225.0  # play area is a ~+/-225 box (y is DOWN)
EDGE_ARC = 275.0  # Clamper edge-spawn distances
EDGE_MORTAR = 275.0
EDGE_SHOTGUN = 258.0
EDGE_BULLET = 275.0

# Aim / per-trap tuning (all inside Data/trap.json clamp ranges).
SHOTGUN_LEAD = 0.35  # iced players barely move, so a short lead suffices
SHOTGUN_TIGHT_DEG = 7.0  # slippery target: concentrate the pellets
ICE_LIFETIME = 5.0  # Data/trap.json trap5 lifetime
MORTAR_AIR_TIME = 1.5
RIPPLE_EXPAND = 130.0
RIPPLE_LIMIT = (400.0, 280.0)
BULLET_SPEED = 150.0
SCANLINE_SPEED = (140.0, 250.0)
BALL_INTERCEPT_RANGE = 130.0

# Newly-wired traps (previously unused):
MINE_OFFSET = (45.0, 110.0)  # place mines AROUND (not under) the player's feet
MINE_GAP = 5.0  # min seconds between mines: keep the field sparse
# (>barrage window, so ~1 mine seeds per barrage;
# mines persist, so a few go a long way)
RING_DELAY = 1.0  # electric-ring fill time before it locks + zaps
RING_RADIUS = (85.0, 120.0)  # trap.json ring radius range is 70..150

# Barrage control.
# Different trap types fired at the pinned player. Order = preference when
# several are ready in one tick (mortar first: 20 dmg, radius-100 blast).
MIX = ["mortar", "shotgun", "arc", "ripple", "scanline", "ring", "bullet"]
BARRAGE_MIN_ENERGY = 60  # bank at least this before opening a barrage
# (higher than before: real trap costs are 8..15, so
# a burst needs more banked to overlap several hazards)
BARRAGE_WINDOW = ICE_LIFETIME - 0.5  # keep raining for the ice's lifetime
ICE_REFRESH_GAP = 2.6  # re-ice mid-barrage to keep them slippery
MAX_SUBMITS_PER_TICK = 2  # stay under the scheduler's queue (max 3)
BULLET_MIN_ENERGY = 15  # cheap homing shot; only skip it when nearly broke
# The mortar is repurposed as orb denial: it lobs at the energy-orb spot (not the
# player) at a RANDOM frequency -- each time it's ready it fires only with this
# probability, so the player can't predict/time a safe grab. The orb is
# stationary, so no flight-time lead is needed.
MORTAR_ORB_PROB = 0.35

# Per-trap energy cost and cooldown, mirrored from Data/trap.json so we don't
# waste RPCs on requests the game would reject.
COST = {
    "mine": 5,
    "ring": 15,
    "bullet": 5,
    "conveyor": 10,
    "ice": 10,
    "scanline": 15,
    "ripple": 15,
    "arc": 15,
    "mortar": 8,
    "shotgun": 10,
}
COOLDOWN = {
    "mine": 0.2,
    "ring": 3.0,
    "bullet": 0.0,
    "conveyor": 3.0,
    "ice": 2.0,
    "scanline": 0.5,
    "ripple": 1.0,
    "arc": 1.0,
    "mortar": 0.5,
    "shotgun": 1.0,
}


# --- small vector helpers (api.Vector2 is intentionally bare) -----------------


def _sign(v: float) -> float:
    return 1.0 if v >= 0.0 else -1.0


def _add(a: Vector2, b: Vector2) -> Vector2:
    return Vector2(a.x + b.x, a.y + b.y)


def _sub(a: Vector2, b: Vector2) -> Vector2:
    return Vector2(a.x - b.x, a.y - b.y)


def _scale(a: Vector2, k: float) -> Vector2:
    return Vector2(a.x * k, a.y * k)


def _len(a: Vector2) -> float:
    return math.hypot(a.x, a.y)


def _norm(a: Vector2) -> Vector2:
    n = _len(a)
    if n == 0.0:
        ang = random.uniform(0.0, math.tau)
        return Vector2(math.cos(ang), math.sin(ang))
    return Vector2(a.x / n, a.y / n)


def _rot(a: Vector2, radians: float) -> Vector2:
    c, s = math.cos(radians), math.sin(radians)
    return Vector2(a.x * c - a.y * s, a.x * s + a.y * c)


def _perp(a: Vector2) -> Vector2:
    return Vector2(-a.y, a.x)


def _clamp_box(a: Vector2, ax: float, ay: float) -> Vector2:
    return Vector2(max(-ax, min(ax, a.x)), max(-ay, min(ay, a.y)))


def _rand_dir() -> Vector2:
    ang = random.uniform(0.0, math.tau)
    return Vector2(math.cos(ang), math.sin(ang))


def _dir_to_center(pos: Vector2) -> Direction:
    """The cardinal Direction that pushes ``pos`` back toward the arena center."""
    if abs(pos.x) >= abs(pos.y):
        return Direction.LEFT if pos.x > 0.0 else Direction.RIGHT
    return Direction.UP if pos.y > 0.0 else Direction.DOWN


def snap_to_edge(direction: Vector2, edge: float) -> Vector2:
    """Actual edge-spawn point the game will use for a given bearing (Clamper)."""
    d = _norm(direction)
    if abs(d.x) > abs(d.y):
        mult = edge * _sign(d.x) / d.x
        return Vector2(edge * _sign(d.x), d.y * mult)
    mult = edge * _sign(d.y) / d.y
    return Vector2(d.x * mult, edge * _sign(d.y))


def line_box_chord(point: Vector2, unit_dir: Vector2, edge: float):
    """Two +/-edge-box boundary points on the line through ``point`` (for arc)."""
    t0, t1 = -math.inf, math.inf
    for p, d, lo, hi in (
        (point.x, unit_dir.x, -edge, edge),
        (point.y, unit_dir.y, -edge, edge),
    ):
        if abs(d) < 1e-9:
            if p < lo or p > hi:
                return None
            continue
        ta, tb = (lo - p) / d, (hi - p) / d
        if ta > tb:
            ta, tb = tb, ta
        t0, t1 = max(t0, ta), min(t1, tb)
    if t0 > t1:
        return None
    return _add(point, _scale(unit_dir, t0)), _add(point, _scale(unit_dir, t1))


# --- bookkeeping -------------------------------------------------------------


class CooldownBook:
    """Local mirror of each trap's cooldown so we don't waste RPCs on rejects."""

    def __init__(self) -> None:
        self._t: dict[str, float] = {}

    def ready(self, name: str, now: float) -> bool:
        return now - self._t.get(name, -1e9) >= COOLDOWN.get(name, 3.0)

    def mark(self, name: str, now: float) -> None:
        self._t[name] = now


class Tracker:
    """Position sampler -> velocity estimate -> lead prediction."""

    def __init__(self) -> None:
        self.pos = Vector2(0.0, 0.0)
        self.vel = Vector2(0.0, 0.0)
        self._t = None

    def update(self, pos: Vector2, now: float) -> None:
        if self._t is not None:
            dt = now - self._t
            if dt > 1e-3:
                raw = _scale(_sub(pos, self.pos), 1.0 / dt)
                if _len(raw) > PLAYER_MAX_SPEED:
                    raw = _scale(_norm(raw), PLAYER_MAX_SPEED)
                self.vel = _add(
                    _scale(self.vel, VEL_SMOOTHING), _scale(raw, 1.0 - VEL_SMOOTHING)
                )
        self.pos = pos
        self._t = now

    def speed(self) -> float:
        return _len(self.vel)

    def predict(self, lead: float, cap: float = 150.0) -> Vector2:
        disp = _scale(self.vel, lead)
        if _len(disp) > cap:
            disp = _scale(_norm(disp), cap)
        return _clamp_box(_add(self.pos, disp), ARENA, ARENA)


# --- trap casters (each returns the game's result dict) ----------------------


def cast_ice(client, tracker: Tracker) -> dict:
    # Put the ice where the player IS, so they're standing on it immediately.
    return client.spawn_trap5(_clamp_box(tracker.pos, 175.0, 175.0))


def cast_mine(client, tracker: Tracker) -> dict:
    # Anti-jump: a mine detonates when the player LANDS on it from a jump, but
    # harmlessly disarms if walked over grounded. Place it OFF the player's feet
    # (a mine directly under a standing player just disarms) so it covers a
    # jump-dodge landing spot.
    ang = random.uniform(0.0, math.tau)
    r = random.uniform(*MINE_OFFSET)
    off = Vector2(math.cos(ang) * r, math.sin(ang) * r)
    return client.spawn_trap1(_clamp_box(_add(tracker.pos, off), ARENA, ARENA))


def cast_conveyor(client, tracker: Tracker) -> dict:
    # Shove the player back toward center so they can't stroll out of the kill
    # zone. On ice (accel 5) the push barely gets fought back -> they slide.
    pos = _clamp_box(tracker.pos, 195.0, 195.0)
    return client.spawn_trap4(pos, _dir_to_center(tracker.pos))


def cast_ring(client) -> dict:
    # Electric ring auto-centers on the player during its fill, then locks and
    # zaps its rim. Punishes crossing the rim -- combos with the conveyor/mortar
    # that force movement and with ice that makes stopping precisely hard.
    return client.spawn_trap2(RING_DELAY, random.uniform(*RING_RADIUS))


def cast_shotgun(client, target: Vector2, spawn_bearing: Vector2) -> dict:
    # spawn_bearing picks WHICH edge to fire from; random each time so successive
    # shots come in from different angles. Tight spread (target is iced/pinned).
    spawn = snap_to_edge(spawn_bearing, EDGE_SHOTGUN)
    center = _norm(_sub(target, spawn))
    spread = math.radians(SHOTGUN_TIGHT_DEG)
    return client.spawn_trap10(
        spawn, _rot(center, -spread), center, _rot(center, spread)
    )


def cast_mortar(client, target: Vector2, tracker: Tracker) -> dict:
    start = snap_to_edge(_rand_dir(), EDGE_MORTAR)
    end = _clamp_box(target, ARENA, ARENA)
    return client.spawn_trap9(start, end, MORTAR_AIR_TIME)


def cast_arc(client, target: Vector2, tracker: Tracker) -> dict:
    line = _norm(_perp(tracker.vel)) if tracker.speed() > 25.0 else Vector2(1.0, 0.0)
    chord = line_box_chord(
        _clamp_box(target, EDGE_ARC - 1.0, EDGE_ARC - 1.0), line, EDGE_ARC
    )
    if chord is None:
        y = max(-(EDGE_ARC - 1.0), min(EDGE_ARC - 1.0, target.y))
        chord = (Vector2(-EDGE_ARC, y), Vector2(EDGE_ARC, y))
    return client.spawn_trap8(chord[0], chord[1])


def cast_ripple(client, target: Vector2, tracker: Tracker) -> dict:
    return client.spawn_trap7(_clamp_box(target, *RIPPLE_LIMIT), RIPPLE_EXPAND)


def cast_bullet(client, target: Vector2, tracker: Tracker) -> dict:
    spawn = snap_to_edge(_rand_dir(), EDGE_BULLET)
    return client.spawn_trap3(spawn, _sub(target, spawn), BULLET_SPEED)


def cast_scanline(client) -> dict:
    direction = random.choice(
        [Direction.UP, Direction.DOWN, Direction.LEFT, Direction.RIGHT]
    )
    return client.spawn_trap6(direction, random.uniform(*SCANLINE_SPEED))


def cast_from_mix(name: str, client, target: Vector2, tracker: Tracker, ball) -> dict:
    if name == "mortar":
        # Orb denial: land the shell on the energy-orb spot, not the player.
        aim = ball if ball is not None else target
        return cast_mortar(client, aim, tracker)
    if name == "shotgun":
        return cast_shotgun(client, target, _rand_dir())
    if name == "arc":
        return cast_arc(client, target, tracker)
    if name == "ripple":
        return cast_ripple(client, target, tracker)
    if name == "scanline":
        return cast_scanline(client)
    if name == "ring":
        return cast_ring(client)
    return cast_bullet(client, target, tracker)


# --- targeting ---------------------------------------------------------------


def choose_target(tracker: Tracker, ball) -> Vector2:
    aim = tracker.predict(SHOTGUN_LEAD)
    if ball is not None and _len(_sub(tracker.pos, ball)) < BALL_INTERCEPT_RANGE:
        aim = _clamp_box(
            Vector2((aim.x + ball.x) / 2.0, (aim.y + ball.y) / 2.0), ARENA, ARENA
        )
    return aim


# --- main loop ---------------------------------------------------------------


def run(client) -> None:
    tracker = Tracker()
    book = CooldownBook()
    ball = None
    last_health = None
    last_ball_read = last_health_read = last_status = 0.0
    last_ice = -1e9
    last_mine = -1e9
    barrage_until = -1e9
    mix_i = 0

    print(
        "[test_agent] ICE-ANCHORED BARRAGE: pin with ice, mix many traps, "
        "mine the landings, shove with the conveyor"
    )

    while True:
        now = time.monotonic()
        tracker.update(Vector2.from_list(client.get_opponent_player_position()), now)
        energy = client.get_my_energy()

        if now - last_ball_read >= 0.5:
            last_ball_read = now
            ball = Vector2.from_list(client.get_opponent_energy_ball_position())

        if now - last_health_read >= 0.35:
            last_health_read = now
            hp = client.get_my_health()
            if last_health is not None and hp < last_health:
                print(f"  HIT! hp {last_health} -> {hp}")
            last_health = hp

        in_barrage = now < barrage_until
        if now - last_status >= STATUS_EVERY_SEC:
            last_status = now
            print(
                f"energy={energy} player=({tracker.pos.x:.0f},{tracker.pos.y:.0f}) "
                f"spd={tracker.speed():.0f} mode={'BARRAGE' if in_barrage else 'bank'}"
            )

        target = choose_target(tracker, ball)
        submits = 0

        def try_mine(now=now):
            # Sprinkle an anti-jump mine around the player, respecting cooldown,
            # the sprinkle throttle, energy and the per-tick submit budget.
            nonlocal energy, last_mine, submits
            if (
                submits >= MAX_SUBMITS_PER_TICK
                or not book.ready("mine", now)
                or energy < COST["mine"]
                or now - last_mine < MINE_GAP
            ):
                return
            if cast_mine(client, tracker).get("ok"):
                book.mark("mine", now)
                energy -= COST["mine"]
                last_mine = now
                submits += 1
                print("  * mine")

        if not in_barrage:
            # BANK until we can afford a real barrage, then drop ice to open it.
            # Below the threshold we fire nothing -- energy is saved, not wasted.
            if energy >= BARRAGE_MIN_ENERGY and book.ready("ice", now):
                if cast_ice(client, tracker).get("ok"):
                    book.mark("ice", now)
                    energy -= COST["ice"]
                    last_ice = now
                    barrage_until = now + BARRAGE_WINDOW
                    submits += 1
                    print("== ICE BARRAGE ==")
                    # Set the pin as part of the opener: freeze the floor AND
                    # start shoving them back toward the kill zone.
                    if (
                        submits < MAX_SUBMITS_PER_TICK
                        and book.ready("conveyor", now)
                        and energy >= COST["conveyor"]
                    ):
                        if cast_conveyor(client, tracker).get("ok"):
                            book.mark("conveyor", now)
                            energy -= COST["conveyor"]
                            submits += 1
                            print("  * conveyor->center (pin)")
            elif energy >= BARRAGE_MIN_ENERGY:
                # Banked enough but ice still cooling down: use the wait to
                # pre-arm mines so they're live the instant the barrage opens.
                try_mine()
        else:
            # Keep the player pinned: re-ice under them when it comes off cooldown.
            if (
                book.ready("ice", now)
                and energy >= COST["ice"]
                and now - last_ice >= ICE_REFRESH_GAP
                and submits < MAX_SUBMITS_PER_TICK
            ):
                if cast_ice(client, tracker).get("ok"):
                    book.mark("ice", now)
                    energy -= COST["ice"]
                    last_ice = now
                    submits += 1

            # DAMAGE first: rain a rotating mix at the pinned player. Control
            # traps (conveyor/mine) below only get whatever budget is left, so a
            # burst never wastes its opening slots on non-damaging setup.
            for _ in range(len(MIX)):
                if submits >= MAX_SUBMITS_PER_TICK:
                    break
                name = MIX[mix_i]
                mix_i = (mix_i + 1) % len(MIX)
                if not book.ready(name, now):
                    continue
                # Mortar fires at the orb spot only at a random frequency.
                if name == "mortar" and (
                    ball is None or random.random() > MORTAR_ORB_PROB
                ):
                    continue
                if name == "bullet" and energy < BULLET_MIN_ENERGY:
                    continue
                if energy < COST[name]:
                    continue
                res = cast_from_mix(name, client, target, tracker, ball)
                reason = res.get("reason", "")
                if res.get("ok"):
                    book.mark(name, now)
                    energy -= COST[name]
                    submits += 1
                    print(f"  * {name}")
                elif reason == "cooldown_active":
                    book.mark(name, now)
                elif reason == "scheduler_cannot_accept_request":
                    break  # queue full this instant; try again next tick

            # Leftover budget -> re-pin the shove (brutal with ice: they slide).
            if (
                submits < MAX_SUBMITS_PER_TICK
                and book.ready("conveyor", now)
                and energy >= COST["conveyor"]
            ):
                if cast_conveyor(client, tracker).get("ok"):
                    book.mark("conveyor", now)
                    energy -= COST["conveyor"]
                    submits += 1
                    print("  * conveyor->center")

            # Leftover budget -> keep sprinkling anti-jump mines around their feet.
            try_mine()

        time.sleep(TICK_SEC)


# ruff: enable[F403]
