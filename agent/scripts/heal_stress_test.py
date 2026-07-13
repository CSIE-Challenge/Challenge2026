"""A focused heal stress-test agent.

Keep this agent on one client while another client places traps.
It continuously tries to heal when your health is below the observed max,
and prints refusals (energy/uses issues) for manual verification.
"""

import time

from api import ApiError

LOOP_INTERVAL_SEC = 0.35
LOG_INTERVAL_SEC = 1.5


def _print_status(
    health: int,
    energy: int,
    phase: int,
    uses_left: int | None,
    heal_result: str,
) -> None:
    uses_text = (
        f"uses_left={uses_left}" if uses_left is not None else "uses_left=unknown"
    )
    print(
        f"[heal_stress] hp={health} energy={energy} "
        f"phase={phase} {uses_text} | {heal_result}"
    )


def _snapshot_state(client):
    health = client.get_my_health()
    if isinstance(health, ApiError):
        print(f"[heal_stress] get_my_health error: {health}")
        return None

    energy = client.get_my_energy()
    if isinstance(energy, ApiError):
        print(f"[heal_stress] get_my_energy error: {energy}")
        return None

    phase = client.get_phase()
    if isinstance(phase, ApiError):
        print(f"[heal_stress] get_phase error: {phase}")
        return None

    return health, energy, phase


def run(client) -> None:
    initial_health = client.get_my_health()
    if isinstance(initial_health, ApiError):
        print(f"[heal_stress] cannot read initial health: {initial_health}")
        return

    observed_max_health = int(initial_health)
    print(
        "[heal_stress] start. "
        f"Observed initial health={observed_max_health}. "
        "Script will keep attempting heal when hp drops below this value."
    )

    last_log = 0.0
    last_heal_result = "init"
    last_uses_left = None

    while True:
        snapshot = _snapshot_state(client)
        if snapshot is None:
            time.sleep(LOOP_INTERVAL_SEC)
            continue

        health, energy, phase = snapshot
        if health > observed_max_health:
            observed_max_health = health

        if health < observed_max_health:
            result = client.heal()
            if isinstance(result, ApiError):
                last_heal_result = f"heal_refused={result.reason}"
                # Keep trying so phase/energy changes are continuously observed.
            else:
                last_uses_left = (
                    result.get("heal_uses_left") if isinstance(result, dict) else None
                )
                last_heal_result = (
                    f"heal_ok hp={result.get('health', health)} "
                    f"energy={result.get('energy', energy)} "
                    f"uses={last_uses_left}"
                )
                health = result.get("health", health)
                energy = result.get("energy", energy)
        elif time.time() - last_log >= LOG_INTERVAL_SEC:
            last_heal_result = "idle"

        if time.time() - last_log >= LOG_INTERVAL_SEC:
            _print_status(health, energy, phase, last_uses_left, last_heal_result)
            last_log = time.time()

        time.sleep(LOOP_INTERVAL_SEC)
