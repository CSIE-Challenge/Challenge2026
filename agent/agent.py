import time

PLAN = [
    ("trap1-mine", {"position": [120.0, 80.0]}),
    ("trap2-electric_ring", {"delay_time": 1.5, "radius": 100.0}),
    (
        "trap3-tracing_bullet",
        {"position": [100.0, 0.0], "direction": [0.0, -100.0], "speed": 200.0},
    ),
    ("trap5-icefloor", {"position": [150.0, 150.0]}),
    ("trap6-scanline", {"direction": [0.0, -1.0], "speed": 100.0}),
    ("trap7-spreading_ripples", {"position": [300.0, 300.0], "expand_rate": 150.0}),
    (
        "trap8-electric_arc",
        {"start_position": [-100.0, -100.0], "end_position": [100.0, -100.0]},
    ),
    (
        "trap9-mortar",
        {
            "start_position": [200.0, 100.0],
            "end_position": [220.0, 100.0],
            "air_time": 1.0,
        },
    ),
    (
        "trap10-shotgun",
        {
            "position": [-250.0, 100.0],
            "dir1": [1.0, 0.2],
            "dir2": [1.0, 0.0],
            "dir3": [1.0, -0.2],
        },
    ),
]


def run(client):
    for trap_id, params in PLAN:
        # Energy refills over time -- wait and retry until we can afford it.
        while True:
            result = client.request_trap(trap_id, params)
            if result.get("ok"):
                print(f"placed {trap_id} (energy left: {client.get_my_energy()})")
                break
            if result.get("reason") != "insufficient_energy":
                print(f"{trap_id} rejected: {result.get('reason')}")
                break
            time.sleep(1.0)
