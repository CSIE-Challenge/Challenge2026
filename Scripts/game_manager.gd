extends Node2D

@export var player: CharacterBody2D
@export var camera: Camera2D
@export var health_label: Label
@export var energy_bar_label: Label
@export var coconut_bar: Node2D
@export var opponent_energy_bar_label: Label
@export var time_label: Label
@export var result_screen: ResultScreen
@export var pause_menu: PauseMenu
@export var phase_label: Label
@export var health_icon: HealthIcon
@export var walls: Array[Sprite2D]
@export var energy_label: Node2D

var game_data: Dictionary = GameData.new().data
var energy_increase_period = game_data["game_manager"]["energy_increase_period"]
var player_invincibility_time = game_data["game_manager"]["player_invincibility_time"]
var game_duration = game_data["game_manager"]["game_duration"]
var max_health = int(game_data["player"]["max_health"])
var max_phase = game_data["game_manager"]["max_phase"]
var phase_duration = game_data["game_manager"]["phase_duration"]
var max_energy = game_data["game_manager"]["max_energy"]

var energy_ball_count := 0
var energy_amount := 0
var total_energy_spent := 0
var rng := RandomNumberGenerator.new()
var player_invincible := false
var game_over := false
var survival_started_msec := 0
var trap_data = TrapData.new().data
var current_phase := 0
var _health_icon_ready := false
var _is_paused := false
var _is_shutting_down := false

@onready var energy_ball: Node2D = $"../SubViewport/Stage/EnergyBall"
@onready var player_invincibility_timer = $PlayerInvincibilityTimer
@onready var energy_increase_timer = $EnergyIncreaseTimer
@onready var game_duration_timer = $GameDurationTimer
@onready var phase_timer = $PhaseTimer
@onready var trap_request_scheduler: TrapRequestScheduler = $"../TrapRequestScheduler"
@onready var agent_action_service: AgentActionService = $"../AgentActionService"
@onready var pregame_countdown: Label = $"../SubViewport/PregameCountdown"
@onready var skin_prefab = $"/StageLayer/AdvancedSkinPrefab"


func _ready() -> void:
	if player != null:
		player.max_health = max_health
		player.health = max_health

	survival_started_msec = Time.get_ticks_msec()
	if multiplayer.is_server():
		NetworkManager.cancel_ready_timeout()
	else:
		NetworkManager.cancel_ready_timeout.rpc_id(1)
	Global.player_hit.connect(on_player_hit)
	Global.energyball_collected.connect(_on_energyball_collected)
	Global.game_manager = self
	player_invincibility_timer.timeout.connect(_on_player_invincibility_timer_timeout)
	NetworkManager.energy_changed.connect(_on_network_energy_changed)
	NetworkManager.health_changed.connect(_on_network_health_changed)
	_setup_health_ui()
	_update_energy_label()
	_update_opponent_energy_label(0, 0)
	_update_max_energy(0)
	_connect_agent_action_signals()
	_connect_pause_menu()

	agent_action_service.setup_services(self, trap_request_scheduler)
	trap_request_scheduler.initialize()

	energy_increase_timer.wait_time = energy_increase_period[current_phase]

	game_duration_timer.wait_time = game_duration
	game_duration_timer.timeout.connect(_on_game_duration_timeout)
	game_duration_timer.start()
	_update_time_label()

	phase_timer.timeout.connect(_on_phase_timeout)
	phase_timer.start(phase_duration[0])

	player.get_node("ShadowSprite").z_index = Util.LAYERS["Player/ShadowSprite"]
	player.get_node("BodySprite").z_index = Util.LAYERS["Player/BodySprite"]
	player.get_node("WalkParticle").z_index = Util.LAYERS["Player/WalkParticle"]
	player.get_node("JumpParticle").z_index = Util.LAYERS["Player/JumpParticle"]
	player.get_node("LandParticle").z_index = Util.LAYERS["Player/LandParticle"]
	player.reparent_land_particles()

	energy_ball.z_index = Util.LAYERS["EnergyBall"]
	$"../SubViewport/Stage/Walls".z_index = Util.LAYERS["Walls"]
	coconut_bar.z_index = Util.LAYERS["CoconutBar/CoconutBar"]

	player.hide()
	player.skin_instance.hide()
	energy_label.process_mode = Node.PROCESS_MODE_ALWAYS
	for w in walls:
		w.process_mode = Node.PROCESS_MODE_ALWAYS
	_wall_animation()
	energy_ball.hide()

	get_tree().paused = true
	await get_tree().create_timer(0.3).timeout
	pregame_countdown.play_countdown()

	await get_tree().create_timer(3.0).timeout
	get_tree().paused = false
	for w in walls:
		w.process_mode = Node.PROCESS_MODE_PAUSABLE
	energy_label.process_mode = Node.PROCESS_MODE_PAUSABLE

	Audio.set_phase_bgm(0)
	player_invincible = false
	player.show()
	player.skin_instance.show()
	_begin_agents()

	energy_ball._respawn_energy_ball()
	await get_tree().create_timer(0.2).timeout
	energy_ball.show()
	await get_tree().create_timer(1.0).timeout
	pregame_countdown.hide()


