extends Node2D

const AGENT_NAME := "Agent1"
const ECONOMY_TICK_SEC := 1.0

@export var player: CharacterBody2D
@export var camera: Camera2D
@export var health_label: Label
@export var energy_balls_label: Label
@export var energy_bar_label: Label
@export var opponent_energy_bar_label: Label
@export var result_screen: ResultScreen
var energy_increase_period := 1.0
var player_invincibility_time := 1.0
var energy_gain_per_ball := 10
var game_duration := 180.0

var energy_ball_count := 0
var energy_amount := 0
var total_energy_spent := 0
var rng := RandomNumberGenerator.new()
var player_invincible := false
var game_over := false
var survival_started_msec := 0
var trap_data = TrapData.new().data

@onready var player_invincibility_timer = $PlayerInvincibilityTimer
@onready var energy_increase_timer = $EnergyIncreaseTimer
@onready var game_duration_timer = $GameDurationTimer

@onready var team_status_service: TeamStatusService = $"../TeamStatusService"
@onready var trap_request_scheduler: TrapRequestScheduler = $"../TrapRequestScheduler"
@onready var agent_action_service: AgentActionService = $"../AgentActionService"


func _ready() -> void:
	_reload_from_game_data()

	survival_started_msec = Time.get_ticks_msec()
	Global.player_hit.connect(on_player_hit)
	Global.energyball_collected.connect(_on_energyball_collected)
	Global.game_manager = self
	player_invincibility_timer.timeout.connect(_on_player_invincibility_timer_timeout)
	NetworkManager.energy_changed.connect(_on_network_energy_changed)
	health_label.text = "Health: %d" % player.max_health
	energy_balls_label.text = "Energy Balls: %d" % energy_ball_count
	_update_energy_label()
	_update_opponent_energy_label(0, 0)
	_connect_team_status_signals()
	_connect_agent_action_signals()

	agent_action_service.setup_services(team_status_service, trap_request_scheduler)

	team_status_service.initialize()
	trap_request_scheduler.initialize()

	var economy_timer := Timer.new()
	economy_timer.wait_time = ECONOMY_TICK_SEC
	economy_timer.timeout.connect(_on_economy_tick)
	add_child(economy_timer)
	economy_timer.start()

	energy_increase_timer.wait_time = energy_increase_period

	game_duration_timer.wait_time = game_duration
	game_duration_timer.timeout.connect(_on_game_duration_timeout)
	game_duration_timer.start()

	player_invincible = false

	_begin_agents()

	#_show_test_result_after_delay()


func _reload_from_game_data() -> void:
	var game_data := GameData.new()
	energy_increase_period = game_data.get_float(
		"game_manager", "energy_increase_period", energy_increase_period
	)
	player_invincibility_time = game_data.get_float(
		"game_manager", "player_invincibility_time", player_invincibility_time
	)
	energy_gain_per_ball = game_data.get_int(
		"game_manager", "energy_gain_per_ball", energy_gain_per_ball
	)
	game_duration = game_data.get_float("game_manager", "game_duration", game_duration)


func _physics_process(delta: float) -> void:
	# Real-time per frame: spawn queued traps promptly + count down cooldowns.
	# Energy regen is NOT here -- it ticks discretely in _on_economy_tick().
	if game_over:
		return
	agent_action_service.update_cooldowns(delta)
	trap_request_scheduler.process_requests()


func _on_economy_tick() -> void:
	# Discrete integer energy regen (regen_rate * tick seconds) on a fixed clock.
	if game_over:
		return
	team_status_service.update_energy_regen(ECONOMY_TICK_SEC)


func _begin_agents() -> void:
	if "--console" in OS.get_cmdline_user_args():
		_spawn_agents("", "")
		return
	var bundle := _resolve_bundle_dir()
	if bundle == "" or not FileAccess.file_exists(bundle.path_join("runner.py")):
		_spawn_agents("", "")
		return
	var override := ApiServer.cmdline_value("--agent-file")
	var agent_file := override if override != "" else Global.agent_file
	_spawn_agents(bundle, agent_file)


func _resolve_bundle_dir() -> String:
	var override := ApiServer.cmdline_value("--agent-bundle")
	if override != "":
		return override
	if OS.has_feature("editor"):
		var root := ProjectSettings.globalize_path("res://")
		return root.path_join("agent/build").path_join(_bundle_platform_label())
	return OS.get_executable_path().get_base_dir().path_join("agent")


