class_name GameAgent
extends Node

const _REAP_INTERVAL := 1.0

const TRAP_IDS := {
	1: "trap1-mine",
	2: "trap2-electric_ring",
	3: "trap3-tracing_bullet",
	4: "trap4-conveyor",
	5: "trap5-icefloor",
	6: "trap6-scanline",
	7: "trap7-spreading_ripples",
	8: "trap8-electric_arc",
	9: "trap9-mortar",
	10: "trap10-shotgun",
}

# Failures the agent can do nothing about (our bug, not the agent's input).
const _INTERNAL_REASONS := [
	"game_not_assigned",
	"trap_request_scheduler_not_assigned",
	"scheduler_submit_failed",
]

var game: Node2D

var bundle_dir := ""
var agent_file := ""
var _conn: WebSocketConnection
var _command_handlers: Dictionary[String, Callable] = {}
var _agent_pid := -1
var _agent_script_path := ""
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

	if OS.has_feature("macos") and Global.single_player and agent_file != "":
		_spawn_agent_process_macos_terminal(token, python, runner, libs)
		return

	OS.set_environment("PYTHONPATH", libs)
	OS.set_environment("CHALLENGE_WS_URL", "ws://127.0.0.1:%d" % ApiServer.port)
	OS.set_environment("CHALLENGE_TOKEN", token)
	if agent_file != "":
		OS.set_environment("CHALLENGE_AGENT_PATH", agent_file)
	else:
		OS.unset_environment("CHALLENGE_AGENT_PATH")
	if (Global.single_player) and agent_file != "":
		OS.set_environment("CHALLENGE_AGENT_LOG", "1")
		_agent_pid = OS.create_process(python, ["-s", runner], true)
	else:
		OS.unset_environment("CHALLENGE_AGENT_LOG")
		_agent_pid = OS.create_process(python, ["-s", runner])

	print("[API Server] agent process pid: %d" % _agent_pid)


func _spawn_agent_process_macos_terminal(
	token: String, python: String, runner: String, libs: String
) -> void:
	var short_token := token.left(8)
	var script_path := "/tmp/challenge_agent_%s.command" % short_token
	var pid_path := "/tmp/challenge_agent_%s.pid" % short_token
	var url := "ws://127.0.0.1:%d" % ApiServer.port

	var content := "#!/bin/bash\n"
	content += 'echo $$ > "%s"\n' % pid_path
	content += 'export PYTHONPATH="%s"\n' % libs
	content += 'export CHALLENGE_WS_URL="%s"\n' % url
	content += 'export CHALLENGE_TOKEN="%s"\n' % token
	content += 'export CHALLENGE_AGENT_PATH="%s"\n' % agent_file
	content += "export CHALLENGE_AGENT_LOG=1\n"
	content += 'exec "%s" -s "%s"\n' % [python, runner]

	var file := FileAccess.open(script_path, FileAccess.WRITE)
	if file == null:
		printerr("[API Server] failed to create agent launch script: %s" % script_path)
		return
	file.store_string(content)
	file.close()

	OS.execute("chmod", ["+x", script_path])
	OS.execute("open", ["-a", "Terminal", script_path])
	_agent_script_path = script_path
	_agent_pid = -1
	print("[API Server] agent launched in Terminal.app")


func _bundle_python() -> String:
	if OS.has_feature("windows"):
		return bundle_dir + "/python/python.exe"
	return bundle_dir + "/python/bin/python3.11"


func _exit_tree() -> void:
	if is_instance_valid(_conn):
		_conn.disconnect_from_socket()
	if _agent_script_path != "":
		var pid_path := _agent_script_path.replace(".command", ".pid")
		if FileAccess.file_exists(pid_path):
			var pid_file := FileAccess.open(pid_path, FileAccess.READ)
			if pid_file:
				var pid_str := pid_file.get_as_text().strip_edges()
				pid_file.close()
				var pid := pid_str.to_int()
				if pid > 0 and OS.is_process_running(pid):
					OS.kill(pid)
					print("[API Server] agent process %d stopped" % pid)
			DirAccess.remove_absolute(pid_path)
		DirAccess.remove_absolute(_agent_script_path)
		_agent_script_path = ""
	if _agent_pid >= 0 and OS.is_process_running(_agent_pid):
		OS.kill(_agent_pid)
		print("[API Server] agent process %d stopped" % _agent_pid)


