extends Node2D

@export var player: CharacterBody2D
@export var camera: Camera2D
@export var health_label: Label
@export var energy_balls_label: Label
@export var energy_bar_label: Label
@export var energy_bar: Node2D
@export var opponent_energy_bar_label: Label
@export var result_screen: ResultScreen
@export var level_label: Label
@export var health_icon: HealthIcon
@export var walls: Array[Sprite2D]
var energy_increase_period: Array
var player_invincibility_time := 1.0
var game_duration := 180.0
var max_health := 5

var energy_ball_count := 0
var energy_amount := 0
var total_energy_spent := 0
var rng := RandomNumberGenerator.new()
var player_invincible := false
var game_over := false
var survival_started_msec := 0
var trap_data = TrapData.new().data
var current_level := 0
var max_level := 4
var level_duration: Array
var _health_icon_ready := false
var _last_local_network_health := 0
var _has_local_health_network_seed := false

@onready var energy_ball: Node2D = $"../SubViewport/Stage/EnergyBall"
@onready var player_invincibility_timer = $PlayerInvincibilityTimer
@onready var energy_increase_timer = $EnergyIncreaseTimer
@onready var game_duration_timer = $GameDurationTimer
@onready var level_up_timer = $LevelUpTimer
@onready var trap_request_scheduler: TrapRequestScheduler = $"../TrapRequestScheduler"
@onready var agent_action_service: AgentActionService = $"../AgentActionService"


func _ready() -> void:
	_reload_from_game_data()
	if player != null:
		player.max_health = max_health
		player.health = max_health

	survival_started_msec = Time.get_ticks_msec()
	Global.player_hit.connect(on_player_hit)
	Global.energyball_collected.connect(_on_energyball_collected)
	Global.game_manager = self
	player_invincibility_timer.timeout.connect(_on_player_invincibility_timer_timeout)
	NetworkManager.energy_changed.connect(_on_network_energy_changed)
	NetworkManager.health_changed.connect(_on_network_health_changed)
	_setup_health_ui()
	energy_balls_label.text = "Energy Balls: %d" % energy_ball_count
	_update_energy_label()
	_update_opponent_energy_label(0, 0)
	_connect_agent_action_signals()

	agent_action_service.setup_services(self, trap_request_scheduler)
	trap_request_scheduler.initialize()

	energy_increase_timer.wait_time = energy_increase_period[current_level]

	game_duration_timer.wait_time = game_duration
	game_duration_timer.timeout.connect(_on_game_duration_timeout)
	game_duration_timer.start()

	player_invincible = false

	_begin_agents()

	level_up_timer.timeout.connect(_on_level_up_timeout)
	level_up_timer.start(level_duration[0])

	_wall_animation()

	Audio.set_bgm(Audio.BGM.GAMEPLAY)

	#_show_test_result_after_delay()


func _reload_from_game_data() -> void:
	var game_data := GameData.new()
	energy_increase_period = game_data.data["game_manager"]["energy_increase_period"]
	player_invincibility_time = game_data.data["game_manager"]["player_invincibility_time"]
	game_duration = game_data.data["game_manager"]["game_duration"]
	max_health = int(game_data.data["player"]["max_health"])
	max_level = game_data.data["game_manager"]["max_level"]
	level_duration = game_data.data["game_manager"]["level_duration"]


func _physics_process(delta: float) -> void:
	# Real-time per frame: spawn queued traps promptly + count down cooldowns.
	# Energy regen is NOT here -- it ticks discretely via EnergyIncreaseTimer.
	if game_over:
		return
	agent_action_service.update_cooldowns(delta)
	trap_request_scheduler.process_requests()


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
	agent.game = self
	agent.bundle_dir = bundle
	agent.agent_file = agent_file
	add_child(agent)


func get_agent_action_service() -> AgentActionService:
	return agent_action_service


func _connect_agent_action_signals() -> void:
	agent_action_service.trap_approved.connect(_on_trap_approved)
	agent_action_service.trap_rejected.connect(_on_trap_rejected)
	agent_action_service.heal_used.connect(_on_heal_used)


func _on_heal_used(_heal_amount: int, _energy_cost: int, _heal_uses_left: int) -> void:
	_update_health_display(player.health)


