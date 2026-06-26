extends AnimatableBody2D  # 🌟 根節點改為繼承 AnimatableBody2D

const DEFAULT_HALF_SIZE = Vector2(200.0, 200.0)
const DEFAULT_POSITION = Vector2(0, -20)  # 預設場地中心

# 當前的半寬高值 (方便 Tween 讀寫)
var current_half_size: Vector2 = DEFAULT_HALF_SIZE:
	set(value):
		current_half_size = value
		_update_wall_positions()

var bounce_tween: Tween
var dynamic_base_half: Vector2 = DEFAULT_HALF_SIZE

# 獲取子碰撞節點與貼圖節點
@onready var right_collision = $RightWallCollision
@onready var left_collision = $LeftWallCollision
@onready var up_collision = $UpWallCollision
@onready var down_collision = $DownWallCollision


func _ready() -> void:
	current_half_size = DEFAULT_HALF_SIZE


# 根據 current_half_size 即時更新子 CollisionShape2D 的 position 與長度 (scale.y)
# 因為 CollisionShape2D 不是獨立物理體，所以完全不會引發任何物理同步競態 Bug！
func _update_wall_positions() -> void:
	if right_collision:
		right_collision.position = Vector2(current_half_size.x, 0)
		right_collision.scale.y = (current_half_size.y / 250.0) * 3.6
	if left_collision:
		left_collision.position = Vector2(-current_half_size.x, 0)
		left_collision.scale.y = (current_half_size.y / 250.0) * 3.6
	if up_collision:
		# up_wall 預設旋轉了 90 度，所以 Y 座標對應上下移動
		up_collision.position = Vector2(0, current_half_size.y)
		up_collision.scale.y = (current_half_size.x / 250.0) * 3.6
	if down_collision:
		# down_wall 預設旋轉了 90 度，所以 Y 座標對應上下移動
		down_collision.position = Vector2(0, -current_half_size.y)
		down_collision.scale.y = (current_half_size.x / 250.0) * 3.6

	# 🌟 新增：強力防穿牆與平滑推擠約束機制
	var player = get_node_or_null("../coconut")
	if is_instance_valid(player):
		var half = current_half_size
		var player_radius = 16.0  # 椰子碰撞半徑約 15px，給予 1px 的安全餘量

		# 計算玩家允許活動的最邊緣邊界
		var min_x = position.x - half.x + player_radius
		var max_x = position.x + half.x - player_radius

		# 在 Godot 中正 Y 向下，負 Y 向上。
		# 牆壁上邊界是 position.y - half.y，下邊界是 position.y + half.y
		var min_y = position.y - half.y + player_radius
		var max_y = position.y + half.y - player_radius

		# 🌟 X 軸強制限制：如果牆壁壓得比玩家還窄，強制將玩家置中以防 Clamp 報錯
		if min_x < max_x:
			player.position.x = clamp(player.position.x, min_x, max_x)
		else:
			player.position.x = position.x

		# 🌟 Y 軸強制限制
		if min_y < max_y:
			player.position.y = clamp(player.position.y, min_y, max_y)
		else:
			player.position.y = position.y


# ==================== 外部調用 API ====================


# 1. 動態平滑調整牆壁框框的大小 (傳入目標寬高，例如 Vector2(300, 200))
func tween_box_size(target_size: Vector2, duration: float) -> PropertyTweener:
	var target_half = target_size / 2.0
	var tween = create_tween()
	return (
		tween
		. tween_property(self, "current_half_size", target_half, duration)
		. set_trans(Tween.TRANS_CUBIC)
		. set_ease(Tween.EASE_OUT)
	)


# 2. 動態平滑移動整個框框的中心位置 (相對於 Stage)
func tween_box_position(target_pos: Vector2, duration: float) -> PropertyTweener:
	var tween = create_tween()
	return (
		tween
		. tween_property(self, "position", target_pos, duration)
		. set_trans(Tween.TRANS_CUBIC)
		. set_ease(Tween.EASE_OUT)
	)


# 3. 一鍵重置牆壁的大小與位置
func reset_box(duration: float = 0.5) -> void:
	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "current_half_size", DEFAULT_HALF_SIZE, duration)
	tween.tween_property(self, "position", DEFAULT_POSITION, duration)


# 4. 同時平滑移動與縮放框框
func tween_box(target_size: Vector2, target_pos: Vector2, duration: float) -> void:
	var target_half = target_size / 2.0
	var tween = create_tween().set_parallel(true)
	(
		tween
		. tween_property(self, "current_half_size", target_half, duration)
		. set_trans(Tween.TRANS_CUBIC)
		. set_ease(Tween.EASE_OUT)
	)
	(
		tween
		. tween_property(self, "position", target_pos, duration)
		. set_trans(Tween.TRANS_CUBIC)
		. set_ease(Tween.EASE_OUT)
	)


func bounce_punch(is_horizontal_hit: bool) -> void:
	if bounce_tween and bounce_tween.is_valid():
		bounce_tween.kill()

	# 🌟 1. 永久改變場地的基礎比例 (每次撞擊變動 15 像素)
	if is_horizontal_hit:
		dynamic_base_half.x += 15.0
		dynamic_base_half.y -= 15.0
	else:
		dynamic_base_half.y += 15.0
		dynamic_base_half.x -= 15.0

	# 🌟 2. 限制極限大小，避免場地無限放大或縮到不見
	dynamic_base_half.x = clamp(dynamic_base_half.x, 80.0, 360.0)
	dynamic_base_half.y = clamp(dynamic_base_half.y, 80.0, 360.0)

	# 3. 計算瞬間被撞擊的極限形變 (比基礎尺寸更誇張，呈現果凍感)
	var peak_half = dynamic_base_half
	if is_horizontal_hit:
		peak_half.x += 20.0
		peak_half.y -= 10.0
	else:
		peak_half.y += 20.0
		peak_half.x -= 10.0

	bounce_tween = create_tween()
	# 極速形變
	bounce_tween.tween_property(self, "current_half_size", peak_half, 0.04).set_trans(
		Tween.TRANS_SINE
	)
	# 🌟 彈性恢復到「新的永久比例」！這就是重點！
	(
		bounce_tween
		. tween_property(self, "current_half_size", dynamic_base_half, 0.35)
		. set_trans(Tween.TRANS_ELASTIC)
		. set_ease(Tween.EASE_OUT)
	)
