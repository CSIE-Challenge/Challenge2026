extends CharacterBody2D
@export var move_speed:float
@export var jump_velocity:float
@export var jump_gravity:float
@export var jump_fall_multiplier:float
@onready var body_sprite = $BodySprite

var isjumping := false
var current_jump_velocity:float
var current_sprite_y:float

func _ready() -> void:
	pass

func _physics_process(delta: float) -> void:
	var input_dir = Input.get_vector("move_left","move_right","move_up","move_down")
	move(input_dir,move_speed)
	if Input.is_action_just_pressed("jump"):
		jump()
		GlobalSignal.player_hit.emit(67) #只是測試與示範player_hit怎麼呼叫
	if isjumping:
		jump_process(delta)

func move(dir:Vector2,speed:float):
	velocity = dir * speed
	move_and_slide()
	
func jump():
	if isjumping:
		return
	isjumping = true
	current_jump_velocity = jump_velocity
	current_sprite_y = 0
	jump_invisiblility_toggle(true)

func jump_process(delta:float):
	if current_jump_velocity < 0:
		current_jump_velocity -= jump_gravity*jump_fall_multiplier*delta
	else:
		current_jump_velocity -= jump_gravity*delta
	current_sprite_y += current_jump_velocity*delta
	if current_sprite_y <= 0:
		isjumping = false
		body_sprite.position.y = 0
		jump_invisiblility_toggle(false)
	else:
		body_sprite.position.y = -current_sprite_y

func jump_invisiblility_toggle(on:bool):
	if on:
		collision_layer=0
	else:
		collision_layer=1