func _on_trap_approved(request: Dictionary, _energy_cost: float) -> void:
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
func _wall_animation() -> void:
	for w in walls:
		w.material.set_shader_parameter("offset", randf_range(0, 10))
		var tween = create_tween()
		(
			tween
			. tween_method(
				func(value): w.material.set_shader_parameter("draw", value), -0.2, 1.0, 1.5
			)
			. set_trans(Tween.TRANS_SINE)
			. set_ease(Tween.EASE_IN_OUT)
		)


func on_player_hit(damage: int) -> void:
	if game_over or player_invincible:
		return
	_player_become_invincible()
	camera.shake_cam()
	NetworkManager.request_damage_health(damage, "player_hit")


func _on_game_duration_timeout() -> void:
	finish_game()


func _on_level_up_timeout() -> void:
	current_level = min(current_level + 1, max_level)
	energy_ball.level_up()
	level_up_timer.start(level_duration[current_level])
	level_label.text = "Level: %d" % current_level


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


func _on_energyball_collected(energy_gain: int) -> void:
	energy_ball_count += 1
	energy_balls_label.text = "Energy Balls: %d" % energy_ball_count
	NetworkManager.request_add_energy(energy_gain, "energy_ball")


func _player_become_invincible() -> void:
	player_invincible = true
	player.invincibility_toggle(true)
	player_invincibility_timer.start(player_invincibility_time)


func _on_player_invincibility_timer_timeout() -> void:
	player_invincible = false
	player.invincibility_toggle(false)


func _on_energy_increase_timer_timeout() -> void:
	NetworkManager.request_add_energy(1, "passive_regeneration")
	energy_increase_timer.start(energy_increase_period[current_level])


func _on_network_energy_changed(peer_id: int, energy: int) -> void:
	if peer_id == multiplayer.get_unique_id():
		if energy < energy_amount:
			total_energy_spent += energy_amount - energy
		energy_amount = energy
		_update_energy_label()

	_update_opponent_energy_label(peer_id, energy)


func _on_network_health_changed(peer_id: int, health: int) -> void:
	if peer_id == multiplayer.get_unique_id():
		var normalized_health: int = _normalize_network_health(health)
		_update_health_display(normalized_health)
		if player == null:
			return
		if player.health <= 0:
			finish_game()
		return

	_update_opponent_energy_label(peer_id, NetworkManager.get_energy(peer_id))


func _update_energy_label() -> void:
	energy_bar_label.text = "My Energy: %d" % energy_amount
	energy_bar.energy = energy_amount


func _update_opponent_energy_label(peer_id: int, energy: int) -> void:
	if peer_id == 0:
		opponent_energy_bar_label.text = "Opponent: waiting"
		return
	opponent_energy_bar_label.text = (
		"Opponent (%d) Energy: %d Health: %d"
		% [
			peer_id,
			energy,
			NetworkManager.get_health(peer_id),
		]
	)


func _setup_health_ui() -> void:
	var start_health: int = max_health
	if player != null:
		start_health = int(player.health)
	if health_icon != null:
		health_icon.set_max_health(max_health)
		_health_icon_ready = true
	# Seed the normalization baseline with raw network health so the first
	# subsequent network update maps to exactly one local health step.
	var local_peer_id: int = multiplayer.get_unique_id()
	_last_local_network_health = NetworkManager.get_health(local_peer_id)
	_has_local_health_network_seed = true
	_update_health_display(clampi(start_health, 0, max_health))


# TEMPORARY: keeps gameplay stable while trap damage/heal values are still
# being tuned. Network APIs remain untouched; we normalize all network health
# updates to +/-1 deltas for local display/logic.
func _normalize_network_health(raw_health: int) -> int:
	if player == null:
		return clampi(raw_health, 0, max_health)
	if not _has_local_health_network_seed:
		_last_local_network_health = raw_health
		_has_local_health_network_seed = true
		return clampi(player.health, 0, max_health)

	var target_health: int = int(player.health)
	if raw_health > _last_local_network_health:
		target_health += 1
	elif raw_health < _last_local_network_health:
		target_health -= 1
	_last_local_network_health = raw_health
	return clampi(target_health, 0, max_health)


func _update_health_display(health: int) -> void:
	if player == null:
		return
	var current_health: int = clampi(health, 0, max_health)
	player.health = current_health
	health_label.text = "Health: %d" % current_health
	if health_icon != null:
		if not _health_icon_ready:
			health_icon.set_max_health(max_health)
			_health_icon_ready = true
		health_icon.set_health(current_health)
