class_name GameAgent
extends Node

const _REAP_INTERVAL := 1.0

const TEAM_ID := 0

const TRAP_PARAM_DEFINITIONS := {
	"trap1-mine": {"position": {"type": "vector2", "required": true}},
	"trap2-electric_ring":
	{
		"delay_time": {"type": "float", "required": true},
		"radius": {"type": "float", "required": true},
	},
	"trap3-tracing_bullet":
	{
		"position": {"type": "vector2", "required": true},
		"direction": {"type": "vector2", "required": true},
		"speed": {"type": "float", "required": true},
	},
	"trap4-conveyor":
	{
		"position": {"type": "vector2", "required": true},
		"direction":
		{
			"type": "vector2",
			"required": false,
			"default": Vector2.UP,
		},
	},
	"trap5-icefloor":
	{
		"position": {"type": "vector2", "required": true},
	},
	"trap6-scanline":
	{
		"direction": {"type": "vector2", "required": true},
		"speed": {"type": "float", "required": false, "default": 5.0},
	},
	"trap7-spreading_ripples":
	{
		"position": {"type": "vector2", "required": true},
		"expand_rate": {"type": "float", "required": false, "default": 10.0},
	},
	"trap8-electric_arc":
	{
		"start_position": {"type": "vector2", "required": true},
		"end_position": {"type": "vector2", "required": true},
	},
	"trap9-mortar":
	{
		"start_position": {"type": "vector2", "required": true},
		"end_position": {"type": "vector2", "required": true},
		"air_time": {"type": "float", "required": false, "default": 2.0},
	},
	"trap10-shotgun":
	{
		"position": {"type": "vector2", "required": true},
		"dir1": {"type": "vector2", "required": true},
		"dir2": {"type": "vector2", "required": true},
		"dir3": {"type": "vector2", "required": true},
	},
}

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
	print("[API Server] agent '%s' token: %s" % [name, _conn.get_token()])

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
		print("[API Server] agent '%s' process %d exited" % [name, _agent_pid])
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
	print("[API Server] agent '%s' process pid: %d" % [name, _agent_pid])


func _bundle_python() -> String:
	if OS.has_feature("windows"):
		return bundle_dir + "/python/python.exe"
	return bundle_dir + "/python/bin/python3.11"


func _exit_tree() -> void:
	if _agent_pid >= 0 and OS.is_process_running(_agent_pid):
		OS.kill(_agent_pid)
		print("[API Server] agent '%s' process %d stopped" % [name, _agent_pid])


# Add one line per new API.
func _register_commands() -> void:
	# Actions.
	register_command("ping", _cmd_ping)
	register_command("request_trap", _cmd_request_trap)
	register_command("heal", _cmd_request_heal)

	# Reads.
	register_command("get_my_energy", _cmd_get_my_energy)
	register_command("get_my_health", _cmd_get_my_health)
	register_command("get_opponent_player_position", _cmd_get_opponent_player_position)
	register_command("get_opponent_energy_ball_position", _cmd_get_opponent_energy_ball_position)


func register_command(cmd_name: String, handler: Callable) -> void:
	_command_handlers[cmd_name] = handler


# Helpers used by gameplay APIs.
func _get_team_status_service() -> TeamStatusService:
	if game == null:
		return null

	if not game.has_method("get_team_status_service"):
		return null

	return game.get_team_status_service()


