class_name DemoResultScreen
extends CanvasLayer

var fade_tween: Tween

@onready var stat_names_label: Label = %StatNamesLabel
@onready var stat_values_label: Label = %StatValuesALabel
@onready var stat_values_b_label: Label = %StatValuesBLabel
@onready var health_icon = %HealthIconsA
@onready var health_icon_b = %HealthIconsB
@onready var vboxcontainer = %VBoxContainer
@onready var result_root: Control = $ResultRoot
@onready var title_label: Label = %TitleLabel
@onready var border_panel: PanelContainer = $"ResultRoot/CenterContainer/PanelContainer"


func _ready() -> void:
	hide()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and not event.pressed:
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_ENTER:
			if visible:
				_on_home_button_button_up()
				get_viewport().set_input_as_handled()


func show_demo_results(
	results_a: Dictionary,
	results_b: Dictionary,
	winner_peer_ids: Array,
	draw: bool,
	forfeit: bool,
	peer_id_a: int,
	peer_id_b: int,
	name_a: String = "Player A (Left)",
	name_b: String = "Player B (Right)"
) -> void:
	var survival_seconds_a := int(results_a.get("elapsed_time", 0.0))
	var survival_seconds_b := int(results_b.get("elapsed_time", 0.0))

	# 1. 解決死亡/輸家血量顯示 1 的問題
	# 若非平手，且玩家未贏得比賽，則其剩餘血量強制顯示為 0
	var health_val_a = int(results_a.get("health", 0))
	var health_val_b = int(results_b.get("health", 0))
	if not draw:
		if not peer_id_a in winner_peer_ids:
			health_val_a = 0
		if not peer_id_b in winner_peer_ids:
			health_val_b = 0

	# "Remaining Health" 行設定為空字串 ""，因為血量 Icon 會動態對齊覆蓋在此行
	var names: Array[String] = [
		"",
		"Survival Time",
		"Remaining Health",
		"Energy Balls Collected",
		"Jumps",
		"Distance Traveled",
		"Total Energy Spent",
	]

	# 使用傳入的真實名稱
	var values_a: Array[String] = [
		name_a,
		"%02d:%02d" % [survival_seconds_a / 60, survival_seconds_a % 60],
		"",
		str(int(results_a.get("energy_ball_count", 0))),
		str(int(results_a.get("jump_count", 0))),
		"%.1f" % float(results_a.get("distance_traveled", 0.0)),
		str(int(results_a.get("energy_spent", 0))),
	]

	var values_b: Array[String] = [
		name_b,
		"%02d:%02d" % [survival_seconds_b / 60, survival_seconds_b % 60],
		"",
		str(int(results_b.get("energy_ball_count", 0))),
		str(int(results_b.get("jump_count", 0))),
		"%.1f" % float(results_b.get("distance_traveled", 0.0)),
		str(int(results_b.get("energy_spent", 0))),
	]

	# 設定勝負標題與顏色
	var win_color := Color.LAWN_GREEN
	var draw_color := Color.LIGHT_SKY_BLUE

	# 移除 " (Left)" 或 " (Right)" 後綴以在勝負大字中使用實際名字
	var display_name_a := name_a.trim_suffix(" (Left)")
	var display_name_b := name_b.trim_suffix(" (Right)")

	if draw:
		title_label.text = "DRAW"
		title_label.modulate = draw_color
	else:
		var a_won := peer_id_a in winner_peer_ids
		var b_won := peer_id_b in winner_peer_ids
		if a_won and b_won:
			title_label.text = "DRAW"
			title_label.modulate = draw_color
		elif a_won:
			if forfeit:
				title_label.text = "%s WINS (by forfeit)" % display_name_a.to_upper()
			else:
				title_label.text = "%s WINS" % display_name_a.to_upper()
			title_label.modulate = win_color
		elif b_won:
			if forfeit:
				title_label.text = "%s WINS (by forfeit)" % display_name_b.to_upper()
			else:
				title_label.text = "%s WINS" % display_name_b.to_upper()
			title_label.modulate = win_color
		else:
			title_label.text = "NO WINNER"
			title_label.modulate = draw_color

	var panel_style_box = StyleBoxFlat.new()
	panel_style_box.border_color = title_label.modulate
	panel_style_box.bg_color = Color(0, 0, 0, 0)
	panel_style_box.set_border_width_all(3)
	panel_style_box.set_corner_radius_all(27)
	border_panel.add_theme_stylebox_override("panel", panel_style_box)

	stat_names_label.text = "\n".join(names)
	stat_values_label.text = "\n".join(values_a)
	stat_values_b_label.text = "\n".join(values_b)

	# 設定 Player A 血量 Icon
	health_icon.modulate.a = 0.0
	health_icon.reversed = 1
	health_icon.set_icon_size(Vector2(25, 25))
	health_icon._ensure_icons()
	health_icon.set_health(health_val_a)

	# 設定 Player B 血量 Icon
	health_icon_b.modulate.a = 0.0
	health_icon_b.reversed = 1
	health_icon_b.set_icon_size(Vector2(25, 25))
	health_icon_b._ensure_icons()
	health_icon_b.set_health(health_val_b)

	result_root.modulate.a = 0.0
	show()
	result_root.show()
	health_icon.show()
	health_icon_b.show()
	health_icon.queue_sort()
	health_icon_b.queue_sort()
	vboxcontainer.queue_sort()

	# 等待排版布局完成
	await get_tree().process_frame
	await get_tree().process_frame

	# 對齊雙方的血量 Icon
	_align_health_icon_to_column(health_icon, stat_values_label)
	_align_health_icon_to_column(health_icon_b, stat_values_b_label)
	health_icon.modulate.a = 1.0
	health_icon_b.modulate.a = 1.0

	Audio.set_bgm(Audio.BGM.RESULT_SCREEN)
	_fade_in(3.0)