func shutdown() -> void:
	if is_instance_valid(_conn):
		_conn.disconnect_from_socket()


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
	register_command("get_opponent_player_velocity", _cmd_get_opponent_player_velocity)
	register_command("get_elapsed_time", _cmd_get_elapsed_time)
	register_command("get_opponent_combo", _cmd_get_opponent_combo)
	register_command("get_phase", _cmd_get_phase)
	register_command("get_available_traps", _cmd_get_available_traps)
	register_command("get_cooldown_time", _cmd_get_cooldown_time)
	register_command("get_current_stock", _cmd_get_current_stock)


func register_command(cmd_name: String, handler: Callable) -> void:
	_command_handlers[cmd_name] = handler


# Non-empty when the game world is unusable; handlers must not run then,
# because GDScript has no try/catch — a null deref would drop the response
# and hang the agent's pending request forever.
func _internal_reason() -> String:
	if not is_instance_valid(game):
		return "game_not_assigned"
	if not is_instance_valid(game.player):
		return "player_missing"
	if not is_instance_valid(game.energy_ball):
		return "energy_ball_missing"
	return ""


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


func _read_required_int(args: Dictionary, key: String) -> Dictionary:
	if not args.has(key):
		return {"ok": false, "value": 0, "reason": "missing_" + key}

	var value: Variant = args[key]
	if not _is_number(value) or float(value) != floorf(float(value)):
		return {"ok": false, "value": 0, "reason": "invalid_" + key}

	return {"ok": true, "value": int(value), "reason": ""}


func _submit_trap(trap_id: String, params: Dictionary) -> Dictionary:
	var agent_action_service: AgentActionService = game.get_agent_action_service()
	var result: Dictionary = agent_action_service.submit_trap_request_result(trap_id, params)
	if not result["ok"]:
		var code := 500 if result["reason"] in _INTERNAL_REASONS else 409
		return ApiServer.err(code, result["reason"])
	return ApiServer.ok(true)


# gdlint: disable=max-returns
func _coerce_to_vector2(value: Variant) -> Dictionary:
	if typeof(value) == TYPE_VECTOR2:
		return {"ok": true, "value": value}

	if typeof(value) == TYPE_ARRAY:
		if value.size() != 2:
			return {"ok": false, "value": Vector2.ZERO}
		if not _is_number(value[0]) or not _is_number(value[1]):
			return {"ok": false, "value": Vector2.ZERO}
		return {"ok": true, "value": Vector2(float(value[0]), float(value[1]))}

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
		return ApiServer.err(400, r["reason"])
	return _submit_trap("trap1-mine", r["params"])


func _cmd_spawn_trap2(args: Dictionary) -> Dictionary:
	var r := _read_required(args, [], ["delay_time", "radius"])
	if not r["ok"]:
		return ApiServer.err(400, r["reason"])
	return _submit_trap("trap2-electric_ring", r["params"])


func _cmd_spawn_trap3(args: Dictionary) -> Dictionary:
	var r := _read_required(args, ["position", "direction"], ["speed"])
	if not r["ok"]:
		return ApiServer.err(400, r["reason"])
	return _submit_trap("trap3-tracing_bullet", r["params"])


func _cmd_spawn_trap4(args: Dictionary) -> Dictionary:
	var r := _read_required(args, ["position", "direction"], [])
	if not r["ok"]:
		return ApiServer.err(400, r["reason"])
	return _submit_trap("trap4-conveyor", r["params"])


func _cmd_spawn_trap5(args: Dictionary) -> Dictionary:
	var r := _read_required(args, ["position"], [])
	if not r["ok"]:
		return ApiServer.err(400, r["reason"])
	return _submit_trap("trap5-icefloor", r["params"])


func _cmd_spawn_trap6(args: Dictionary) -> Dictionary:
	var r := _read_required(args, ["direction"], ["speed"])
	if not r["ok"]:
		return ApiServer.err(400, r["reason"])
	return _submit_trap("trap6-scanline", r["params"])


