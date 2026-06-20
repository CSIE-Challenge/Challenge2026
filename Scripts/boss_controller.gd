extends Node2D

# 記錄 Boss 的初始待機位置，以便招式施展後歸位
var original_position: Vector2
var is_attacking: bool = false

# 取得椰子玩家的參照
@onready var player = $"../coconut"

# 取得 Boss 的碰撞與視覺節點
@onready var damage_field = $damagefield
@onready var sprites = $Sprites  # 注意：Sprites 在場景中必須是 Node2D 類型


func _ready() -> void:
	# 記錄初始位置
	original_position = position


func _unhandled_input(event: InputEvent) -> void:
	if is_attacking:
		return

	# 使用鍵盤的 1, 2, 3 鍵來測試不同的招式
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1:
				print("觸發招式一：衝鋒攻擊")
				charge_attack()
			KEY_2:
				print("觸發招式二：跳躍壓擊")
				jump_slam_attack()
			KEY_3:
				print("觸發招式三：橫向掃擊")
				sweep_attack()


# ==================== 招式一：衝鋒攻擊 (Charge Attack) ====================
# Boss 會先向後蓄力，然後快速衝向玩家當前的位置，最後回到原位。
func charge_attack() -> void:
	if not player:
		return
	is_attacking = true

	var target_pos = player.global_position
	var charge_dir = (target_pos - position).normalized()
	var tween = create_tween()

	# 1. 蓄力：向玩家相反方向退後，並將 Sprite 變紅表示警告
	(
		tween
		. tween_property(self, "position", position - charge_dir * 60.0, 0.4)
		. set_trans(Tween.TRANS_BACK)
		. set_ease(Tween.EASE_OUT)
	)
	tween.parallel().tween_property(sprites, "modulate", Color(2.0, 0.3, 0.3, 1.0), 0.4)

	# 2. 衝刺：極快地衝撞到目標位置，並恢復顏色
	tween.tween_property(self, "position", target_pos, 0.2).set_trans(Tween.TRANS_QUINT).set_ease(
		Tween.EASE_OUT
	)
	tween.parallel().tween_property(sprites, "modulate", Color.WHITE, 0.2)

	# 3. 撞擊停留
	tween.tween_interval(0.3)

	# 4. 歸位：平滑滑回原處
	(
		tween
		. tween_property(self, "position", original_position, 0.6)
		. set_trans(Tween.TRANS_SINE)
		. set_ease(Tween.EASE_IN_OUT)
	)

	await tween.finished
	is_attacking = false


# ==================== 招式二：跳躍壓擊 (Jump Slam Attack) ====================
# Boss 向上飛出螢幕，鎖定玩家的 X 軸，接著從天而降砸向玩家，隨後回到原位。
func jump_slam_attack() -> void:
	if not player:
		return
	is_attacking = true

	var tween = create_tween()

	# 1. 躍起：往上飛出螢幕外 (-600 像素)
	(
		tween
		. tween_property(self, "position", position + Vector2(0, -600), 0.4)
		. set_trans(Tween.TRANS_CUBIC)
		. set_ease(Tween.EASE_IN)
	)

	# 2. 鎖定：在空中隱形移動到玩家正上方，稍微停頓
	var target_x = player.position.x
	tween.tween_callback(func(): position = Vector2(target_x, original_position.y - 600))
	tween.tween_interval(0.25)

	# 3. 下砸：快速砸向地面的玩家位置
	var target_y = player.position.y
	(
		tween
		. tween_property(self, "position", Vector2(target_x, target_y), 0.25)
		. set_trans(Tween.TRANS_BOUNCE)
		. set_ease(Tween.EASE_OUT)
	)

	# 4. 震地停頓
	tween.tween_interval(0.4)

	# 5. 歸位：飛回原本待機位置
	(
		tween
		. tween_property(self, "position", original_position, 0.6)
		. set_trans(Tween.TRANS_SINE)
		. set_ease(Tween.EASE_IN_OUT)
	)

	await tween.finished
	is_attacking = false


# ==================== 招式三：橫向掃擊 (Sweep Attack) ====================
# Boss 移動到螢幕最左側外，然後平行橫掃到最右側外，最後回到原位。
func sweep_attack() -> void:
	is_attacking = true

	var tween = create_tween()
	# 假設戰鬥邊界大約在 -250 到 250 之間
	var left_start = Vector2(-350, original_position.y)
	var right_end = Vector2(350, original_position.y)

	# 1. 退場：移動到左側外準備
	tween.tween_property(self, "position", left_start, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(
		Tween.EASE_OUT
	)

	# 2. 橫掃：從左至右快速滑過螢幕
	tween.tween_property(self, "position", right_end, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(
		Tween.EASE_IN_OUT
	)

	# 3. 歸位：從右側游回原本中心點
	(
		tween
		. tween_property(self, "position", original_position, 0.5)
		. set_trans(Tween.TRANS_CUBIC)
		. set_ease(Tween.EASE_OUT)
	)

	await tween.finished
	is_attacking = false


func boss_appear_animation():
	pass
