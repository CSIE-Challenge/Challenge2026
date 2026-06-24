class_name GameAgent
extends Node

var game: Node2D
var _conn: WebSocketConnection
var _command_handlers: Dictionary[String, Callable] = {}


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
	register_command("ping", _cmd_ping)
	register_command("get_energy", _cmd_get_energy)
	register_command("request_trap", _cmd_request_trap)

	register_command("get_team_status", _cmd_get_team_status)
	register_command("get_team_energy", _cmd_get_team_energy)
	register_command("get_team_health", _cmd_get_team_health)
	register_command("request_heal", _cmd_request_heal)


func register_command(cmd_name: String, handler: Callable) -> void:
	_command_handlers[cmd_name] = handler


#helpers
func _get_team_status_service() -> TeamStatusService:
	if game == null:
		return null

	if not game.has_method("get_team_status_service"):
		return null

	return game.get_team_status_service()


func _is_number(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT


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

	if not args.has("team_id"):
		return (
			ApiServer
			. ok(
				{
					"ok": false,
					"stage": "rejected",
					"request_id": -1,
					"team_id": -1,
					"trap_id": str(args.get("trap_id", "")),
					"reason": "missing_team_id",
				}
			)
		)

	if not args.has("trap_id"):
		return (
			ApiServer
			. ok(
				{
					"ok": false,
					"stage": "rejected",
					"request_id": -1,
					"team_id": int(args.get("team_id", -1)),
					"trap_id": "",
					"reason": "missing_trap_id",
				}
			)
		)

	var team_id := int(args["team_id"])
	var trap_id := str(args["trap_id"])

	var params: Dictionary = {}
	var raw_params: Variant = args.get("params", {})
	if typeof(raw_params) == TYPE_DICTIONARY:
		params = raw_params
	else:
		return (
			ApiServer
			. ok(
				{
					"ok": false,
					"stage": "rejected",
					"request_id": -1,
					"team_id": team_id,
					"trap_id": trap_id,
					"reason": "invalid_params",
				}
			)
		)

	var agent_action_service: AgentActionService = game.get_agent_action_service()
	var result: Dictionary = agent_action_service.submit_trap_request_result(
		team_id, trap_id, params
	)

	return ApiServer.ok(result)


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
