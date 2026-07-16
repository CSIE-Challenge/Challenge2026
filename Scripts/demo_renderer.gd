## Renders ghost traps/players for the spectator demo client.
## Receives combined state from the server via NetworkManager's
## demo_state_received signal and updates two SubViewport stages.
class_name DemoRenderer
extends Node

const ProxyClass = preload("res://Scripts/demo_player_proxy.gd")

@export var stage_a: Node2D
@export var stage_b: Node2D

var _ghosts_a: Dictionary = {}
var _ghosts_b: Dictionary = {}
var _balls_a: Dictionary = {}  # energy ball ghosts: ball_id → Node
var _balls_b: Dictionary = {}
var _player_a: Node2D
var _player_b: Node2D
var _screens: Array = []


func _ready() -> void:
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
	if stage_a:
		_setup_walls(stage_a)
	if stage_b:
		_setup_walls(stage_b)

	_screens = [
		{
			"ghosts": _ghosts_a,
			"balls": _balls_a,
			"stage": stage_a,
			"player": _player_a,
			"prev_player": {},
			"proxy": null,
			"loaded_skin_id": "",
		},
		{
			"ghosts": _ghosts_b,
			"balls": _balls_b,
			"stage": stage_b,
			"player": _player_b,
			"prev_player": {},
			"proxy": null,
			"loaded_skin_id": "",
		},
	]


func _identify_as_demo(nm: Node) -> void:
	nm.rpc_id(1, "_server_identify_as_demo")


func _on_demo_state_received(combined: Dictionary) -> void:
	var screens: Array = combined.get("screens", [])
	for i in range(mini(screens.size(), 2)):
		_apply_screen(_screens[i], screens[i])


func _apply_screen(screen: Dictionary, screen_data: Dictionary) -> void:
	var stage: Node2D = screen["stage"]
	if not stage:
		return
	var ghosts: Dictionary = screen["ghosts"]

	# Apply player ghost
	var player_state: Dictionary = screen_data.get("player", {})
	_apply_player(screen, stage, player_state)

	# Apply trap ghosts
	var traps: Array = screen_data.get("traps", [])
	_update_ghosts(ghosts, stage, traps)

	# Apply energy ball ghosts
	var balls: Array = screen_data.get("energy_balls", [])
	_update_energy_balls(screen, stage, balls)


## Recursively disables game logic callbacks on [param node] and its children.
## Layer 1 defense: stops _process, _physics_process, Area2D monitoring, Timers.
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
		else:
			var ghost: Node = _instantiate_energy_ball()
			if ghost:
				ghost.is_demo = true
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
				stage.add_child(ghost)
				stage.add_child(proxy)
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


## Draws four thin wall rectangles on [param stage] to show the arena boundary.
## Arena is 500×500 centered at the stage origin, matching gameplay walls at ±250.
func _setup_walls(stage: Node2D) -> void:
	const WALL_COLOR := Color(0.7, 0.7, 0.7, 1.0)
	const ARENA_HALF := 250.0
	const THICKNESS := 4.0

	var walls_data := [
		{
			"name": "RightWall",
			"points":
			PackedVector2Array(
				[
					Vector2(ARENA_HALF - THICKNESS, -ARENA_HALF),
					Vector2(ARENA_HALF, -ARENA_HALF),
					Vector2(ARENA_HALF, ARENA_HALF),
					Vector2(ARENA_HALF - THICKNESS, ARENA_HALF),
				]
			),
		},
		{
			"name": "LeftWall",
			"points":
			PackedVector2Array(
				[
					Vector2(-ARENA_HALF, -ARENA_HALF),
					Vector2(-ARENA_HALF + THICKNESS, -ARENA_HALF),
					Vector2(-ARENA_HALF + THICKNESS, ARENA_HALF),
					Vector2(-ARENA_HALF, ARENA_HALF),
				]
			),
		},
		{
			"name": "UpWall",
			"points":
			PackedVector2Array(
				[
					Vector2(-ARENA_HALF, ARENA_HALF - THICKNESS),
					Vector2(ARENA_HALF, ARENA_HALF - THICKNESS),
					Vector2(ARENA_HALF, ARENA_HALF),
					Vector2(-ARENA_HALF, ARENA_HALF),
				]
			),
		},
		{
			"name": "DownWall",
			"points":
			PackedVector2Array(
				[
					Vector2(-ARENA_HALF, -ARENA_HALF),
					Vector2(ARENA_HALF, -ARENA_HALF),
					Vector2(ARENA_HALF, -ARENA_HALF + THICKNESS),
					Vector2(-ARENA_HALF, -ARENA_HALF + THICKNESS),
				]
			),
		},
	]

	for w in walls_data:
		var wall := Polygon2D.new()
		wall.name = w["name"]
		wall.polygon = w["points"]
		wall.color = WALL_COLOR
		stage.add_child(wall)
