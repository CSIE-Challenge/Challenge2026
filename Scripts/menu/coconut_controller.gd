extends CharacterBody2D

signal player_died
@export var auto_restart: bool = true

@export var move_speed: float = 300
var can_move: bool = true
var is_immutable = false

var skin_instance = null

var _debug: bool = true

@onready var body_sprite = $BodySprite
@onready var shadow_sprite = $ShadowSprite

@onready var cpu_particle = $CPUParticles2D


func _ready() -> void:
	# 1. 根據玩家目前裝備的 ID，動態組合出 .tres 的路徑
	var skin_path = "res://Assets/skins/" + PlayerData.equipped_skin + ".tres"
	var skin_data = load(skin_path)

	if skin_data and skin_data.skin_prefab:
		skin_instance = skin_data.skin_prefab.instantiate()
		add_child(skin_instance)

		# 3. 隱藏原本白色的預設圖片
		body_sprite.hide()
		# 你也可以選擇把陰影也隱藏：shadow_sprite.hide()

		if skin_instance.has_method("play_spawn"):
			can_move = false
			is_immutable = true

			await get_tree().create_timer(0.8).timeout
			await skin_instance.play_spawn()

			can_move = true
			is_immutable = false


func _physics_process(_delta: float) -> void:
	if can_move:
		var input_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
		move(input_dir, move_speed)


func move(dir: Vector2, speed: float):
	velocity = dir * speed
	move_and_slide()


func die():
	if is_immutable:
		return
	if not can_move:
		return
	can_move = false
	$CollisionShape2D.set_deferred("disabled", true)

	player_died.emit()

	# 如果皮膚有自帶的死亡動畫，就播放皮膚的
	if skin_instance and skin_instance.has_method("play_die"):
		# 如果皮膚有自帶特效，就隱藏預設的陰影
		shadow_sprite.hide()
		await skin_instance.play_die()
	else:
		# 備用防呆：如果你裝備的皮膚沒有 play_die，就用原本的粒子爆炸
		var die_tween: Tween = create_tween().set_parallel(true)
		die_tween.tween_property(body_sprite, "modulate:a", 0.0, 0.2)
		die_tween.tween_property(shadow_sprite, "modulate:a", 0.0, 0.2)
		cpu_particle.global_position = self.global_position
		cpu_particle.emitting = true
		await get_tree().create_timer(0.5).timeout

	if auto_restart:
		SceneTransition.transition_to_distortion("")
	queue_free()


func _on_damagefield_body_entered(body: Node2D) -> void:
	if body == self:
		die()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_J:
				if _debug:
					is_immutable = !is_immutable
