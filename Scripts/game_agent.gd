class_name GameAgent
extends Node

const _REAP_INTERVAL := 1.0

var game: Node2D

var bundle_dir := ""
var agent_file := ""
var _conn: WebSocketConnection
var _command_handlers: Dictionary[String, Callable] = {}
var _agent_pid := -1
var _reap_accum := 0.0


func _init() -> void:
	# keep serving requests even while the game is paused
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	_conn = ApiServer.register_connection()
	add_child(_conn)
	_conn.received_text.connect(_on_received_text)
	print("[API Server] agent token: %s" % _conn.get_token())

	_register_commands()

	if bundle_dir != "":
		_spawn_agent_process(_conn.get_token())


func _process(delta: float) -> void:
	if _agent_pid < 0:
		return
	_reap_accum += delta
	if _reap_accum < _REAP_INTERVAL:
		return
	_reap_accum = 0.0
	if not OS.is_process_running(_agent_pid):
		print("[API Server] agent process %d exited" % _agent_pid)
		_agent_pid = -1


## Launch the player's Python agent from the downloaded bundle.
func _spawn_agent_process(token: String) -> void:
	var python := _bundle_python()
	var runner := bundle_dir + "/runner.py"
	var libs := bundle_dir + "/libs"
	if OS.has_feature("linux") or OS.has_feature("macos"):
		OS.execute("chmod", ["+x", python])

	OS.set_environment("PYTHONPATH", libs)
	OS.set_environment("CHALLENGE_WS_URL", "ws://127.0.0.1:%d" % ApiServer.port)
	OS.set_environment("CHALLENGE_TOKEN", token)
	if agent_file != "":
		OS.set_environment("CHALLENGE_AGENT_PATH", agent_file)
	else:
		OS.unset_environment("CHALLENGE_AGENT_PATH")

	_agent_pid = OS.create_process(python, ["-s", runner])
	print("[API Server] agent process pid: %d" % _agent_pid)


func _bundle_python() -> String:
	if OS.has_feature("windows"):
		return bundle_dir + "/python/python.exe"
	return bundle_dir + "/python/bin/python3.11"


func _exit_tree() -> void:
	if _agent_pid >= 0 and OS.is_process_running(_agent_pid):
		OS.kill(_agent_pid)
		print("[API Server] agent process %d stopped" % _agent_pid)


# Add one line per new API.
func _register_commands() -> void:
	register_command("ping", _cmd_ping)

	# Actions.
	register_command("heal", _cmd_heal)

	# Traps.
	register_command("spawn_trap1", _cmd_spawn_trap1)
	register_command("spawn_trap2", _cmd_spawn_trap2)
	register_command("spawn_trap3", _cmd_spawn_trap3)
	register_command("spawn_trap4", _cmd_spawn_trap4)
	register_command("spawn_trap5", _cmd_spawn_trap5)
	register_command("spawn_trap6", _cmd_spawn_trap6)
	register_command("spawn_trap7", _cmd_spawn_trap7)
	register_command("spawn_trap8", _cmd_spawn_trap8)
	register_command("spawn_trap9", _cmd_spawn_trap9)
	register_command("spawn_trap10", _cmd_spawn_trap10)

	# Reads.
	register_command("get_my_energy", _cmd_get_my_energy)
	register_command("get_my_health", _cmd_get_my_health)
	register_command("get_opponent_player_position", _cmd_get_opponent_player_position)
	register_command("get_opponent_energy_ball_position", _cmd_get_opponent_energy_ball_position)


func register_command(cmd_name: String, handler: Callable) -> void:
	_command_handlers[cmd_name] = handler


