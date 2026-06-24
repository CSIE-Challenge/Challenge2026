class_name StateCollector
extends Node

## Runs only on the server. Drives periodic (~30 fps) state collection
## from game clients and pushes combined state to the demo peer.

const PUSH_INTERVAL := 1.0 / 30.0


func _ready() -> void:
	if not multiplayer.is_server():
		return

	var timer := Timer.new()
	timer.name = "StatePushTimer"
	timer.wait_time = PUSH_INTERVAL
	timer.process_callback = Timer.TIMER_PROCESS_PHYSICS
	timer.autostart = true
	timer.timeout.connect(_on_push_tick)
	add_child(timer)
	timer.start()

	print("[StateCollector] Started — pushing state every %.1f ms" % (PUSH_INTERVAL * 1000.0))


func _on_push_tick() -> void:
	var nm := get_node_or_null("/root/NetworkManager")
	if nm and nm.has_method("_push_state_to_demo"):
		nm._push_state_to_demo()