func _bundle_platform_label() -> String:
	var os_label := ""
	if OS.has_feature("windows"):
		os_label = "windows"
	elif OS.has_feature("linux"):
		os_label = "linux"
	elif OS.has_feature("macos"):
		os_label = "macos"
	else:
		return ""
	var arch := ""
	if OS.has_feature("arm64"):
		arch = "aarch64"
	elif OS.has_feature("x86_64"):
		arch = "x86_64"
	else:
		return ""
	return "%s-%s" % [os_label, arch]


func _spawn_agents(bundle: String, agent_file: String) -> void:
	var agent := GameAgent.new()
	agent.name = AGENT_NAME
	agent.game = self
	agent.bundle_dir = bundle
	agent.agent_file = agent_file
	add_child(agent)


func get_agent_action_service() -> AgentActionService:
	return agent_action_service


func get_team_status_service() -> TeamStatusService:
	return team_status_service


func _connect_team_status_signals() -> void:
	team_status_service.energy_changed.connect(_on_team_energy_changed)
	team_status_service.health_changed.connect(_on_team_health_changed)
	team_status_service.mode_changed.connect(_on_team_mode_changed)
	team_status_service.heal_used.connect(_on_team_heal_used)


func _connect_agent_action_signals() -> void:
	agent_action_service.trap_request_submitted.connect(_on_trap_request_submitted)
	agent_action_service.trap_request_rejected.connect(_on_trap_request_rejected)
	agent_action_service.trap_approved.connect(_on_trap_approved)
	agent_action_service.trap_rejected.connect(_on_trap_rejected)


func _on_team_energy_changed(current: float, max_energy: float) -> void:
	print("ENERGY_CHANGED energy=", current, "/", max_energy)


func _on_team_health_changed(current: float, max_health: float) -> void:
	print("HEALTH_CHANGED health=", current, "/", max_health)


func _on_team_mode_changed(old_mode: String, new_mode: String) -> void:
	print("MODE_CHANGED ", old_mode, " -> ", new_mode)


func _on_team_heal_used(heal_amount: float, energy_cost: float, heal_uses_left: int) -> void:
	print("HEAL_USED heal=", heal_amount, " cost=", energy_cost, " uses_left=", heal_uses_left)


func _on_trap_request_submitted(request: Dictionary) -> void:
	print("SUBMITTED request_id=", request["request_id"], " trap=", request["trap_id"])


func _on_trap_request_rejected(request: Dictionary, reason: String) -> void:
	print("SUBMIT_REJECTED trap=", request["trap_id"], " reason=", reason)


func _on_trap_approved(request: Dictionary, energy_cost: float) -> void:
	print(
		"APPROVED request_id=",
		request["request_id"],
		" trap=",
		request["trap_id"],
		" cost=",
		energy_cost
	)
	_spawn_trap_from_request(request)


func _on_trap_rejected(request: Dictionary, reason: String) -> void:
	print(
		"FINAL_REJECTED request_id=",
		request["request_id"],
		" trap=",
		request["trap_id"],
		" reason=",
		reason
	)


