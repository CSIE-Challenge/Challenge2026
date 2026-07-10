extends Control

@export var skin_item_scene: PackedScene  # 從 Inspector 拖曳你的 SkinItem.tscn 進來
@export var all_skins: Array[SkinData]  # 從 Inspector 把你建立的 .tres 皮膚資料全部塞進這個陣列

var current_preview_model: Node = null  # 紀錄目前在 SubViewport 裡的皮膚實體
var instanced_items: Array[Control] = []  # 紀錄畫面上所有的商品節點

var detail_viewport: SubViewport
var close_btn: Button

@onready var grid_container: GridContainer = $ScrollContainer/GridContainer

@onready var detail_popup: ColorRect = $DetailPopup
@onready var detail_title: Label = $DetailPopup/CenterContainer/PopupPanel/VBoxContainer/Label
@onready var lock_icon: TextureRect = $DetailPopup/CenterContainer/PopupPanel/VBoxContainer/LockIcon
@onready var popup_panel: PanelContainer = $DetailPopup/CenterContainer/PopupPanel
@onready var coin_label: Label = $CoinLabel
@onready var main_close_btn: Button = $CloseButton


func _ready():
	var dv_path = (
		"DetailPopup/CenterContainer/PopupPanel/VBoxContainer/" + "SubViewportContainer/SubViewport"
	)
	detail_viewport = get_node(dv_path)
	var cb_path = "DetailPopup/CenterContainer/PopupPanel/VBoxContainer/MarginContainer/CloseBtn"
	close_btn = get_node(cb_path)

	# 商店開啟時，隱藏自己，準備做打開的特效
	modulate.a = 0.0

	_update_coin_label()

	# 1. 實例化所有商品
	populate_shop()

	# 2. 播放商店與商品出現的特效
	play_open_animation()

	detail_popup.visible = false
	close_btn.pressed.connect(_on_close_popup_pressed)
	main_close_btn.pressed.connect(_on_main_close_pressed)


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

	for data in all_skins:
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
	else:
		# 如果還沒擁有 -> 嘗試【購買】
		if not data.is_achievement_unlock:
			if PlayerData.buy_skin(data.skin_id, data.price):
				_update_coin_label()  # 更新金幣顯示
				refresh_all_items()  # 購買成功，刷新畫面讓按鈕變成「裝備」


func _update_coin_label():
	if coin_label:
		coin_label.text = "💰 " + str(PlayerData.money)


# 重新整理所有商品的狀態
func refresh_all_items():
	for item in instanced_items:
		item.update_state()  # 呼叫 SkinItem 裡的 update_state() 重新判斷


# ==========================================
# 處理開啟詳細介紹頁面
# ==========================================
func _on_item_detail_requested(data: SkinData):
	# 1. 判斷狀態
	var is_owned = PlayerData.has_skin(data.skin_id)
	var is_locked_silhouette = (not is_owned) and data.is_silhouette

	# 清除上一次預覽殘留的模型
	if current_preview_model:
		current_preview_model.queue_free()
		current_preview_model = null

	# 2. 根據狀態更新視窗內容
	if is_locked_silhouette:
		detail_title.text = "????"
		lock_icon.visible = true
		# 鎖定狀態不載入模型
	else:
		detail_title.text = data.true_name
		lock_icon.visible = false

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