func _exit_tree() -> void:
	_shutdown_gameplay_for_scene_change()


func _physics_process(delta: float) -> void:
	# Real-time per frame: spawn queued traps promptly + count down cooldowns.
	# Energy regen is NOT here -- it ticks discretely via EnergyIncreaseTimer.
	if game_over:
		return
	_update_time_label()
	agent_action_service.update_cooldowns(delta)
	trap_request_scheduler.process_requests()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		_handle_pause_toggle()


func _handle_pause_toggle() -> void:
	if game_over:
		return
	if pause_menu == null:
		return

	if _is_paused:
		_resume_gameplay()
	else:
		_pause_gameplay()


#region Agent
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
	# Launcher layout: the exe sits in GameBuilds/ with the bundle beside it.
	return OS.get_executable_path().get_base_dir().get_base_dir().path_join("agent")


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


#endregion


#region API
func get_agent_action_service() -> AgentActionService:
	return agent_action_service


func get_opponent_player_velocity() -> Vector2:
	var current_player: CharacterBody2D = player
	if current_player == null:
		return Vector2.ZERO
	return current_player.velocity


func get_remaining_time() -> float:
	if game_duration_timer == null:
		return 0.0
	return maxf(0.0, game_duration_timer.time_left)


func get_opponent_combo() -> int:
	if energy_ball == null:
		return 0
	return energy_ball.get_combo()


func get_phase() -> int:
	return current_phase


func _connect_agent_action_signals() -> void:
	agent_action_service.trap_approved.connect(_on_trap_approved)


func _on_trap_approved(request: Dictionary, _energy_cost: float) -> void:
	_spawn_trap_from_request(request)


# gdlint: disable=max-returns
func _spawn_trap_from_request(request: Dictionary) -> void:
	var trap_id: String = request["trap_id"]
	var params: Dictionary = request["params"]

	Audio.play_sfx(Audio.SFX.SET_TRAP)

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


#endregion


func _wall_animation() -> void:
	for w in walls:
		w.material.set_shader_parameter("offset", randf_range(0, 10))
		var tween = create_tween()
		tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
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
	NetworkManager.request_damage_health(damage)
	Audio.play_sfx(Audio.SFX.TAKE_DAMAGE)


func _on_game_duration_timeout() -> void:
	finish_game()


func _on_phase_timeout() -> void:
	current_phase = min(current_phase + 1, max_phase)
	energy_ball.advance_phase()
	phase_timer.start(phase_duration[current_phase])
	phase_label.text = "%d" % current_phase
	_update_max_energy()


func _update_max_energy(play_audio: bool = true) -> void:
	var max = max_energy[min(current_phase, max_energy.size() - 1)]
	energy_label._update_max_energy(max)
	NetworkManager.update_max_energy(max)
	if play_audio:
		Audio.set_phase_bgm(current_phase)


#region Control
func finish_game(authoritative_stats: Dictionary = {}) -> void:
	if game_over:
		return
	_close_pause_overlay_for_finish()
	game_over = true
	get_tree().paused = true
	energy_increase_timer.stop()
	player_invincibility_timer.stop()
	game_duration_timer.stop()
	phase_timer.stop()
	if trap_request_scheduler != null:
		trap_request_scheduler.clear()
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


func _connect_pause_menu() -> void:
	if pause_menu == null:
		return
	pause_menu.resume_requested.connect(_on_pause_resume_requested)
	pause_menu.restart_requested.connect(_on_pause_restart_requested)
	pause_menu.main_menu_requested.connect(_on_pause_main_menu_requested)
	pause_menu.exit_requested.connect(_on_pause_exit_requested)
	pause_menu.close()


func _on_pause_resume_requested() -> void:
	_resume_gameplay()


func _on_pause_restart_requested() -> void:
	_shutdown_gameplay_for_scene_change()
	SceneTransition.transition_to_wave("res://Scenes/gameplay.tscn")


func _on_pause_main_menu_requested() -> void:
	_shutdown_gameplay_for_scene_change()
	SceneTransition.transition_to("res://Scenes/menu.tscn")


