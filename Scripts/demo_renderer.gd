## Renders ghost traps/players for the spectator demo client.
## Receives combined state from the server via NetworkManager's
## demo_state_received signal and updates two SubViewport stages.
class_name DemoRenderer
extends Node

@export var stage_a: Node2D
@export var stage_b: Node2D

var _ghosts_a: Dictionary = {}
var _ghosts_b: Dictionary = {}


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
	if stage_a:
		_setup_walls(stage_a)
	if stage_b:
		_setup_walls(stage_b)


func _identify_as_demo(nm: Node) -> void:
	nm.rpc_id(1, "_server_identify_as_demo")


func _on_demo_state_received(combined: Dictionary) -> void:
	var screens: Array = combined.get("screens", [])
	for i in range(mini(screens.size(), 2)):
		var screen_data: Dictionary = screens[i]
		var ghosts: Dictionary = _ghosts_a if i == 0 else _ghosts_b
		var stage: Node2D = stage_a if i == 0 else stage_b
		_apply_screen(ghosts, stage, screen_data)


func _apply_screen(ghosts: Dictionary, stage: Node2D, screen_data: Dictionary) -> void:
	var traps: Array = screen_data.get("traps", [])
	_update_ghosts(ghosts, stage, traps)


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


## Draws four thin wall rectangles on [param stage] to show the arena boundary.
## Arena is 500×500 centered at the stage origin, matching gameplay walls at ±250.
func _setup_walls(stage: Node2D) -> void:
	const WALL_COLOR := Color(0.45, 0.45, 0.45, 0.9)
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
