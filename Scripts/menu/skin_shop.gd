extends Control

@export var skin_item_scene: PackedScene  # 從 Inspector 拖曳你的 SkinItem.tscn 進來
@export var all_skins: Array[SkinData]  # 從 Inspector 把你建立的 .tres 皮膚資料全部塞進這個陣列

var current_preview_model: Node = null  # 紀錄目前在 SubViewport 裡的皮膚實體
var instanced_items: Array[Control] = []  # 紀錄畫面上所有的商品節點

var detail_viewport: SubViewport
var close_btn: TextureButton

var current_detail_data: SkinData = null
# 為了避免明碼被偷看，這裡只儲存兌換碼的 SHA256 雜湊值
var redeem_codes = {
	"84f6a2c702e037e57b2289af71a2d28d68cde6934d70b097fb8884b62db3fb69": "default_skin",
	"886f2cb86c4ba333f9b506a2db58d64bac1c81e17688b4d2df6733665c65e450": "advanced_skin",
	"011f2f0e62048585e4701d1e95a385f737ac8052fb677f65fe90a9f90b1c5592": "phantom_skin",
	"ef642fe2c39f36d7c74431eb57e1db70e19a1e68ad7ce2c0a4447ba4bd65fc6f": "magma_skin",
	"1a4c586e7f3f6e9e83937a15628e8aa40ba2341d492427bd9eabf12a932103c0": "slime_skin",
	"3a914c541596e1220b923997fd13801de891f111213e92b83b69b0fbd5472dad": "meteor_skin",
	"aa357d92e50512b9daf4678746573b442d8fd50061419e1db6e0c5cc1ca48071": "cyber_skin",
	"94b7e668432447c355089493495f7b1eb6e12a90baf41f0208b23d53ab4a7c01": "thunder_skin",
	"799634aac05bd322a90fefa1c95adc04cce484e1e0dbb27688e6125083d95c3b": "golden_skin",
	"adf68bdabbf43a3e6d96b8e793bcfd5b899e9793c7d99d09d90bd8165f4c3c2b": "ninja_skin",
	"a12ea7da335092449afb85d4be6f650f1397583379286ce66dec64f31e9c14f2": "attack_ball_skin",
	"dca2e322ffde134f1b77e229aff58efe26701c4df696fca51fd9f1ea2fe5feb3": "champion_skin",
	"7223de97ceedcb7fe277ce6e732b279792e1ba5a3eeb4f34565e589d3cd225a8": "singularity_skin",
	"bb78f50c0237b6008c936b121de44c27ad060bf10493bce5175fc6c6fcc1441a": "absolute_zero_skin",
	"955fb8b06f12ee1177042fbb1c0ae2f0e07e96c917bd4d4a1ec84f49026944c2": "retro_pixel_skin",
	"b1febad03912a9c1e7524b552b9646acd16c0152f3510aea8884124fd3757203": "chicken_skin",
	"ee84277cbbe48dac2823530dc5fd607756216f6dfdda16b4b9eb2c9d90de468f": "among_us_skin",
	"0de8197e0efb7a13ecf7ebe6ab3ea20541820eb509c68533c1c53c1f74aee096": "matrix_skin",
	"99ce212dbfc057dd48d5532aacf9f0c76ac9f6a7cc3bac27b6be8e87525bc6e7": "undertale_skin",
	"d82925a1cbba09cb6b74d679d5eb5bb4068022ac647e27c4119dc96648a28177": "coconut_king_skin",
	"8169f1df4c3e57e67156554ded65480570cb74f65cdb50272f0b01acbc82abd5": "ALL_SKINS"
}

@onready var grid_container: GridContainer = $ScrollContainer/GridContainer

