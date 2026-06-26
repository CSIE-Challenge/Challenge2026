extends Node2D

const NOTE_WARNING_AREA = preload("res://Scenes/menu/note_warning_area.tscn")

var start_y: float = -200.0
var target_y: float = 180.0  # 判定線的位置
var target_global_x: float = 0.0  # 最終落點的 X 世界座標
var center_global_x: float = 0.0  # 整個判定區中心的世界 X 座標 (用於 3D 放射軌跡)

var fall_speed: float = 400.0
var note_width: float = 80.0
var target_height: float = 45.0  # 判定區的高度
var player: Node2D


func init(
	start_x: float,
	spawn_y: float,
	end_y: float,
	center_x: float,
	width: float,
	height: float,
	speed: float,
	player_node: Node2D
) -> void:
	target_global_x = start_x
	start_y = spawn_y
	target_y = end_y
	center_global_x = center_x
	note_width = width
	target_height = height
	fall_speed = speed
	player = player_node

	# 初始位置在最上方 (3D 遠處焦點)
	global_position = Vector2(center_global_x, start_y)

	# 設定 ColorRect 落鍵外觀大小 (使其相對於中心點居中對齊)
	$ColorRect.size = Vector2(note_width, 18.0)  # 高度 18 的長條鍵
	$ColorRect.position = -Vector2(note_width, 18.0) / 2.0

	# 🌟【Glow 高亮冰藍色光芒】使用大於 1 的顏色值 (HDR)，配合 WorldEnvironment 產生霓虹光芒
	$ColorRect.modulate = Color(0.5, 1.5, 3.0, 0.85)

	# 初始為 3D 透視遠處的大小 (縮小 0.3 倍)
	scale = Vector2(0.3, 0.3)


func _process(delta: float) -> void:
	if not is_instance_valid(player):
		queue_free()
		return

	# 垂直向下飛行
	global_position.y += fall_speed * delta

	# 計算目前的下落比例 (t 從 0.0 到 1.0)
	var total_dist = target_y - start_y
	var current_dist = global_position.y - start_y
	var t = clampf(current_dist / total_dist, 0.0, 1.0)

	# 🌟 1. 【近大遠小】縮放隨 t 從 0.3 線性放大到 1.0
	var current_scale = lerp(0.3, 1.0, t)
	scale = Vector2(current_scale, current_scale)

	# 🌟 2. 【放射狀 3D 軌道】X 座標隨著接近判定線，從中心放射滑出到指定 X 落點
	global_position.x = lerp(center_global_x, target_global_x, t)

	# 3. 當落鍵底部到達判定線時，觸發判定
	# 因為高度會被 scale 縮放影響，所以此時的半高度是 9.0 * scale.y
	if global_position.y + (9.0 * scale.y) >= target_y:
		_trigger_judgment()


func _trigger_judgment() -> void:
	# 停止 process，防止重複觸發
	set_process(false)

	# 1. 在判定線上生成一個紅色高亮傷害殘影框
	var warning = NOTE_WARNING_AREA.instantiate()
	get_parent().add_child(warning)
	# 殘影位置就在落鍵最終降落的世界座標上
	warning.global_position = Vector2(target_global_x, target_y)
	# 初始化殘影：寬度、高度、持續傷害時間 0.1 秒 (0.1秒後關閉碰撞，純留視覺淡出)
	warning.init(note_width, target_height, 0.1, player)

	# 2. 播放落鍵撞擊判定線的消失特效 (橫向拉寬壓扁，隨後銷毀)
	var tween = create_tween()
	(
		tween
		. tween_property(self, "scale", Vector2(1.5, 0.0), 0.06)
		. set_trans(Tween.TRANS_CUBIC)
		. set_ease(Tween.EASE_OUT)
	)
	tween.parallel().tween_property($ColorRect, "modulate:a", 0.0, 0.06)
	tween.tween_callback(queue_free)
