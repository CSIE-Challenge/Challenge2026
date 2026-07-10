class_name HealthIcon
extends HBoxContainer

signal depleted

@export var life_capacity: int = 5
@export var unit_icon: Texture2D
@export var icon_size: Vector2 = Vector2(24, 24)
@export var inactive_alpha: float = 0.25
@export var reversed: bool = 0

var _icons: Array[TextureRect] = []
var _current_health: int = 0
var _max_health: int = 0


func _ready() -> void:
	_set_max_health_safely(life_capacity)

	if has_node("/root/PlayerData"):
		var player_data_node = get_node("/root/PlayerData")
		var skin_path = "res://Assets/skins/" + player_data_node.equipped_skin + ".tres"
		if ResourceLoader.exists(skin_path):
			var skin_data = load(skin_path) as SkinData
			if skin_data and skin_data.health_icon_texture:
				unit_icon = skin_data.health_icon_texture

	if unit_icon == null:
		unit_icon = preload("res://Shapes/feather.svg")

	_ensure_icons()
	set_health(_max_health)


func set_max_health(max_hp: int) -> void:
	_set_max_health_safely(max_hp)
	_ensure_icons()
	if _current_health > _max_health:
		_current_health = _max_health
	_refresh_display()


func set_health(current_health: int) -> void:
	var new_health: int = clampi(current_health, 0, _max_health)
	if new_health == _current_health:
		return
	_current_health = new_health
	_refresh_display()
	if _current_health <= 0:
		depleted.emit()


func _ensure_icons() -> void:
	for icon in _icons:
		icon.queue_free()
	_icons = []

	for _i in range(_max_health):
		var icon: TextureRect = TextureRect.new()
		icon.custom_minimum_size = icon_size
		icon.size = icon_size
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.texture = unit_icon
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		add_child(icon)
		_icons.append(icon)


func _refresh_display() -> void:
	if _max_health <= 0:
		return

	var remaining: int = _current_health
	for i in range(_icons.size()):
		var not_transparent: bool = (
			i < remaining if not reversed else i >= life_capacity - remaining
		)
		var alpha: float = 1.0 if not_transparent else inactive_alpha
		_icons[i].modulate = Color(1, 1, 1, alpha)


func _set_max_health_safely(value: int) -> void:
	_max_health = max(0, int(value))
	life_capacity = _max_health


func set_icon_size(new_size: Vector2) -> void:
	icon_size = new_size
	for icon in _icons:
		icon.custom_minimum_size = new_size
	reset_size()
	queue_sort()
