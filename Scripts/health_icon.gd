class_name HealthIcon
extends HBoxContainer

signal depleted

@export var player: CharacterBody2D
@export var life_capacity: int = 5
@export var unit_icon: Texture2D
@export var icon_size: Vector2 = Vector2(24, 24)
@export var inactive_alpha: float = 0.25

var _icons: Array[TextureRect] = []
var _remaining_lives: int = 0
var _last_player_health: int = 0


func _ready() -> void:
	if life_capacity < 0:
		life_capacity = 0
	if unit_icon == null:
		unit_icon = preload("res://Shapes/feather.svg")

	_ensure_icons()
	_remaining_lives = life_capacity
	if player != null:
		_last_player_health = int(player.health)
	_refresh_display()
	if not Global.player_hit.is_connected(_on_player_hit):
		Global.player_hit.connect(_on_player_hit)


func _ensure_icons() -> void:
	for icon in _icons:
		icon.queue_free()
	_icons = []

	for _i in range(life_capacity):
		var icon := TextureRect.new()
		icon.custom_minimum_size = icon_size
		icon.size = icon_size
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.texture = unit_icon
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		add_child(icon)
		_icons.append(icon)


func _on_player_hit(_damage: int) -> void:
	if life_capacity <= 0:
		return
	if player == null:
		return

	var current_health: int = int(player.health)
	if current_health >= _last_player_health:
		_last_player_health = current_health
		return
	_last_player_health = current_health

	_remaining_lives = max(_remaining_lives - 1, 0)
	_refresh_display()
	if _remaining_lives <= 0:
		depleted.emit()


func _exit_tree() -> void:
	if Global.player_hit.is_connected(_on_player_hit):
		Global.player_hit.disconnect(_on_player_hit)


func _refresh_display() -> void:
	if player == null:
		return
	if life_capacity <= 0:
		return
	var remaining: int = _remaining_lives

	for i in range(_icons.size()):
		var alpha: float = 1.0 if i < remaining else inactive_alpha
		_icons[i].modulate = Color(1, 1, 1, alpha)
