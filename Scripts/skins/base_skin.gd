class_name BaseSkin extends Node2D


# ==========================================
# 標準特效介面 (讓子類別去覆寫實作細節)
# ==========================================
func play_spawn():
	await get_tree().process_frame


func play_die():
	await get_tree().process_frame


func play_eat_ball():
	pass


func play_jump():
	pass


func play_land():
	pass


func play_hit():
	pass


# ==========================================
# 商店預覽用的自動循環展示 (所有皮膚共用這個邏輯)
# ==========================================
func play_showcase_loop():
	# 只要這個節點還在場景樹裡面 (沒有被關閉視窗殺掉)，就無限循環
	while is_inside_tree():
		play_spawn()
		await get_tree().create_timer(1.5).timeout

		# 檢查是否還在場景樹中 (避免等待期間被關閉)
		if not is_inside_tree():
			break

		play_eat_ball()
		await get_tree().create_timer(1.0).timeout
		if not is_inside_tree():
			break

		play_jump()
		await get_tree().create_timer(0.5).timeout
		if not is_inside_tree():
			break

		play_land()
		await get_tree().create_timer(1.0).timeout
		if not is_inside_tree():
			break

		play_die()
		await get_tree().create_timer(2.0).timeout
