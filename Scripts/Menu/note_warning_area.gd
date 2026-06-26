extends Area2D

# 因為是動畫所以交給Gemini :)


# 外部初始化長寬與持續時間
func init(width: float, height: float, duration: float, player_node: Node2D) -> void:
	# 1. 動態配置 CollisionShape2D 大小 (配合 RectangleShape2D)
	var shape = RectangleShape2D.new()
	shape.size = Vector2(width, height)
	$CollisionShape2D.shape = shape

	# 2. 動態配置 ColorRect 外觀大小與位置偏置 (使其相對於中心點居中)
	$ColorRect.size = Vector2(width, height)
	$ColorRect.position = -Vector2(width, height) / 2.0

	# 🌟【Glow 高亮光芒】使用大於 1 的顏色值 (HDR)，配合 WorldEnvironment 產生輝光
	$ColorRect.modulate = Color(3.0, 0.2, 0.2, 0.0)  # 初始為完全透明高亮紅

	# 3. 連接碰撞信號：踩到紅色殘影的玩家會死亡
	if player_node and player_node.has_method("die"):
		body_entered.connect(
			func(body):
				if body == player_node:
					player_node.die()
		)

	# 4. 播放殘影展開與閃爍動畫
	var tween = create_tween()

	# 瞬間閃紅 (在 0.05 秒內變為半透明紅，並帶有垂直縮放展開感)
	scale.y = 0.0
	tween.tween_property(self, "scale:y", 1.0, 0.05)
	tween.parallel().tween_property($ColorRect, "modulate:a", 0.7, 0.05)

	# 傷害維持極短時間 (0.1 秒)
	tween.tween_interval(duration)

	# 🌟【關鍵】0.1 秒傷害過後，立刻關閉 CollisionShape 碰撞，使其純粹變為視覺殘影，不影響玩家後續移動
	tween.tween_callback(func(): $CollisionShape2D.disabled = true)

	# 隨後在 0.3 秒內收縮並淡出消失 (視覺殘影收縮餘韻)
	tween.tween_property(self, "scale:y", 0.0, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(
		Tween.EASE_IN
	)
	tween.parallel().tween_property($ColorRect, "modulate:a", 0.0, 0.3)
	tween.tween_callback(queue_free)
