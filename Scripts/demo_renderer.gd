## Renders ghost traps/players for the spectator demo client.
## Receives combined state from the server via NetworkManager's
## demo_state_received signal and updates two SubViewport stages.
class_name DemoRenderer
extends Node

const ProxyClass = preload("res://Scripts/demo_player_proxy.gd")
const FALLBACK_HEALTH_TEXTURE = preload("res://Shapes/feather.svg")

@export var stage_a: Node2D
@export var stage_b: Node2D
@export var time_label: Label
@export var phase_label: Label
@export var pregame_countdown: Label
@export var screen_a_energy: Node2D
@export var screen_a_health: Node2D
@export var screen_b_energy: Node2D
@export var screen_b_health: Node2D
@export var stage_layer: CanvasLayer
@export var high_stage_a: Node2D
@export var high_stage_b: Node2D
@export var camera_a: Camera2D
@export var camera_b: Camera2D

var _ghosts_a: Dictionary = {}
var _ghosts_b: Dictionary = {}
var _balls_a: Dictionary = {}  # energy ball ghosts: ball_id → Node
var _balls_b: Dictionary = {}
var _player_a: Node2D
var _player_b: Node2D
var _screens: Array = []
var _countdown_triggered: bool = false
var _phase_duration: Array = []
var _max_phase: int = 0


func _ready() -> void:
	var game_data := GameData.new()
	_phase_duration = game_data.data.get("game_manager", {}).get("phase_duration", [])
	_max_phase = game_data.data.get("game_manager", {}).get("max_phase", _phase_duration.size())

	# Resize window for dual 960×540 viewports side by side
	DisplayServer.window_set_size(Vector2i(1920, 540))

	var nm := get_node_or_null("/root/NetworkManager")
	if not nm:
		return

	# Connect state receiver
	if nm.has_signal("demo_state_received"):
		nm.demo_state_received.connect(_on_demo_state_received)

	# Identify as demo to server — wait for connection to be ready
	if nm.has_signal("connection_succeeded"):
		nm.connection_succeeded.connect(_identify_as_demo.bind(nm))

	# Draw arena walls on both stages
	# Use get_node as fallback — exported NodePath may fail across SubViewport boundaries
	if not stage_a:
		stage_a = get_node_or_null("../ScreenA/SubViewport/StageA") as Node2D
	if not stage_b:
		stage_b = get_node_or_null("../ScreenB/SubViewport/StageB") as Node2D
	if not high_stage_a:
		high_stage_a = get_node_or_null("../HigherThanPlayerA/Stage") as Node2D
	if not high_stage_b:
		high_stage_b = get_node_or_null("../HigherThanPlayerB/Stage") as Node2D

	_screens = [
		{
			"ghosts": _ghosts_a,
			"balls": _balls_a,
			"stage": stage_a,
			"high_stage": high_stage_a,
			"player": _player_a,
			"prev_player": {},
			"proxy": null,
			"loaded_skin_id": "",
			"energy_label": screen_a_energy,
			"energy_value": 0,
			"health_root": screen_a_health,
			"health_icons": [],
			"health_value": -1,
			"camera": camera_a,
		},
		{
			"ghosts": _ghosts_b,
			"balls": _balls_b,
			"stage": stage_b,
			"high_stage": high_stage_b,
			"player": _player_b,
			"prev_player": {},
			"proxy": null,
			"loaded_skin_id": "",
			"energy_label": screen_b_energy,
			"energy_value": 0,
			"health_root": screen_b_health,
			"health_icons": [],
			"health_value": -1,
			"camera": camera_b,
		},
	]
	var creator_name := ApiServer.cmdline_value("--creator-name")
	var joiner_name := ApiServer.cmdline_value("--joiner-name")
	var name_label_a = get_node_or_null("../HUD/NameLabelA")
	if name_label_a and creator_name != "":
		name_label_a.text = creator_name
	var name_label_b = get_node_or_null("../HUD/NameLabelB")
	if name_label_b and joiner_name != "":
		name_label_b.text = joiner_name


