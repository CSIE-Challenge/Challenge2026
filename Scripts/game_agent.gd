class_name GameAgent
extends Node

const TRAP_PARAM_DEFINITIONS := {
	"mine": {"position": {"type": "vector2", "required": true}},
	"electric_arc":
	{
		"start_position": {"type": "vector2", "required": true},
		"end_position": {"type": "vector2", "required": true},
	},
	"mortar":
	{
		"start_position": {"type": "vector2", "required": true},
		"end_position": {"type": "vector2", "required": true},
		"air_time": {"type": "float", "required": false, "default": 2.0},
	},
	"shotgun":
	{
		"position": {"type": "vector2", "required": true},
		"dir1": {"type": "vector2", "required": true},
		"dir2": {"type": "vector2", "required": true},
		"dir3": {"type": "vector2", "required": true},
	},
	"electric_ring":
	{
		"radius": {"type": "float", "required": true},
		"delay_time": {"type": "float", "required": false, "default": 1.0},
	},
	"tracing_bullet":
	{
		"position": {"type": "vector2", "required": true},
		"direction": {"type": "vector2", "required": true},
		"speed": {"type": "float", "required": true},
	},
	"conveyor":
	{
		"position": {"type": "vector2", "required": true},
		"direction":
		{
			"type": "vector2",
			"required": false,
			"default": Vector2.UP,
		},
	},
	"scanline":
	{
		"direction": {"type": "vector2", "required": true},
		"speed": {"type": "float", "required": false, "default": 5.0},
	},
	"icefloor":
	{
		"position": {"type": "vector2", "required": true},
	},
	"spreading_ripples":
	{
		"position": {"type": "vector2", "required": true},
		"expand_rate": {"type": "float", "required": false, "default": 10.0},
	},
}

var game: Node2D
var _conn: WebSocketConnection
var _command_handlers: Dictionary[String, Callable] = {}
# gdlint: disable=max-returns


func _init() -> void:
	# keep serving requests even while the game is paused
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	_conn = ApiServer.register_connection()
	add_child(_conn)
	_conn.received_text.connect(_on_received_text)
	print("[API Server] agent '%s' token: %s" % [name, _conn.get_token()])

	_register_commands()


# Add one line per new API.
func _register_commands() -> void:
	# Runtime gameplay commands.
	register_command("ping", _cmd_ping)
	register_command("get_energy", _cmd_get_energy)
	register_command("request_trap", _cmd_request_trap)

	# Test-only commands (integration test helpers only).
	register_command("init_agent_services", _cmd_init_agent_services)
	register_command("process_trap_requests", _cmd_process_trap_requests)

	# Team/player status commands.
	register_command("get_team_status", _cmd_get_team_status)
	register_command("get_team_energy", _cmd_get_team_energy)
	register_command("get_team_health", _cmd_get_team_health)
	register_command("request_heal", _cmd_request_heal)


func register_command(cmd_name: String, handler: Callable) -> void:
	_command_handlers[cmd_name] = handler


# Helpers used by gameplay APIs.
func _get_team_status_service() -> TeamStatusService:
	if game == null:
		return null

	if not game.has_method("get_team_status_service"):
		return null

	return game.get_team_status_service()


# Test-only helpers used by integration-test utility APIs.
func _get_trap_request_scheduler() -> TrapRequestScheduler:
	if game == null:
		return null

	var scheduler = game.get_node_or_null("../TrapRequestScheduler")
	if scheduler == null:
		return null

	return scheduler


# Test-only helpers used by integration-test utility APIs.
func _read_team_id_array(args: Dictionary) -> Dictionary:
	if not args.has("team_ids"):
		return {"ok": false, "team_ids": []}

	var raw_team_ids: Variant = args["team_ids"]
	if typeof(raw_team_ids) != TYPE_ARRAY:
		return {"ok": false, "team_ids": []}

	var team_ids: Array[int] = []
	for value in raw_team_ids:
		if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
			return {"ok": false, "team_ids": []}

		var num: int = int(value)
		team_ids.append(num)

	if team_ids.is_empty():
		return {"ok": false, "team_ids": []}

	return {"ok": true, "team_ids": team_ids, "reason": ""}


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


func _read_team_id(args: Dictionary) -> Dictionary:
	if not args.has("team_id"):
		return {
			"ok": false,
			"team_id": -1,
			"reason": "missing_team_id",
		}

	var raw_team_id: Variant = args["team_id"]

	if not _is_number(raw_team_id):
		return {
			"ok": false,
			"team_id": -1,
			"reason": "invalid_team_id",
		}

	return {
		"ok": true,
		"team_id": int(raw_team_id),
		"reason": "",
	}


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


func _make_team_api_error(team_id: int, reason: String) -> Dictionary:
	return (
		ApiServer
		. ok(
			{
				"ok": false,
				"team_id": team_id,
				"reason": reason,
			}
		)
	)


#region Command handlers
#
# Runtime handlers.
func _cmd_ping(_args: Dictionary) -> Dictionary:
	return ApiServer.ok("pong")


func _cmd_get_energy(_args: Dictionary) -> Dictionary:
	return ApiServer.ok(game.energy_amount)