@onready var detail_popup: ColorRect = $DetailPopup
@onready var detail_title: Label = get_node(
	"DetailPopup/CenterContainer/PopupPanel/MarginContainer/" + "HBoxContainer/InfoVBox/Label"
)
@onready var detail_desc: Label = get_node(
	"DetailPopup/CenterContainer/PopupPanel/MarginContainer/" + "HBoxContainer/InfoVBox/DescLabel"
)
@onready var detail_cond: Label = get_node(
	(
		"DetailPopup/CenterContainer/PopupPanel/MarginContainer/"
		+ "HBoxContainer/InfoVBox/ConditionLabel"
	)
)
@onready var action_btn: Button = get_node(
	"DetailPopup/CenterContainer/PopupPanel/MarginContainer/" + "HBoxContainer/InfoVBox/ActionBtn"
)
@onready var lock_icon: TextureRect = get_node(
	"DetailPopup/CenterContainer/PopupPanel/MarginContainer/" + "HBoxContainer/PreviewVBox/LockIcon"
)
@onready var popup_panel: PanelContainer = $DetailPopup/CenterContainer/PopupPanel
@onready var main_close_btn: Button = $CloseButton

@onready var open_redeem_btn: Button = $OpenRedeemBtn

@onready var redeem_popup: ColorRect = $RedeemPopup
@onready var redeem_input: LineEdit = get_node(
	"RedeemPopup/CenterContainer/PanelContainer/MarginContainer/" + "VBoxContainer/RedeemInput"
)
@onready var redeem_msg_label: Label = get_node(
	"RedeemPopup/CenterContainer/PanelContainer/MarginContainer/" + "VBoxContainer/MessageLabel"
)
@onready var redeem_submit_btn: Button = get_node(
	(
		"RedeemPopup/CenterContainer/PanelContainer/MarginContainer/"
		+ "VBoxContainer/HBoxContainer/RedeemSubmitBtn"
	)
)
@onready var redeem_close_btn: Button = get_node(
	(
		"RedeemPopup/CenterContainer/PanelContainer/MarginContainer/"
		+ "VBoxContainer/HBoxContainer/RedeemCloseBtn"
	)
)


func _ready():
	var dv_path = (
		"DetailPopup/CenterContainer/PopupPanel/MarginContainer/HBoxContainer/PreviewVBox/"
		+ "SubViewportContainer/SubViewport"
	)
	detail_viewport = get_node(dv_path)
	var cb_path = "DetailPopup/LeaveBtn"
	close_btn = get_node(cb_path)

	# 商店開啟時，隱藏自己，準備做打開的特效
	modulate.a = 0.0

	# 1. 實例化所有商品
	populate_shop()

	# 2. 播放商店與商品出現的特效
	play_open_animation()

	detail_popup.visible = false
	close_btn.pressed.connect(_on_close_popup_pressed)
	main_close_btn.pressed.connect(_on_main_close_pressed)
	action_btn.pressed.connect(_on_detail_action_pressed)

	redeem_popup.visible = false
	open_redeem_btn.pressed.connect(_on_open_redeem_pressed)
	redeem_close_btn.pressed.connect(_on_redeem_close_pressed)
	redeem_submit_btn.pressed.connect(_on_redeem_submit_pressed)


func _on_main_close_pressed():
	# 離開商店回到主畫面
	Audio.play_sfx(Audio.SFX.BUTTON_PRESS)
	SceneTransition.transition_to("res://Scenes/menu.tscn")


# ==========================================
# 生成商品
# ==========================================
func populate_shop():
	# 清空網格 (如果在開發中重複呼叫時)
	for child in grid_container.get_children():
		child.queue_free()
	instanced_items.clear()

	var sorted_skins = all_skins.duplicate()
	sorted_skins.sort_custom(
		func(a, b):
			if a == null or b == null:
				return false
			var a_owned = PlayerData.has_skin(a.skin_id)
			var b_owned = PlayerData.has_skin(b.skin_id)
			if a_owned and not b_owned:
				return true
			if not a_owned and b_owned:
				return false
			return false
	)

	for data in sorted_skins:
		if data == null:
			continue  # 防呆機制：如果陣列裡有空槽位就跳過

		var item = skin_item_scene.instantiate()
		grid_container.add_child(item)

		# 綁定商品發出的訊號到我們商店的函數
		item.detail_requested.connect(_on_item_detail_requested)
		item.action_requested.connect(_on_item_action_requested)

		# 初始化商品狀態
		item.setup(data)
		instanced_items.append(item)