func _on_pause_exit_requested() -> void:
	_shutdown_gameplay_for_scene_change()
	get_tree().quit()


func _pause_gameplay() -> void:
	if get_tree() == null:
		return
	if game_over or _is_paused:
		return

	_is_paused = true
	if pause_menu != null:
		pause_menu.open()
	get_tree().paused = true
	Audio.pause_bgm()


func _resume_gameplay() -> void:
	if get_tree() == null:
		return
	if not _is_paused:
		return

	_is_paused = false
	get_tree().paused = false
	Audio.resume_bgm()
	if pause_menu != null:
		pause_menu.close()


func _close_pause_overlay_for_finish() -> void:
	if _is_paused:
		_resume_gameplay()
	elif pause_menu != null:
		pause_menu.close()


func _shutdown_gameplay_for_scene_change() -> void:
	if _is_shutting_down:
		return
	_is_shutting_down = true

	if get_tree() != null and get_tree().paused:
		get_tree().paused = false

	_is_paused = false
	game_over = true

	if pause_menu != null:
		pause_menu.close()

	_stop_gameplay_timers()
	_clear_gameplay_backend_state()
	_disconnect_runtime_signals()
	_shutdown_running_agents()
	NetworkManager.stop_network()

	if player != null:
		player.set_physics_process(false)


func _stop_gameplay_timers() -> void:
	energy_increase_timer.stop()
	player_invincibility_timer.stop()
	game_duration_timer.stop()
	phase_timer.stop()


func _clear_gameplay_backend_state() -> void:
	if agent_action_service != null:
		agent_action_service.reset_for_scene_exit()
	if trap_request_scheduler != null:
		trap_request_scheduler.clear()


func _disconnect_runtime_signals() -> void:
	if Global.player_hit.is_connected(on_player_hit):
		Global.player_hit.disconnect(on_player_hit)
	if Global.energyball_collected.is_connected(_on_energyball_collected):
		Global.energyball_collected.disconnect(_on_energyball_collected)

	if NetworkManager.energy_changed.is_connected(_on_network_energy_changed):
		NetworkManager.energy_changed.disconnect(_on_network_energy_changed)
	if NetworkManager.health_changed.is_connected(_on_network_health_changed):
		NetworkManager.health_changed.disconnect(_on_network_health_changed)


func _shutdown_running_agents() -> void:
	for child in get_children():
		if child is GameAgent:
			child.queue_free()


#endregion


func _on_energyball_collected(energy_gain: int) -> void:
	energy_ball_count += 1
	coconut_bar._update_coconut_count(energy_ball_count)
	energy_balls_label.text = "Energy Balls: %d" % energy_ball_count
	NetworkManager.request_add_energy(energy_gain)


func _player_become_invincible() -> void:
	player_invincible = true
	player.invincibility_toggle(true)
	player_invincibility_timer.start(player_invincibility_time)


func _on_player_invincibility_timer_timeout() -> void:
	player_invincible = false
	player.invincibility_toggle(false)


func _on_energy_increase_timer_timeout() -> void:
	NetworkManager.request_add_energy(1)
	energy_increase_timer.start(energy_increase_period[current_phase])


func _on_network_energy_changed(peer_id: int, energy: int) -> void:
	if peer_id == multiplayer.get_unique_id():
		if energy < energy_amount:
			total_energy_spent += energy_amount - energy
		energy_amount = energy
		_update_energy_label()

	_update_opponent_energy_label(peer_id, energy)


func _on_network_health_changed(peer_id: int, health: int) -> void:
	if peer_id == multiplayer.get_unique_id():
		_update_health_display(clampi(health, 0, max_health))
		if player == null:
			return
		if player.health <= 0:
			await player.die()
			finish_game()
		return

	_update_opponent_energy_label(peer_id, NetworkManager.get_energy(peer_id))


#region UI
func _update_time_label() -> void:
	# Show whole seconds still remaining (counts down game_duration -> 0).
	# The label uses right alignment, so digits stay anchored at the right edge
	# (e.g. "180", "99", "1" all keep the ones digit in the same spot).
	var seconds_left := int(ceil(game_duration_timer.time_left))
	var minute = seconds_left / 60
	var second = seconds_left % 60
	time_label.text = "%02d:%02d" % [minute, second]


func _update_energy_label() -> void:
	energy_bar_label.text = "My Energy: %d" % energy_amount
	energy_label._update_energy(energy_amount)


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
	_update_health_display(clampi(start_health, 0, max_health))


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
#endregion
