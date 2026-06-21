extends AnimatableBody2D  # 🌟 根節點改為繼承 AnimatableBody2D

const DEFAULT_HALF_SIZE = Vector2(200.0, 200.0)
const DEFAULT_POSITION = Vector2(0, -20)  # 預設場地中心

# 當前的半寬高值 (方便 Tween 讀寫)
var current_half_size: Vector2 = DEFAULT_HALF_SIZE:
	set(value):
		current_half_size = value
		_update_wall_positions()

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
