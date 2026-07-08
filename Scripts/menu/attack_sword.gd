extends CollisionShape2D

# 基礎縮放大小
var base_scale: Vector2 = Vector2(0.1, 0.1)
var base_sprite_scale: Vector2 = Vector2(0.1, 0.1)
# 拉伸強度參數 (數值越大，飛得越快時拉得越長)
var stretch_factor: float = 0.0015

@onready var sprite = $Sprite2D


func _ready() -> void:
	pass


func init(start_pos: Vector2, target_pos: Vector2, speed: float, wait_time: float) -> void:
	base_scale = scale  # 立即記錄編輯器中的 CollisionShape2D 縮放大小
	if has_node("Sprite2D"):
		sprite = get_node("Sprite2D")
		base_sprite_scale = sprite.scale

	position = start_pos

	# 計算飛行方向與角度
	var move_dir = (target_pos - start_pos).normalized()
	# 讓飛劍 Sprite 朝向移動方向 (假設您的 Sprite 原生朝右。如果朝上，請在此加上 PI/2)
	rotation = move_dir.angle()

	# 計算飛行總時間 (距離 / 速度)
	var distance = start_pos.distance_to(target_pos)
	var fly_duration = distance / speed

	var tween = create_tween()

	# 1. 預備階段：在起點等待，從 scale = 0 放大出現
	scale = Vector2.ZERO
	tween.tween_property(self, "scale", Vector2.ONE, 0.15)

	# 如果 wait_time 足夠長，就在起點停留
	if wait_time > 0.15:
		tween.tween_interval(wait_time - 0.15)

	# 2. 飛行階段：開始起飛
	tween.tween_callback(_apply_stretch.bind(speed))

	# 移動到對角目標點
	tween.tween_property(self, "position", target_pos, fly_duration)

	# 3. 結束階段：恢復正常大小並縮小淡出，隨後銷毀自身
	tween.tween_callback(
		func():
			if sprite:
				sprite.scale = base_sprite_scale
	)
	tween.tween_property(self, "scale", Vector2.ZERO, 0.1)
	tween.tween_callback(queue_free)


func _apply_stretch(speed: float):
	# 飛行開始時，套用速度拉伸效果 (拉長 X，壓扁 Y，維持視覺體積)
	if sprite:
		var stretch = 1.0 + speed * stretch_factor
		sprite.scale.x = base_sprite_scale.x * stretch
		sprite.scale.y = base_sprite_scale.y / (1.0 + (stretch - 1.0) * 0.5)