# ==========================================
# 特效動畫 (Tween)
# ==========================================
func play_open_animation():
	var tween = create_tween()

	# 1. 整個商店背景淡入 (0.3秒)
	tween.tween_property(self, "modulate:a", 1.0, 0.3)

	# 2. 讓裡面的商品一個一個「彈」出來 (階梯式特效 Staggered Animation)
	for i in range(instanced_items.size()):
		var item = instanced_items[i]
		# 初始狀態設為透明且縮小
		item.modulate.a = 0.0
		item.scale = Vector2(0.5, 0.5)
		# 改變物件的軸心，讓它從中心點放大 (這裡假設 anchor 是預設的，使用 pivot_offset)
		item.pivot_offset = item.size / 2.0

		# 平行執行的動畫 (與前一個同時發生，但我們用 set_delay 錯開)
		# 每個商品比前一個晚 0.05 秒出現，並加上 Q 彈效果 (TRANS_BACK)
		tween.parallel().tween_property(item, "modulate:a", 1.0, 0.4).set_delay(i * 0.05)
		(
			tween
			. parallel()
			. tween_property(item, "scale", Vector2(1, 1), 0.4)
			. set_trans(Tween.TRANS_BACK)
			. set_ease(Tween.EASE_OUT)
			. set_delay(i * 0.05)
		)


# ==========================================
# 處理購買與裝備邏輯
# ==========================================
func _on_item_action_requested(data: SkinData):
	if PlayerData.has_skin(data.skin_id):
		# 如果已經擁有了 -> 執行【裝備】
		PlayerData.equipped_skin = data.skin_id
		refresh_all_items()  # 刷新畫面，確保只有一個顯示「已裝備」


func _on_detail_action_pressed():
	Audio.play_sfx(Audio.SFX.BUTTON_PRESS)
	if current_detail_data == null:
		return
	var data = current_detail_data

	if PlayerData.has_skin(data.skin_id):
		PlayerData.equipped_skin = data.skin_id
		refresh_all_items()
		action_btn.text = "已裝備"
		action_btn.disabled = true


func show_message(msg: String):
	redeem_msg_label.text = msg


func _on_open_redeem_pressed():
	Audio.play_sfx(Audio.SFX.BUTTON_PRESS)
	redeem_input.text = ""
	redeem_msg_label.text = ""
	redeem_popup.visible = true
	redeem_popup.modulate.a = 0.0
	var panel = redeem_popup.get_node("CenterContainer/PanelContainer")
	panel.scale = Vector2(0.5, 0.5)
	panel.pivot_offset = panel.size / 2.0
	var tween = create_tween()
	redeem_input.grab_focus()
	tween.parallel().tween_property(redeem_popup, "modulate:a", 1.0, 0.2)
	(
		tween
		. parallel()
		. tween_property(panel, "scale", Vector2.ONE, 0.3)
		. set_trans(Tween.TRANS_BACK)
		. set_ease(Tween.EASE_OUT)
	)


func _on_redeem_close_pressed():
	Audio.play_sfx(Audio.SFX.BUTTON_PRESS)
	var tween = create_tween()
	var panel = redeem_popup.get_node("CenterContainer/PanelContainer")
	tween.parallel().tween_property(redeem_popup, "modulate:a", 0.0, 0.2)
	(
		tween
		. parallel()
		. tween_property(panel, "scale", Vector2(0.8, 0.8), 0.2)
		. set_trans(Tween.TRANS_BACK)
		. set_ease(Tween.EASE_IN)
	)
	await tween.finished
	redeem_popup.visible = false


func _on_redeem_submit_pressed():
	Audio.play_sfx(Audio.SFX.BUTTON_PRESS)
	var code = redeem_input.text.strip_edges().to_upper()
	var code_hash = code.sha256_text()  # 將輸入的兌換碼進行 SHA256 雜湊
	if redeem_codes.has(code_hash):
		var skin_id = redeem_codes[code_hash]

		if skin_id == "ALL_SKINS":
			var changed = false
			for s in all_skins:
				if s != null and not PlayerData.has_skin(s.skin_id):
					PlayerData.unlocked_skins.append(s.skin_id)
					PlayerData.skin_unlocked.emit(s.skin_id)
					changed = true
			if changed:
				PlayerData.save_data()
				show_message("秘技：解鎖全部皮膚！")
				redeem_input.text = ""
				populate_shop()
			else:
				show_message("已經擁有全部皮膚！")
			return

		if not PlayerData.has_skin(skin_id):
			PlayerData.unlocked_skins.append(skin_id)
			PlayerData.save_data()  # 確保兌換後存檔
			PlayerData.skin_unlocked.emit(skin_id)
			show_message("兌換成功！")
			redeem_input.text = ""
			populate_shop()  # 重新排序與刷新
		else:
			show_message("已經兌換過此皮膚！")
	else:
		show_message("兌換碼不存在或無效！")