func _identify_as_demo(nm: Node) -> void:
	nm.rpc_id(1, "_server_identify_as_demo")


func _on_demo_state_received(combined: Dictionary) -> void:
	var elapsed: float = combined.get("elapsed_time", 0.0)
	_update_time_display(elapsed)
	_update_phase_display(combined.get("current_phase", 0))

	if not _countdown_triggered and elapsed < 0.0:
		_countdown_triggered = true
		if pregame_countdown and pregame_countdown.has_method("play_countdown"):
			pregame_countdown.play_countdown()

	var screens: Array = combined.get("screens", [])
	for i in range(mini(screens.size(), 2)):
		_apply_screen(_screens[i], screens[i])


func _apply_screen(screen: Dictionary, screen_data: Dictionary) -> void:
	var stage: Node2D = screen["stage"]
	if not stage:
		return
	var ghosts: Dictionary = screen["ghosts"]

	Global.high_stage = screen.get("high_stage", stage)

	var player_state: Dictionary = screen_data.get("player", {})
	_apply_player(screen, stage, player_state)

	# Apply trap ghosts
	var traps: Array = screen_data.get("traps", [])
	_update_ghosts(ghosts, stage, traps)

	# Apply energy ball ghosts
	var balls: Array = screen_data.get("energy_balls", [])
	_update_energy_balls(screen, stage, balls)

	# Apply energy and health HUD (server-authoritative values)
	var energy: int = screen_data.get("energy", 0)
	var health: int = screen_data.get("health", 0)
	var skin_id: String = player_state.get("skin_id", "")
	var max_health: int = 5
	var nm := get_node_or_null("/root/NetworkManager")
	if nm:
		max_health = nm.get_max_health()
	var max_energy: int = 35
	if nm:
		max_energy = nm.max_energy
	var player_max_energy: int = screen_data.get("max_energy_cap", 0)
	if player_max_energy > max_energy:
		max_energy = player_max_energy
	_update_energy_hud(screen, energy, max_energy)
	_update_health_hud(screen, skin_id, max_health)
	_refresh_health_display(screen, health)


## Recursively disables game logic callbacks on [param node] and its children.
## Layer 1 defense: stops _process, _physics_process, Area2D monitoring, Timers.
func _update_time_display(elapsed: float) -> void:
	if not time_label:
		return
	if elapsed < 0.0:
		return
	var minute := int(floor(elapsed)) / 60
	var second := int(floor(elapsed)) % 60
	time_label.text = "%02d:%02d" % [minute, second]


func _update_phase_display(phase: int) -> void:
	if not phase_label:
		return
	phase_label.text = "Phase %d" % phase


func _compute_phase(time: float) -> int:
	for i in range(_max_phase):
		if time >= _phase_duration[i]:
			time -= _phase_duration[i]
		else:
			return i
	return _max_phase


func _suppress_game_logic(node: Node) -> void:
	node.set_process(false)
	node.set_physics_process(false)
	for child in node.get_children():
		_suppress_game_logic(child)
		if child is Area2D:
			(child as Area2D).monitoring = false
		elif child is Timer:
			(child as Timer).stop()


## Maps a trap type string to its scene file path.
## Uses the trap<N>-<name> convention matching TrapData JSON keys.
func _scene_path_for_type(type: String) -> String:
	const SCENE_PATHS := {
		"trap1-mine": "res://Scenes/traps/trap1-mine.tscn",
		"trap2-electric_ring": "res://Scenes/traps/trap2-electric_ring.tscn",
		"trap3-tracing_bullet": "res://Scenes/traps/trap3-tracing_bullet.tscn",
		"trap4-conveyor": "res://Scenes/traps/trap4-conveyor.tscn",
		"trap5-icefloor": "res://Scenes/traps/trap5-icefloor.tscn",
		"trap6-scanline": "res://Scenes/traps/trap6-scanline.tscn",
		"trap7-spreading_ripples": "res://Scenes/traps/trap7-spreading_ripples.tscn",
		"trap8-electric_arc": "res://Scenes/traps/trap8-electric_arc.tscn",
		"trap9-mortar": "res://Scenes/traps/trap9-mortar.tscn",
		"trap10-shotgun": "res://Scenes/traps/trap10-shotgun.tscn",
	}
	return SCENE_PATHS.get(type, "")