# Helpers used by gameplay APIs.
func _is_number(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT


func _read_required(args: Dictionary, vec_keys: Array, float_keys: Array) -> Dictionary:
	var params: Dictionary = {}

	for key in vec_keys:
		var vec := _read_required_vector2(args, key)
		if not vec["ok"]:
			return {"ok": false, "params": {}, "reason": vec["reason"]}
		params[key] = vec["value"]

	for key in float_keys:
		var num := _read_required_float(args, key)
		if not num["ok"]:
			return {"ok": false, "params": {}, "reason": num["reason"]}
		params[key] = num["value"]

	return {"ok": true, "params": params, "reason": ""}


func _read_required_vector2(args: Dictionary, key: String) -> Dictionary:
	if not args.has(key):
		return {"ok": false, "value": Vector2.ZERO, "reason": "missing_" + key}

	var parsed := _coerce_to_vector2(args[key])
	if not parsed["ok"]:
		return {"ok": false, "value": Vector2.ZERO, "reason": "invalid_" + key}

	return {"ok": true, "value": parsed["value"], "reason": ""}


func _read_required_float(args: Dictionary, key: String) -> Dictionary:
	if not args.has(key):
		return {"ok": false, "value": 0.0, "reason": "missing_" + key}

	if not _is_number(args[key]):
		return {"ok": false, "value": 0.0, "reason": "invalid_" + key}

	return {"ok": true, "value": float(args[key]), "reason": ""}


func _submit_trap(trap_id: String, params: Dictionary) -> Dictionary:
	var agent_action_service: AgentActionService = game.get_agent_action_service()
	var result: Dictionary = agent_action_service.submit_trap_request_result(trap_id, params)
	return ApiServer.ok(result)


# gdlint: disable=max-returns
func _coerce_to_vector2(value: Variant) -> Dictionary:
	if typeof(value) == TYPE_VECTOR2:
		return {"ok": true, "value": value}

	if typeof(value) == TYPE_ARRAY:
		var arr: Array = value
		if arr.size() != 2:
			return {"ok": false, "value": Vector2.ZERO}
		if not _is_number(arr[0]) or not _is_number(arr[1]):
			return {"ok": false, "value": Vector2.ZERO}
		return {"ok": true, "value": Vector2(float(arr[0]), float(arr[1]))}

	if typeof(value) == TYPE_DICTIONARY:
		var dict: Dictionary = value
		if not (dict.has("x") and dict.has("y")):
			return {"ok": false, "value": Vector2.ZERO}
		if not (_is_number(dict["x"]) and _is_number(dict["y"])):
			return {"ok": false, "value": Vector2.ZERO}
		return {"ok": true, "value": Vector2(float(dict["x"]), float(dict["y"]))}

	return {"ok": false, "value": Vector2.ZERO}


# gdlint: enable=max-returns


#region Command handlers
func _cmd_ping(_args: Dictionary) -> Dictionary:
	return ApiServer.ok("pong")


func _cmd_spawn_trap1(args: Dictionary) -> Dictionary:
	var r := _read_required(args, ["position"], [])
	if not r["ok"]:
		return _trap_reject("trap1-mine", r["reason"])
	return _submit_trap("trap1-mine", r["params"])


func _cmd_spawn_trap2(args: Dictionary) -> Dictionary:
	var r := _read_required(args, [], ["delay_time", "radius"])
	if not r["ok"]:
		return _trap_reject("trap2-electric_ring", r["reason"])
	return _submit_trap("trap2-electric_ring", r["params"])


func _cmd_spawn_trap3(args: Dictionary) -> Dictionary:
	var r := _read_required(args, ["position", "direction"], ["speed"])
	if not r["ok"]:
		return _trap_reject("trap3-tracing_bullet", r["reason"])
	return _submit_trap("trap3-tracing_bullet", r["params"])


func _cmd_spawn_trap4(args: Dictionary) -> Dictionary:
	var r := _read_required(args, ["position", "direction"], [])
	if not r["ok"]:
		return _trap_reject("trap4-conveyor", r["reason"])
	return _submit_trap("trap4-conveyor", r["params"])


func _cmd_spawn_trap5(args: Dictionary) -> Dictionary:
	var r := _read_required(args, ["position"], [])
	if not r["ok"]:
		return _trap_reject("trap5-icefloor", r["reason"])
	return _submit_trap("trap5-icefloor", r["params"])


func _cmd_spawn_trap6(args: Dictionary) -> Dictionary:
	var r := _read_required(args, ["direction"], ["speed"])
	if not r["ok"]:
		return _trap_reject("trap6-scanline", r["reason"])
	return _submit_trap("trap6-scanline", r["params"])


func _cmd_spawn_trap7(args: Dictionary) -> Dictionary:
	var r := _read_required(args, ["position"], ["expand_rate"])
	if not r["ok"]:
		return _trap_reject("trap7-spreading_ripples", r["reason"])
	return _submit_trap("trap7-spreading_ripples", r["params"])


func _cmd_spawn_trap8(args: Dictionary) -> Dictionary:
	var r := _read_required(args, ["start_position", "end_position"], [])
	if not r["ok"]:
		return _trap_reject("trap8-electric_arc", r["reason"])
	return _submit_trap("trap8-electric_arc", r["params"])


func _cmd_spawn_trap9(args: Dictionary) -> Dictionary:
	var r := _read_required(args, ["start_position", "end_position"], ["air_time"])
	if not r["ok"]:
		return _trap_reject("trap9-mortar", r["reason"])
	return _submit_trap("trap9-mortar", r["params"])


func _cmd_spawn_trap10(args: Dictionary) -> Dictionary:
	var r := _read_required(args, ["position", "dir1", "dir2", "dir3"], [])
	if not r["ok"]:
		return _trap_reject("trap10-shotgun", r["reason"])
	return _submit_trap("trap10-shotgun", r["params"])


func _trap_reject(trap_id: String, reason: String) -> Dictionary:
	return ApiServer.ok(
		{"ok": false, "stage": "rejected", "request_id": -1, "trap_id": trap_id, "reason": reason}
	)


func _cmd_get_my_energy(_args: Dictionary) -> Dictionary:
	return ApiServer.ok(NetworkManager.get_energy(NetworkManager.get_opponent_peer_id()))


func _cmd_get_my_health(_args: Dictionary) -> Dictionary:
	return ApiServer.ok(NetworkManager.get_health(NetworkManager.get_opponent_peer_id()))


func _cmd_get_opponent_player_position(_args: Dictionary) -> Dictionary:
	var pos: Vector2 = game.player.position
	return ApiServer.ok([pos.x, pos.y])


func _cmd_get_opponent_energy_ball_position(_args: Dictionary) -> Dictionary:
	var pos: Vector2 = game.energy_ball.position
	return ApiServer.ok([pos.x, pos.y])


func _cmd_heal(_args: Dictionary) -> Dictionary:
	return ApiServer.ok(game.get_agent_action_service().request_heal())


#endregion


func _on_received_text(msg: String) -> void:
	# Deserialize
	var data: Variant = JSON.parse_string(msg)
	if typeof(data) != TYPE_DICTIONARY:
		_conn.send_text(JSON.stringify(ApiServer.err(400)))
		return

	var req_id: Variant = data.get("id")
	var cmd: String = data.get("cmd", "")
	var args: Variant = data.get("args", {})
	if typeof(args) != TYPE_DICTIONARY:
		args = {}

	var handler: Callable = _command_handlers.get(cmd, Callable())
	var response: Dictionary = handler.call(args) if handler.is_valid() else ApiServer.err(404)
	response["id"] = req_id
	_conn.send_text(JSON.stringify(response))