func _cmd_spawn_trap7(args: Dictionary) -> Dictionary:
	var r := _read_required(args, ["position"], ["expand_rate"])
	if not r["ok"]:
		return ApiServer.err(400, r["reason"])
	return _submit_trap("trap7-spreading_ripples", r["params"])


func _cmd_spawn_trap8(args: Dictionary) -> Dictionary:
	var r := _read_required(args, ["start_position", "end_position"], [])
	if not r["ok"]:
		return ApiServer.err(400, r["reason"])
	return _submit_trap("trap8-electric_arc", r["params"])


func _cmd_spawn_trap9(args: Dictionary) -> Dictionary:
	var r := _read_required(args, ["start_position", "end_position"], ["air_time"])
	if not r["ok"]:
		return ApiServer.err(400, r["reason"])
	return _submit_trap("trap9-mortar", r["params"])


func _cmd_spawn_trap10(args: Dictionary) -> Dictionary:
	var r := _read_required(args, ["position", "dir1", "dir2", "dir3"], [])
	if not r["ok"]:
		return ApiServer.err(400, r["reason"])
	return _submit_trap("trap10-shotgun", r["params"])


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


func _cmd_get_opponent_player_velocity(_args: Dictionary) -> Dictionary:
	var vel: Vector2 = game.get_opponent_player_velocity()
	return ApiServer.ok([vel.x, vel.y])


func _cmd_get_elapsed_time(_args: Dictionary) -> Dictionary:
	return ApiServer.ok(game.get_elapsed_time())


func _cmd_get_opponent_combo(_args: Dictionary) -> Dictionary:
	return ApiServer.ok(game.get_opponent_combo())


func _cmd_get_phase(_args: Dictionary) -> Dictionary:
	return ApiServer.ok(game.get_phase())


func _cmd_get_available_traps(_args: Dictionary) -> Dictionary:
	var action_service: AgentActionService = game.get_agent_action_service()
	var numbers: Array = []
	for trap_id in action_service.get_available_traps():
		numbers.append(TRAP_IDS.find_key(trap_id))
	numbers.sort()
	return ApiServer.ok(numbers)


func _cmd_get_cooldown_time(args: Dictionary) -> Dictionary:
	var req := _read_required_int(args, "trap_id")
	if not req["ok"]:
		return ApiServer.err(400, req["reason"])
	if not TRAP_IDS.has(req["value"]):
		return ApiServer.err(404, "unknown_trap")
	var action_service: AgentActionService = game.get_agent_action_service()
	var cooldown: float = action_service.get_cooldown_time(TRAP_IDS[req["value"]])
	return ApiServer.ok(cooldown)


func _cmd_get_current_stock(args: Dictionary) -> Dictionary:
	var req := _read_required_int(args, "trap_id")
	if not req["ok"]:
		return ApiServer.err(400, req["reason"])
	if not TRAP_IDS.has(req["value"]):
		return ApiServer.err(404, "unknown_trap")
	var action_service: AgentActionService = game.get_agent_action_service()
	var stock: int = action_service.get_current_stock(TRAP_IDS[req["value"]])
	return ApiServer.ok(stock)


func _cmd_heal(_args: Dictionary) -> Dictionary:
	var result: Dictionary = game.get_agent_action_service().request_heal()
	if not result["ok"]:
		return ApiServer.err(409, result["reason"])
	result.erase("ok")
	result.erase("reason")
	return ApiServer.ok(result)


#endregion


func _on_received_text(msg: String) -> void:
	# Deserialize
	var data: Variant = JSON.parse_string(msg)
	if typeof(data) != TYPE_DICTIONARY:
		_conn.send_text(JSON.stringify(ApiServer.err(400, "illformed_request")))
		return

	var req_id: Variant = data.get("id")
	var cmd: String = data.get("cmd", "")
	var args: Variant = data.get("args", {})
	if typeof(args) != TYPE_DICTIONARY:
		args = {}

	var handler: Callable = _command_handlers.get(cmd, Callable())
	var response: Dictionary
	if not handler.is_valid():
		response = ApiServer.err(404, "unknown_command")
	elif cmd != "ping" and _internal_reason() != "":
		# Guard every gameplay handler in one place (see _internal_reason).
		response = ApiServer.err(500, _internal_reason())
	else:
		response = handler.call(args)
	response["id"] = req_id
	_conn.send_text(JSON.stringify(response))