## Instantiates a ghost node from the trap's .tscn file.
func _instantiate_ghost(type: String) -> Node:
	var path := _scene_path_for_type(type)
	if path.is_empty():
		push_warning("[DemoRenderer] Unknown trap type: %s" % type)
		return null
	return load(path).instantiate()


## Diff loop: creates, updates, or removes ghost nodes based on [param traps_array].
## [param ghosts] maps trap_id → ghost Node.
func _update_ghosts(ghosts: Dictionary, stage: Node2D, traps_array: Array) -> void:
	var active_ids: Array = []

	for trap_data in traps_array:
		var trap_id = trap_data.get("id", -1)
		if trap_id == -1:
			continue
		active_ids.append(trap_id)

		if ghosts.has(trap_id):
			# Existing ghost — update
			var ghost: Node = ghosts[trap_id]
			if is_instance_valid(ghost) and ghost.has_method("apply_demo_state"):
				ghost.apply_demo_state(trap_data)
		else:
			# New ghost — instantiate, suppress, apply
			var trap_type: String = trap_data.get("type", "")
			var ghost: Node = _instantiate_ghost(trap_type)
			if ghost:
				ghost.is_demo = true
				stage.add_child(ghost)
				_suppress_game_logic(ghost)
				if ghost.has_method("apply_demo_state"):
					ghost.apply_demo_state(trap_data)
				ghosts[trap_id] = ghost

	# Remove stale ghosts (IDs no longer present)
	for trap_id in ghosts.keys():
		if not active_ids.has(trap_id):
			var old_ghost: Node = ghosts[trap_id]
			if is_instance_valid(old_ghost):
				old_ghost.queue_free()
			ghosts.erase(trap_id)


## Diff loop for energy ball ghosts: instantiates the real energy_ball.tscn,
## suppresses game logic, and positions from state data.
func _update_energy_balls(screen: Dictionary, stage: Node2D, balls_array: Array) -> void:
	var balls: Dictionary = screen["balls"]
	var active_ids: Array = []

	for ball_data in balls_array:
		var ball_id = ball_data.get("id", -1)
		if ball_id == -1:
			continue

		var collected: bool = ball_data.get("collected", false)
		var combo: int = ball_data.get("combo", 0)
		if collected:
			if balls.has(ball_id):
				var old: Node = balls[ball_id]
				if is_instance_valid(old):
					old.queue_free()
				balls.erase(ball_id)
			continue

		active_ids.append(ball_id)
		var pos: Vector2 = ball_data.get("position", Vector2.ZERO)

		if balls.has(ball_id):
			var ghost: Node2D = balls[ball_id]
			if is_instance_valid(ghost):
				ghost.global_position = pos
				ghost.visible = true
				ghost.now_combo = combo
		else:
			var ghost: Node = _instantiate_energy_ball()
			if ghost:
				ghost.is_demo = true
				ghost.z_index = Util.LAYERS["EnergyBall"]
				stage.add_child(ghost)
				_suppress_energy_ball(ghost)
				ghost.global_position = pos
				ghost.visible = true
				balls[ball_id] = ghost

	# Remove stale
	for ball_id in balls.keys():
		if not active_ids.has(ball_id):
			var old: Node = balls[ball_id]
			if is_instance_valid(old):
				old.queue_free()
			balls.erase(ball_id)


## Lightweight suppression for energy ball ghosts: keeps _physics_process
## for coconut animation, but disables collision and _process.
func _suppress_energy_ball(node: Node) -> void:
	node.set_process(false)
	# Keep set_physics_process(true) — drives coconut rotation + outline color
	if node is Area2D:
		(node as Area2D).monitoring = false


## Instantiates the energy_ball.tscn scene for demo rendering.
func _instantiate_energy_ball() -> Node:
	return load("res://Scenes/energy_ball.tscn").instantiate()


