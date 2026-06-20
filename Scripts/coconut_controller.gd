extends CharacterBody2D

@export var move_speed: float = 300
var can_move: bool = true
@onready var body_sprite = $BodySprite
@onready var shadow_sprite = $ShadowSprite

@onready var cpu_particle = $CPUParticles2D


func _ready() -> void:
	pass


func _physics_process(_delta: float) -> void:
	if can_move:
		var input_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
		move(input_dir, move_speed)


func move(dir: Vector2, speed: float):
	velocity = dir * speed
	move_and_slide()


func die():
	if not can_move:  # 防止重複觸發死亡
		return
	can_move = false
	$CollisionShape2D.disabled = true

	var die_tween: Tween = create_tween().set_parallel(true)
	die_tween.tween_property(body_sprite, "modulate:a", 0.0, 0.2)
	die_tween.tween_property(shadow_sprite, "modulate:a", 0.0, 0.2)

	cpu_particle.global_position = self.global_position
	cpu_particle.emitting = true

	await get_tree().create_timer(cpu_particle.lifetime).timeout
	queue_free()


func _on_damagefield_body_entered(body: Node2D) -> void:
	if body == self:
		die()