# gdlint: disable=max-returns
func _spawn_trap_from_request(request: Dictionary) -> void:
	var trap_id: String = request["trap_id"]
	var params: Dictionary = request["params"]

	match trap_id:
		"trap1-mine":
			if not params.has("position"):
				push_error("Missing position for mine trap")
				return
			Clamper.clamp_trap1(trap_data, params)
			Trap1Mine.initialize(params["position"])
		"trap2-electric_ring":
			if not (params.has("delay_time") and params.has("radius")):
				push_error("Missing delay_time or radius for electric_ring trap")
				return
			Clamper.clamp_trap2(trap_data, params)
			Trap2ElectricRing.initialize(params["delay_time"], params["radius"])
		"trap3-tracing_bullet":
			if not (params.has("position") and params.has("direction") and params.has("speed")):
				push_error("Missing position/direction/speed for tracing_bullet trap")
				return
			Clamper.clamp_trap3(trap_data, params)
			Trap3TracingBullet.initialize(params["position"], params["direction"], params["speed"])
		"trap4-conveyor":
			if not (params.has("position") and params.has("direction")):
				push_error("Missing position or direction for conveyor trap")
				return
			Clamper.clamp_trap4(trap_data, params)
			Trap4Conveyor.initialize(params["position"], params["direction"])
		"trap5-icefloor":
			if not params.has("position"):
				push_error("Missing position for icefloor trap")
				return
			Clamper.clamp_trap5(trap_data, params)
			Trap5IceFloor.initialize(params["position"])
		"trap6-scanline":
			if not params.has("direction"):
				push_error("Missing direction for scanline trap")
				return
			Clamper.clamp_trap6(trap_data, params)
			Trap6Scanline.initialize(params["direction"], params.get("speed", 5.0))
		"trap8-electric_arc":
			if not (params.has("start_position") and params.has("end_position")):
				push_error("Missing start_position or end_position for electric_arc trap")
				return
			Clamper.clamp_trap8(trap_data, params)
			Trap8ElectricArc.initialize(params["start_position"], params["end_position"])
		"trap9-mortar":
			if not (params.has("start_position") and params.has("end_position")):
				push_error("Missing start_position or end_position for mortar trap")
				return
			Clamper.clamp_trap9(trap_data, params)
			Trap9Mortar.initialize(
				params["start_position"], params["end_position"], params.get("air_time", 2.0)
			)
		"trap7-spreading_ripples":
			if not (params.has("position") and params.has("expand_rate")):
				push_error("Missing position or expand_rate for spreading_ripples trap")
				return
			Clamper.clamp_trap7(trap_data, params)
			Trap7SpreadingRipples.initialize(params["position"], params["expand_rate"])
		"trap10-shotgun":
			if not (
				params.has("position")
				and params.has("dir1")
				and params.has("dir2")
				and params.has("dir3")
			):
				push_error("Missing position or shoot directions for shotgun trap")
				return
			Clamper.clamp_trap10(trap_data, params)
			Trap10Shotgun.initialize(
				params["position"], params["dir1"], params["dir2"], params["dir3"]
			)
		_:
			push_error("Unsupported trap id in approved request: %s" % trap_id)
	# gdlint: enable=max-returns


#----------------------------------------------------------------------


func on_player_hit(damage: int) -> void:
	if game_over or player_invincible:
		return
	_player_become_invincible()
	print("玩家受到了", damage, "點傷害")
	camera.shake_cam()
	player.health = max(player.health - damage, 0.0)
	health_label.text = "Health: %d" % player.health
	if player.health <= 0.0:
		finish_game()


func _on_game_duration_timeout() -> void:
	finish_game()


func finish_game(authoritative_stats: Dictionary = {}) -> void:
	if game_over:
		return
	game_over = true
	get_tree().paused = true
	energy_increase_timer.stop()
	player_invincibility_timer.stop()
	game_duration_timer.stop()
	player.set_physics_process(false)
	player.collision_layer = 0
	player.collision_mask = 0

	var survival_time := (Time.get_ticks_msec() - survival_started_msec) / 1000.0
	(
		result_screen
		. show_results(
			{
				"energy_spent": authoritative_stats.get("energy_spent", total_energy_spent),
				"energy_balls": energy_ball_count,
				"jump_count": player.jump_count,
				"distance_traveled": player.distance_traveled,
				"survival_time": survival_time,
				"remaining_health": player.health,
				"trap_count": authoritative_stats.get("trap_count", 0),
			}
		)
	)


func _on_energyball_collected() -> void:
	energy_ball_count += 1
	energy_balls_label.text = "Energy Balls: %d" % energy_ball_count
	NetworkManager.request_add_energy(energy_gain_per_ball, "energy_ball")


func _player_become_invincible() -> void:
	player_invincible = true
	player.invincibility_toggle(true)
	player_invincibility_timer.start(player_invincibility_time)


func _on_player_invincibility_timer_timeout() -> void:
	player_invincible = false
	player.invincibility_toggle(false)


func _on_energy_increase_timer_timeout() -> void:
	NetworkManager.request_add_energy(1, "passive_regeneration")


func _on_network_energy_changed(peer_id: int, energy: int) -> void:
	if peer_id == multiplayer.get_unique_id():
		if energy < energy_amount:
			total_energy_spent += energy_amount - energy
		energy_amount = energy
		_update_energy_label()
		return

	_update_opponent_energy_label(peer_id, energy)


func _update_energy_label() -> void:
	energy_bar_label.text = "My Energy: %d" % energy_amount


func _update_opponent_energy_label(peer_id: int, energy: int) -> void:
	if peer_id == 0:
		opponent_energy_bar_label.text = "Opponent Energy: waiting"
		return
	opponent_energy_bar_label.text = "Opponent Energy (%d): %d" % [peer_id, energy]
