extends Node2D
const TRUNK_HEIGHT_PIXEL = 40
@export var energy: int = 0
var trunks: Array[Node2D]
var leaves: Array[Node2D]
var coconuts: Array[Node2D]
var tree_height: float
@onready var trunk: Resource = load("res://Scenes/energy_bar/trunk.tscn")
@onready var leaf: Resource = load("res://Scenes/energy_bar/leaf.tscn")
@onready var coconut: Resource = load("res://Scenes/energy_bar/coconut.tscn")


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	trunks.clear()
	leaves.clear()
	coconuts.clear()
	leaf_grow()


func _process(delta: float) -> void:
	rearrange_trunks()
	rearrange_coconuts()
	rearrange_leaves()
	use(delta)


func _input(event: InputEvent):
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_P:
				energy = min(energy + 5, 100)
			KEY_L:
				energy = max(energy - 5, 0)


func rearrange_trunks() -> void:
	var num_target = energy / 5
	while trunks.size() < num_target:
		tree_grow()
	while trunks.size() > num_target:
		tree_cut()
	var len = trunks.size()
	var scale: float = 0.2 + len * 0.02
	tree_height = 0
	for i in len:
		trunks[i].z_index = 0
		trunks[i].relocate(Vector2(0, tree_height))
		trunks[i].resize(scale)
		tree_height -= TRUNK_HEIGHT_PIXEL * scale
		scale *= 0.96


func tree_grow() -> void:
	var new_trunk = trunk.instantiate()
	var new_sprite = new_trunk.get_node("AnimationSprite")
	new_sprite.play(str(randi_range(1, 5)))
	new_trunk.resize(0)
	trunks.push_front(new_trunk)
	add_child(new_trunk)


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
		leaves[i].resize(sqrt(energy) * 0.04)
		leaves[i].set_direction((75 - 5 * len) * (i - len / 2))
		if i == len / 2:
			leaves[i].set_type(0)
		elif len == 7 and i % 2:
			leaves[i].set_type(1)
		else:
			leaves[i].set_type(2)


func leaf_grow() -> void:
	var new_leaf = leaf.instantiate()
	leaves.push_back(new_leaf)
	add_child(new_leaf)


func leaf_cut() -> void:
	if leaves.size() <= 0:
		return
	leaves.back().queue_free()
	leaves.pop_back()


func rearrange_coconuts() -> void:
	var num_target = energy / 20
	while coconuts.size() < num_target:
		coconut_grow()
	while coconuts.size() > num_target:
		coconut_cut()
	var len = coconuts.size()
	for i in len:
		coconuts[i].z_index = 1
		coconuts[i].relocate(
			(
				Vector2(0, tree_height + energy * 0.3)
				+ polar_vector(100 + 180 / len + 360 / len * i, energy * 0.2)
			)
		)
		coconuts[i].resize(0.1 + energy * 0.0025)


func coconut_grow() -> void:
	var new_coconut = coconut.instantiate()
	coconuts.push_back(new_coconut)
	add_child(new_coconut)


func coconut_cut() -> void:
	if coconuts.size() <= 0:
		return
	coconuts.back().queue_free()
	coconuts.pop_back()


func polar_vector(deg: float, len: float) -> Vector2:
	var arc: float = deg * PI / 180
	return Vector2(len * cos(arc), len * sin(arc) * 0.7)


func use(delta: float) -> float:
	return delta