# 重新整理所有商品的狀態
func refresh_all_items():
	for item in instanced_items:
		item.update_state()  # 呼叫 SkinItem 裡的 update_state() 重新判斷


# 未擁有時顯示的價格文字，可被 price_text_override 覆寫
func _get_price_text(data: SkinData) -> String:
	if data.price_text_override != "":
		return data.price_text_override
	return "價格：%d 元" % data.price


# ==========================================
# 處理開啟詳細介紹頁面
# ==========================================
func _on_item_detail_requested(data: SkinData):
	current_detail_data = data
	# 1. 判斷狀態
	var is_owned = PlayerData.has_skin(data.skin_id)
	var is_equipped = PlayerData.equipped_skin == data.skin_id
	var is_locked_silhouette = (not is_owned) and data.is_silhouette

	# 清除上一次預覽殘留的模型
	if current_preview_model:
		current_preview_model.queue_free()
		current_preview_model = null

	# 2. 根據狀態更新視窗內容
	if is_locked_silhouette:
		if data.hide_name:
			detail_title.text = "????"
			detail_desc.text = "未知的皮膚"
		else:
			detail_title.text = data.true_name
			detail_desc.text = data.description
		detail_cond.text = _get_price_text(data)
		action_btn.visible = true
		action_btn.text = "未解鎖"
		action_btn.disabled = true
		lock_icon.visible = true
		# 鎖定狀態不載入模型
	else:
		detail_title.text = data.true_name
		detail_desc.text = data.description
		action_btn.visible = true
		lock_icon.visible = false

		if is_owned:
			detail_cond.text = "已擁有"
			if is_equipped:
				action_btn.text = "已裝備"
				action_btn.disabled = true
			else:
				action_btn.text = "裝備"
				action_btn.disabled = false
		else:
			detail_cond.text = _get_price_text(data)
			action_btn.text = "未解鎖"
			action_btn.disabled = true

		# 預先載入舞台場景
		var ShowcaseStageScene = preload("res://Scenes/menu/showcase_stage.tscn")

		# 把皮膚丟到展示舞台上預覽！
		if data.skin_prefab:
			var stage = ShowcaseStageScene.instantiate()
			detail_viewport.add_child(stage)

			# 讓舞台去設定並開始表演
			stage.setup(data.skin_prefab)

			current_preview_model = stage

	# 3. 播放超 Q 彈的彈出特效
	detail_popup.visible = true
	detail_popup.modulate.a = 0.0
	popup_panel.scale = Vector2(0.5, 0.5)
	popup_panel.pivot_offset = popup_panel.size / 2.0  # 從中心點放大

	var tween = create_tween()
	tween.parallel().tween_property(detail_popup, "modulate:a", 1.0, 0.2)
	(
		tween
		. parallel()
		. tween_property(popup_panel, "scale", Vector2.ONE, 0.3)
		. set_trans(Tween.TRANS_BACK)
		. set_ease(Tween.EASE_OUT)
	)


# ==========================================
# 處理關閉按鈕
# ==========================================
func _on_close_popup_pressed():
	Audio.play_sfx(Audio.SFX.BUTTON_PRESS)
	var tween = create_tween()
	# 關閉時的縮小淡出特效
	tween.parallel().tween_property(detail_popup, "modulate:a", 0.0, 0.2)
	(
		tween
		. parallel()
		. tween_property(popup_panel, "scale", Vector2(0.8, 0.8), 0.2)
		. set_trans(Tween.TRANS_BACK)
		. set_ease(Tween.EASE_IN)
	)

	await tween.finished  # 等待動畫播完
	detail_popup.visible = false

	# 順手清掉模型節省記憶體
	if current_preview_model:
		current_preview_model.queue_free()
		current_preview_model = null