## Creates or updates the player ghost on [param stage] from [param player_state].
## Instantiates the player's skin prefab (same as gameplay) with full animations,
## falling back to a blue circle sprite if skin loading fails.
func _apply_player(screen: Dictionary, stage: Node2D, player_state: Dictionary) -> void:
	if player_state.is_empty():
		return

	var skin_id: String = player_state.get("skin_id", "")
	var ghost: Node2D = screen["player"]
	var prev: Dictionary = screen.get("prev_player", {})

	# Determine desired skin class: non-empty skin_id → BaseSkin, otherwise fallback
	var desired_is_skin := not skin_id.is_empty()
	var current_is_skin := ghost and ghost is BaseSkin
	var skin_changed: bool = (
		desired_is_skin and (not current_is_skin or skin_id != screen.get("loaded_skin_id", ""))
	)

	# Destroy old ghost if type or skin_id changed
	if ghost and (skin_changed or (not desired_is_skin and current_is_skin)):
		if is_instance_valid(ghost):
			ghost.queue_free()
		ghost = null
		screen["player"] = null
		screen["proxy"] = null
		screen["loaded_skin_id"] = ""
		prev = {}

	# Create ghost if needed
	if not is_instance_valid(ghost):
		if desired_is_skin:
			ghost = _load_skin(skin_id)
			if ghost:
				ghost.z_index = Util.LAYERS["Player/BodySprite"]
				var proxy: Node2D = ProxyClass.new()
				proxy.name = "PlayerProxy"
				ghost.set_meta("player", proxy)
				var hs: Node2D = screen.get("high_stage", stage)
				hs.add_child(ghost)
				hs.add_child(proxy)
				screen["proxy"] = proxy
				screen["loaded_skin_id"] = skin_id
				if ghost.has_method("play_spawn"):
					ghost.play_spawn()
			else:
				ghost = _create_player_ghost(stage)
		else:
			ghost = _create_player_ghost(stage)
		screen["player"] = ghost

	# Update position
	var pos: Vector2 = player_state.get("position", Vector2.ZERO)
	var sprite_y: float = player_state.get("sprite_y", 0.0)
	ghost.global_position = Vector2(pos.x, pos.y - sprite_y)

	# Update velocity for skin _process() animations
	var vel: Vector2 = player_state.get("velocity", Vector2.ZERO)
	if ghost is BaseSkin:
		var proxy = screen.get("proxy")
		if is_instance_valid(proxy):
			proxy.velocity = vel

	# Update invincibility flicker
	var alpha: float = player_state.get("modulate_alpha", 1.0)
	ghost.modulate.a = alpha

	# Detect animation transitions
	if ghost is BaseSkin:
		# Jump → call play_jump()
		var was_jumping: bool = prev.get("is_jumping", false)
		var is_jumping: bool = player_state.get("is_jumping", false)
		if is_jumping and not was_jumping and ghost.has_method("play_jump"):
			ghost.play_jump()

		# Land → call play_land()
		if not is_jumping and was_jumping and ghost.has_method("play_land"):
			ghost.play_land()

		# Death → call play_die() (only once, when health drops to 0)
		var prev_health: int = prev.get("health", 0)
		var health: int = player_state.get("health", 0)
		if health <= 0 and prev_health > 0 and ghost.has_method("play_die"):
			ghost.play_die()

		# Ball collected → call play_eat_ball()
		var prev_balls: int = prev.get("energy_ball_count", 0)
		var balls: int = player_state.get("energy_ball_count", 0)
		if balls > prev_balls and ghost.has_method("play_eat_ball"):
			for _i in range(balls - prev_balls):
				ghost.play_eat_ball()

	# Store state for next comparison
	screen["prev_player"] = {
		"is_jumping": player_state.get("is_jumping", false),
		"health": player_state.get("health", 0),
		"energy_ball_count": player_state.get("energy_ball_count", 0),
	}