# 通用的血量 Icon 對齊方法
func _align_health_icon_to_column(icon_node: HBoxContainer, values_label: Label) -> void:
	var character_index := stat_names_label.text.find("Remaining Health")
	if character_index == -1:
		push_warning("Cannot find Remaining Health in StatNamesLabel")
		return
	var character_rect := stat_names_label.get_character_bounds(character_index)
	if character_rect.size == Vector2.ZERO:
		push_warning("Remaining Health text has not been laid out yet")
		return

	var character_center_local := character_rect.get_center()
	var character_center_global := stat_names_label.get_global_transform() * character_center_local
	var values_right_global := (
		values_label.get_global_transform() * Vector2(values_label.size.x, 0.0)
	)
	var icon_transform: Transform2D = icon_node.get_global_transform()
	var icon_right_center_global: Vector2 = (
		icon_transform * Vector2(icon_node.size.x, icon_node.size.y * 0.5)
	)
	var target_global := Vector2(values_right_global.x, character_center_global.y)
	icon_node.global_position += (target_global - icon_right_center_global)


func _fade_in(duration: float = 1.5) -> void:
	show()
	if fade_tween != null and fade_tween.is_valid():
		fade_tween.kill()
	fade_tween = create_tween()
	fade_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	(
		fade_tween
		. tween_property(result_root, "modulate:a", 1.0, duration)
		. set_trans(Tween.TRANS_EXPO)
		. set_ease(Tween.EASE_OUT)
	)


func _on_home_button_button_up() -> void:
	var player: AudioStreamPlayer = Audio.play_sfx(Audio.SFX.BUTTON_PRESS)
	SceneTransition.transition_to("res://Scenes/menu.tscn")
	await get_tree().create_timer(2).timeout
	hide()
	get_tree().paused = false


func _on_exit_button_button_up() -> void:
	var player: AudioStreamPlayer = Audio.play_sfx(Audio.SFX.BUTTON_PRESS)
	await get_tree().create_timer(0.5).timeout
	get_tree().quit()