func _cmd_request_trap(args: Dictionary) -> Dictionary:
	if game == null:
		return (
			ApiServer
			. ok(
				{
					"ok": false,
					"stage": "rejected",
					"request_id": -1,
					"team_id": -1,
					"trap_id": "",
					"reason": "game_not_assigned",
				}
			)
		)

	if not game.has_method("get_agent_action_service"):
		return (
			ApiServer
			. ok(
				{
					"ok": false,
					"stage": "rejected",
					"request_id": -1,
					"team_id": -1,
					"trap_id": "",
					"reason": "agent_action_service_not_available",
				}
			)
		)

	var team_read := _read_team_id(args)
	if not team_read["ok"]:
		return _make_team_api_error(team_read["team_id"], team_read["reason"])

	var read_trap := _read_trap_id(args)
	if not read_trap["ok"]:
		return (
			ApiServer
			. ok(
				{
					"ok": false,
					"stage": "rejected",
					"request_id": -1,
					"team_id": team_read["team_id"],
					"trap_id": read_trap["trap_id"],
					"reason": read_trap["reason"],
				}
			)
		)

	var raw_params: Variant = args.get("params", {})
	if typeof(raw_params) != TYPE_DICTIONARY:
		return (
			ApiServer
			. ok(
				{
					"ok": false,
					"stage": "rejected",
					"request_id": -1,
					"team_id": team_read["team_id"],
					"trap_id": read_trap["trap_id"],
					"reason": "invalid_params_type",
				}
			)
		)

	var normalize_params := _normalize_trap_params(read_trap["trap_id"], raw_params)
	if not normalize_params["ok"]:
		return (
			ApiServer
			. ok(
				{
					"ok": false,
					"stage": "rejected",
					"request_id": -1,
					"team_id": team_read["team_id"],
					"trap_id": read_trap["trap_id"],
					"reason": normalize_params["reason"],
				}
			)
		)

	var agent_action_service: AgentActionService = game.get_agent_action_service()
	var result: Dictionary = agent_action_service.submit_trap_request_result(
		team_read["team_id"], read_trap["trap_id"], normalize_params["params"]
	)

	return ApiServer.ok(result)


# Test-only handlers (for deterministic API e2e setup/process behavior only).
func _cmd_init_agent_services(args: Dictionary) -> Dictionary:
	var scheduler := _get_trap_request_scheduler()
	if scheduler == null:
		return ApiServer.ok({"ok": false, "reason": "trap_request_scheduler_not_available"})

	var service := _get_team_status_service()
	if service == null:
		return ApiServer.ok({"ok": false, "reason": "team_status_service_not_available"})

	var team_ids_read := _read_team_id_array(args)
	if not team_ids_read["ok"]:
		return ApiServer.ok({"ok": false, "reason": "invalid_team_ids"})

	var team_ids: Array[int] = team_ids_read["team_ids"]
	service.initialize_teams(team_ids)
	scheduler.initialize_teams(team_ids)

	var initial_energy_read: Variant = args.get("initial_energy", 0.0)
	if _is_number(initial_energy_read):
		var initial_energy: float = float(initial_energy_read)
		for team_id in team_ids:
			service.add_energy(team_id, initial_energy)

	return ApiServer.ok({"ok": true, "team_ids": team_ids})


# Test-only handlers (for deterministic API e2e setup/process behavior only).
func _cmd_process_trap_requests(_args: Dictionary) -> Dictionary:
	var scheduler := _get_trap_request_scheduler()
	if scheduler == null:
		return ApiServer.ok({"ok": false, "reason": "trap_request_scheduler_not_available"})

	scheduler.process_requests()
	return ApiServer.ok({"ok": true})


func _cmd_get_team_status(args: Dictionary) -> Dictionary:
	var team_read := _read_team_id(args)
	if not team_read["ok"]:
		return _make_team_api_error(team_read["team_id"], team_read["reason"])

	var service := _get_team_status_service()
	if service == null:
		return _make_team_api_error(team_read["team_id"], "team_status_service_not_available")

	return ApiServer.ok(service.get_team_status_api(team_read["team_id"]))


func _cmd_get_team_energy(args: Dictionary) -> Dictionary:
	var team_read := _read_team_id(args)
	if not team_read["ok"]:
		return _make_team_api_error(team_read["team_id"], team_read["reason"])

	var service := _get_team_status_service()
	if service == null:
		return _make_team_api_error(team_read["team_id"], "team_status_service_not_available")

	return ApiServer.ok(service.get_team_energy_api(team_read["team_id"]))


func _cmd_get_team_health(args: Dictionary) -> Dictionary:
	var team_read := _read_team_id(args)
	if not team_read["ok"]:
		return _make_team_api_error(team_read["team_id"], team_read["reason"])

	var service := _get_team_status_service()
	if service == null:
		return _make_team_api_error(team_read["team_id"], "team_status_service_not_available")

	return ApiServer.ok(service.get_team_health_api(team_read["team_id"]))


func _cmd_request_heal(args: Dictionary) -> Dictionary:
	var team_read := _read_team_id(args)
	if not team_read["ok"]:
		return _make_team_api_error(team_read["team_id"], team_read["reason"])

	var heal_read := _read_float_arg(
		args, "heal_amount", "missing_heal_amount", "invalid_heal_amount"
	)
	if not heal_read["ok"]:
		return _make_team_api_error(team_read["team_id"], heal_read["reason"])

	var cost_read := _read_float_arg(
		args, "energy_cost", "missing_energy_cost", "invalid_energy_cost"
	)
	if not cost_read["ok"]:
		return _make_team_api_error(team_read["team_id"], cost_read["reason"])

	var service := _get_team_status_service()
	if service == null:
		return _make_team_api_error(team_read["team_id"], "team_status_service_not_available")

	return ApiServer.ok(
		service.request_heal_api(team_read["team_id"], heal_read["value"], cost_read["value"])
	)


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
