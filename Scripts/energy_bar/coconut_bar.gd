extends Node2D
const TRUNK_HEIGHT_PIXEL = 36

@export var trunk: PackedScene
@export var leaf: PackedScene
@export var coconut: PackedScene
@export var eaten_coconut: PackedScene

@export var coconut_count: int = 0
@export var tree_height: float
@export var tree_root_position: Vector2 = Vector2(980, 512)
var trunks: Array[Node2D]
var leaves: Array[Node2D]
var coconuts: Array[Node2D]
var eaten_coconuts: Array[Node2D]


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	global_position = tree_root_position
	trunks.clear()
	leaves.clear()
	coconuts.clear()
	eaten_coconuts.clear()
	leaf_grow()


func _process(delta: float) -> void:
	rearrange_trunks()
	rearrange_coconuts()
	rearrange_leaves()
	rearrange_eaten_coconuts()
	use(delta)


func rearrange_trunks() -> void:
	var num_target = coconut_count / 5
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
	var num_target = 7 - max(89 - coconut_count, 0) / 30 * 2
	while leaves.size() < num_target:
		leaf_grow()
	while leaves.size() > num_target:
		leaf_cut()
	var len: int = leaves.size()
	for i in len:
		leaves[i].z_index = 2
		leaves[i].relocate(Vector2(0, tree_height))
		leaves[i].resize(sqrt(coconut_count) * 0.036)
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
	new_leaf.position = Vector2(0, tree_height)
	new_leaf.scale = Vector2(0, 0)
	leaves.push_back(new_leaf)


func leaf_cut() -> void:
	if leaves.size() <= 0:
		return
	leaves.back().queue_free()
	leaves.pop_back()


func rearrange_coconuts() -> void:
	var num_target = coconut_count / 20
	while coconuts.size() < num_target:
		coconut_grow()
	while coconuts.size() > num_target:
		coconut_cut()
	var len = coconuts.size()
	for i in len:
		coconuts[i].z_index = 1
		coconuts[i].relocate(
			(
				Vector2(0, tree_height + sqrt(coconut_count))
				+ polar_vector(100 + 180 / len + 360 / len * i, sqrt(coconut_count))
			)
		)
		coconuts[i].resize(0.14 + coconut_count * 0.001)


func coconut_grow() -> void:
	var new_coconut = coconut.instantiate()
	add_child(new_coconut)
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
	return Vector2(len * cos(arc), len * sin(arc) * 0.5)


func spawn_eaten_coconut(pos: Vector2) -> void:
	print("coconut eaten")
	var new_eaten_coconut = eaten_coconut.instantiate()
	add_child(new_eaten_coconut)
	new_eaten_coconut.global_position = pos
	eaten_coconuts.push_back(new_eaten_coconut)


func rearrange_eaten_coconuts() -> void:
	var len = eaten_coconuts.size()
	var target_position = tree_root_position + Vector2(0, tree_height)
	for i in len:
		var j = len - i - 1
		if (eaten_coconuts[j].global_position - target_position).length() < 3.0:
			eaten_coconuts[j].delete()
			eaten_coconuts.remove_at(j)
			continue
		eaten_coconuts[j].set_target_position(target_position)


func use(delta: float) -> float:
	return delta