## Updates the energy HUD for [param screen] from [param energy] and [param max_energy].
func _update_energy_hud(screen: Dictionary, energy: int, max_energy: int) -> void:
	var label = screen["energy_label"]
	if label == null:
		return
	label._update_energy(energy)
	label._update_max_energy(max_energy)


## Rebuilds the health icon row for [param screen] based on [param skin_id]
## and [param max_health]. Only recreates icons when skin or max_health changes.
func _update_health_hud(screen: Dictionary, skin_id: String, max_health: int) -> void:
	var health_root: Node2D = screen.get("health_root")
	if not health_root:
		return

	var need_rebuild: bool = (
		skin_id != screen.get("loaded_skin_id", "") or health_root.get_child_count() != max_health
	)
	if not need_rebuild:
		if screen["health_icons"].is_empty():
			for child in health_root.get_children():
				if child is TextureRect:
					screen["health_icons"].append(child)
		return

	# Clear old icons
	for icon in screen["health_icons"]:
		if is_instance_valid(icon):
			icon.queue_free()
	screen["health_icons"] = []

	# Load skin-specific health textures
	var icon_a: Texture2D = FALLBACK_HEALTH_TEXTURE
	var icon_b: Texture2D = FALLBACK_HEALTH_TEXTURE
	if not skin_id.is_empty():
		var skin_path := "res://Assets/skins/" + skin_id + ".tres"
		if ResourceLoader.exists(skin_path):
			var skin_data = load(skin_path) as SkinData
			if skin_data and skin_data.health_icon_texture:
				icon_a = skin_data.health_icon_texture
				icon_b = (
					skin_data.health_icon_texture2 if skin_data.health_icon_texture2 else icon_a
				)

	# Create icon row
	var icon_size := Vector2(30, 30)
	var spacing := 36.0
	var total_width := max_health * spacing - (spacing - icon_size.x)
	var start_x := -total_width / 2.0

	for i in range(max_health):
		var tex_rect := TextureRect.new()
		tex_rect.custom_minimum_size = icon_size
		tex_rect.size = icon_size
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_rect.texture = icon_a if i % 2 == 0 else icon_b
		tex_rect.position = Vector2(start_x + i * spacing, -icon_size.y / 2.0)
		health_root.add_child(tex_rect)
		screen["health_icons"].append(tex_rect)


## Sets the alpha of each health icon: bright for alive, dim for lost.
func _refresh_health_display(screen: Dictionary, health: int) -> void:
	var prev_health: int = screen.get("health_value", -1)
	screen["health_value"] = health

	var icons: Array = screen.get("health_icons", [])
	for i in range(icons.size()):
		var icon: TextureRect = icons[i]
		if is_instance_valid(icon):
			icon.modulate = Color(1, 1, 1, 1.0 if i < health else 0.25)

	if prev_health != -1 and health < prev_health:
		var cam: Camera2D = screen.get("camera")
		if cam and cam.has_method("shake_cam"):
			cam.shake_cam()


## Loads a skin instance from its skin_id, or returns null on failure.
func _load_skin(skin_id: String) -> Node2D:
	if skin_id.is_empty():
		return null
	var skin_path := "res://Assets/skins/" + skin_id + ".tres"
	if not ResourceLoader.exists(skin_path):
		push_warning("[DemoRenderer] Skin resource not found: %s" % skin_path)
		return null
	var skin_data = load(skin_path) as SkinData
	if not skin_data or not skin_data.skin_prefab:
		push_warning("[DemoRenderer] Invalid SkinData or missing prefab: %s" % skin_id)
		return null
	return skin_data.skin_prefab.instantiate()


## Creates a fallback blue circle player ghost when skin loading fails.
func _create_player_ghost(stage: Node2D) -> Node2D:
	var ghost := Sprite2D.new()
	ghost.name = "PlayerGhost"
	ghost.texture = preload("res://Shapes/Circle.svg")
	ghost.scale = Vector2(0.2, 0.2)
	ghost.z_index = Util.LAYERS["Player/BodySprite"]
	ghost.modulate = Color(0.2, 0.6, 1.0, 1.0)
	stage.add_child(ghost)
	return ghost
