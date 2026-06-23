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


func register_command(cmd_name: String, handler: Callable) -> void:
	_command_handlers[cmd_name] = handler


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
