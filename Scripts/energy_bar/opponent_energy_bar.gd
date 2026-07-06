extends Node2D
# Opponent variant of the coconut tree energy bar.
# Differences from the player's own energy_bar.gd:
#   1. Every part is tinted a cool blue (`tint`) via modulate.
#   2. Coconuts never fly to the tree; coconut_count is derived directly from
#      energy, so there is no eaten_coconut / spawn_eaten_coconut path at all.
#   3. The tree grows top -> down: the scene root is flipped (scale.y = -1) and
#      anchored near the top of the screen, so the trunk/canopy hang downward.
const TRUNK_HEIGHT_PIXEL = 36

@export var trunk: PackedScene
@export var leaf: PackedScene
@export var coconut: PackedScene

@export var tint: Color = Color(0.5, 0.75, 1.25)
@export var energy: int = 0
@export var coconut_count: int = 0
@export var tree_height: float
@export var tree_root_position: Vector2 = Vector2(172, 130)
var trunks: Array[Node2D]
var leaves: Array[Node2D]
var coconuts: Array[Node2D]


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	global_position = tree_root_position
	trunks.clear()
	leaves.clear()
	coconuts.clear()
	leaf_grow()


func _process(_delta: float) -> void:
	# No orbs are collected for the opponent, so the number of coconuts is a
	# direct function of their reported energy instead of landed fruit.
	coconut_count = min(10, energy / 10)
	rearrange_trunks()
	rearrange_coconuts()
	rearrange_leaves()


func rearrange_trunks() -> void:
	var num_target = energy / 5
	while trunks.size() < num_target:
		tree_grow()
	while trunks.size() > num_target:
		tree_cut()
	var len = trunks.size()
	var scale: float = 0.18 + len * 0.02
	tree_height = 0
	for i in len:
		trunks[i].z_index = 0
		trunks[i].relocate(Vector2(0, tree_height))
		trunks[i].resize(scale)
		tree_height -= TRUNK_HEIGHT_PIXEL * scale
		scale *= 0.96


func tree_grow() -> void:
	var new_trunk = trunk.instantiate()
	add_child(new_trunk)
	new_trunk.modulate = tint
	var new_sprite = new_trunk.sprite
	new_sprite.play(str(randi_range(1, 5)))
	new_trunk.position = Vector2(0, 0)
	new_trunk.scale = Vector2(0, 0)
	trunks.push_front(new_trunk)


func tree_cut() -> void:
	if trunks.size() <= 0:
		return
	trunks.back().queue_free()
	trunks.pop_back()


func rearrange_leaves() -> void:
	var num_target = 7 - max(89 - energy, 0) / 30 * 2
	while leaves.size() < num_target:
		leaf_grow()
	while leaves.size() > num_target:
		leaf_cut()
	var len: int = leaves.size()
	for i in len:
		leaves[i].z_index = 2
		leaves[i].relocate(Vector2(0, tree_height))
		leaves[i].resize(sqrt(energy) * 0.036)
		leaves[i].set_direction((75 - 5 * len) * (i - len / 2))
		if i == len / 2:
			leaves[i].set_type(0)
		elif len == 7 and i % 2:
			leaves[i].set_type(1)
		else:
			leaves[i].set_type(2)


func leaf_grow() -> void:
	var new_leaf = leaf.instantiate()
	add_child(new_leaf)
	new_leaf.modulate = tint
	new_leaf.position = Vector2(0, tree_height)
	new_leaf.scale = Vector2(0, 0)
	leaves.push_back(new_leaf)


func leaf_cut() -> void:
	if leaves.size() <= 0:
		return
	leaves.back().queue_free()
	leaves.pop_back()


func rearrange_coconuts() -> void:
	while coconuts.size() < coconut_count:
		coconut_grow()
	while coconuts.size() > coconut_count:
		coconut_cut()
	var len = coconuts.size()
	for i in len:
		coconuts[i].z_index = 1
		coconuts[i].relocate(
			(
				Vector2(0, tree_height + sqrt(coconut_count) * 4)
				+ polar_vector(100 + 180 / len + 360 / len * i, sqrt(coconut_count) * 5)
			)
		)
		coconuts[i].resize(0.14 + energy * 0.001)


func coconut_grow() -> void:
	var new_coconut = coconut.instantiate()
	add_child(new_coconut)
	new_coconut.modulate = tint
	new_coconut.position = Vector2(0, tree_height)
	new_coconut.scale = Vector2(0, 0)
	coconuts.push_back(new_coconut)


func coconut_cut() -> void:
	if coconuts.size() <= 0:
		return
	coconuts.back().queue_free()
	coconuts.pop_back()


func polar_vector(deg: float, len: float) -> Vector2:
	var arc: float = deg * PI / 180
	return Vector2(len * cos(arc), len * sin(arc) * 0.6)