func _is_number(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT


func _read_trap_id(args: Dictionary) -> Dictionary:
	if not args.has("trap_id"):
		return {
			"ok": false,
			"trap_id": "",
			"reason": "missing_trap_id",
		}

	var raw_trap_id: Variant = args["trap_id"]
	if typeof(raw_trap_id) != TYPE_STRING:
		return {
			"ok": false,
			"trap_id": str(raw_trap_id),
			"reason": "invalid_trap_id_type",
		}

	var trap_id: String = str(raw_trap_id)
	if not TRAP_PARAM_DEFINITIONS.has(trap_id):
		return {
			"ok": false,
			"trap_id": trap_id,
			"reason": "unknown_trap",
		}

	return {
		"ok": true,
		"trap_id": trap_id,
		"reason": "",
	}


func _normalize_trap_params(trap_id: String, raw_params: Dictionary) -> Dictionary:
	if not TRAP_PARAM_DEFINITIONS.has(trap_id):
		return {
			"ok": false,
			"params": {},
			"reason": "unknown_trap",
		}

	var normalized_params: Dictionary = {}
	var schema: Dictionary = TRAP_PARAM_DEFINITIONS[trap_id]

	for key in raw_params.keys():
		if not schema.has(key):
			return {
				"ok": false,
				"params": {},
				"reason": "invalid_param_%s" % key,
			}

	for key in schema.keys():
		var field: Dictionary = schema[key]
		var requirement: bool = bool(field.get("required", false))
		var raw_value: Variant = raw_params.get(key)

		if raw_value == null:
			if requirement:
				return {
					"ok": false,
					"params": {},
					"reason": "missing_" + key,
				}
			normalized_params[key] = field.get("default", null)
			continue

		if field["type"] == "vector2":
			var parsed: Dictionary = _coerce_to_vector2(raw_value)
			if not parsed["ok"]:
				return {
					"ok": false,
					"params": {},
					"reason": "invalid_" + key,
				}
			normalized_params[key] = parsed["value"]
		elif field["type"] == "float":
			if not _is_number(raw_value):
				return {
					"ok": false,
					"params": {},
					"reason": "invalid_" + key,
				}
			normalized_params[key] = float(raw_value)
		else:
			normalized_params[key] = raw_value

	return {
		"ok": true,
		"params": normalized_params,
		"reason": "",
	}


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


func _read_float_arg(
	args: Dictionary, key: String, missing_reason: String, invalid_reason: String
) -> Dictionary:
	if not args.has(key):
		return {
			"ok": false,
			"value": 0.0,
			"reason": missing_reason,
		}

	var raw_value: Variant = args[key]

	if not _is_number(raw_value):
		return {
			"ok": false,
			"value": 0.0,
			"reason": invalid_reason,
		}

	return {
		"ok": true,
		"value": float(raw_value),
		"reason": "",
	}


#region Command handlers
#
# Runtime handlers.
func _cmd_ping(_args: Dictionary) -> Dictionary:
	return ApiServer.ok("pong")


func _cmd_request_trap(args: Dictionary) -> Dictionary:
	var read_trap := _read_trap_id(args)
	if not read_trap["ok"]:
		return _trap_reject(read_trap["trap_id"], read_trap["reason"])

	var raw_params: Variant = args.get("params", {})
	if typeof(raw_params) != TYPE_DICTIONARY:
		return _trap_reject(read_trap["trap_id"], "invalid_params_type")

	var normalize_params := _normalize_trap_params(read_trap["trap_id"], raw_params)
	if not normalize_params["ok"]:
		return _trap_reject(read_trap["trap_id"], normalize_params["reason"])

	# A trap is always my action, so it is charged to TEAM_ID.
	var agent_action_service: AgentActionService = game.get_agent_action_service()
	var result: Dictionary = agent_action_service.submit_trap_request_result(
		TEAM_ID, read_trap["trap_id"], normalize_params["params"]
	)

	return ApiServer.ok(result)


func _trap_reject(trap_id: String, reason: String) -> Dictionary:
	return ApiServer.ok(
		{"ok": false, "stage": "rejected", "request_id": -1, "trap_id": trap_id, "reason": reason}
	)


func _cmd_get_my_energy(_args: Dictionary) -> Dictionary:
	return ApiServer.ok(game.energy_amount)


func _cmd_get_my_health(_args: Dictionary) -> Dictionary:
	return ApiServer.ok(int(game.player.health))


func _cmd_get_opponent_player_position(_args: Dictionary) -> Dictionary:
	var pos: Vector2 = game.player.position
	return ApiServer.ok([pos.x, pos.y])


func _cmd_get_opponent_energy_ball_position(_args: Dictionary) -> Dictionary:
	var pos: Vector2 = game.energy_ball.position
	return ApiServer.ok([pos.x, pos.y])


func _cmd_request_heal(args: Dictionary) -> Dictionary:
	var heal_read := _read_float_arg(
		args, "heal_amount", "missing_heal_amount", "invalid_heal_amount"
	)
	if not heal_read["ok"]:
		return ApiServer.ok({"ok": false, "reason": heal_read["reason"]})

	var cost_read := _read_float_arg(
		args, "energy_cost", "missing_energy_cost", "invalid_energy_cost"
	)
	if not cost_read["ok"]:
		return ApiServer.ok({"ok": false, "reason": cost_read["reason"]})

	var service := _get_team_status_service()
	if service == null:
		return ApiServer.ok({"ok": false, "reason": "team_status_service_not_available"})

	# Heal is always my action, so it is charged to TEAM_ID.
	return ApiServer.ok(service.request_heal_api(TEAM_ID, heal_read["value"], cost_read["value"]))


#endregion


func _on_received_text(msg: String) -> void:
	# Deserialize, look the command up in this agent's table, and call it.
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
# gdlint: enable=max-returns
