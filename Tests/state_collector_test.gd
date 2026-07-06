extends SceneTree

const StateCollectorScript = preload("res://Scripts/network/state_collector.gd")
const PUSH_INTERVAL := 1.0 / 30.0


func _init() -> void:
	_run_tests.call_deferred()


func _run_tests() -> void:
	var sc := StateCollectorScript.new()
	root.add_child(sc)

	# Wait one frame for _ready() to execute and create the Timer
	await process_frame

	# TEST 1: StateCollector creates a Timer child
	var timer: Timer = sc.get_node_or_null("StatePushTimer") as Timer
	_assert(timer != null, "should create a StatePushTimer child")

	# TEST 2: Timer has correct interval (~1/30 second)
	_assert(
		abs(timer.wait_time - PUSH_INTERVAL) < 0.001,
		"timer interval should be 1/30 second (got %.4f)" % timer.wait_time
	)

	# TEST 3: Timer uses physics process callback
	_assert_eq(
		timer.process_callback,
		Timer.TIMER_PROCESS_PHYSICS,
		"timer should use physics process callback"
	)

	# TEST 4: Timer timeout signal is connected (to _on_push_tick)
	var connections: Array = timer.timeout.get_connections()
	_assert(connections.size() > 0, "timer timeout should be connected")

	print("StateCollector tests passed")
	sc.queue_free()
	quit(0)


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)


func _assert_eq(actual, expected, message := "") -> void:
	if actual == expected:
		return
	push_error("%s expected <%s>, got <%s>" % [message, expected, actual])
	quit(1)
