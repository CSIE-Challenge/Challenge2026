extends Control

signal detail_requested(data: SkinData)
signal action_requested(data: SkinData)

var skin_data: SkinData  # 儲存當前這個商品卡片對應的資料

var sub_viewport: SubViewport
var sub_viewport_container: SubViewportContainer

# 設定好節點的參考 (請確保這些節點名稱與你場景中的一致)
@onready
var preview_btn: TextureButton = $MarginContainer/VBoxContainer/PreviewContainer/PreviewButton
@onready var name_label: Label = $MarginContainer/VBoxContainer/NameLabel
@onready var action_btn: Button = $MarginContainer/VBoxContainer/ActionBtn


# gdlint:disable=max-line-length
func _ready():
	var path = "MarginContainer/VBoxContainer/PreviewContainer/SubViewportContainer/SubViewport"
	sub_viewport = get_node(path)
	sub_viewport_container = get_node(
		"MarginContainer/VBoxContainer/PreviewContainer/SubViewportContainer"
	)
	# 綁定按鈕的點擊事件
	preview_btn.pressed.connect(_on_preview_pressed)
	action_btn.pressed.connect(_on_action_pressed)
	action_btn.clip_text = true


# gdlint:enable=max-line-length


# ==========================================
# 核心：初始化與更新介面
# ==========================================
func setup(data: SkinData):
	skin_data = data

	# 活體預覽：把 Prefab 塞進卡片的 SubViewport
	if skin_data.skin_prefab:
		# 為了避免和詳細展示衝突，我們為卡片創建獨立實例
		var preview_model = skin_data.skin_prefab.instantiate()
		sub_viewport.add_child(preview_model)
		if preview_model is BaseSkin and preview_model.has_method("play_spawn"):
			preview_model.play_spawn()  # 播放待機/出生特效
	elif skin_data.preview_texture:
		preview_btn.texture_normal = skin_data.preview_texture
	else:
		# 防呆機制：如果忘記設定縮圖，塞一個預設圖片避免看不到
		preview_btn.texture_normal = load("res://icon.svg")

	update_state()  # 根據玩家資料更新狀態


func update_state():
	# 判斷玩家是否已經擁有這個皮膚
	var is_owned = PlayerData.has_skin(skin_data.skin_id)
	var is_equipped = PlayerData.equipped_skin == skin_data.skin_id

	# 1. 處理剪影效果 (Shader 或 Modulate)
	# 活體預覽是畫在 SubViewportContainer 上的，也要一起塗黑才不會洩底
	if not is_owned and skin_data.is_silhouette:
		# 最簡單的剪影作法：將圖片塗黑
		preview_btn.modulate = Color(0, 0, 0, 1)
		sub_viewport_container.modulate = Color(0, 0, 0, 1)
	else:
		preview_btn.modulate = Color(1, 1, 1, 1)
		sub_viewport_container.modulate = Color(1, 1, 1, 1)

	# 2. 處理名稱顯示與亂碼
	if not is_owned and skin_data.hide_name:
		name_label.text = "????"  # 這裡可以替換成隨機亂碼產生的邏輯
	else:
		name_label.text = skin_data.true_name

	# 3. 處理下方按鈕狀態 (購買/裝備/已裝備)
	if is_equipped:
		action_btn.text = "已裝備"
		action_btn.disabled = true
		action_btn.modulate = Color(0.2, 1.0, 0.2, 1)  # 高亮綠色
	elif is_owned:
		action_btn.text = "裝備"
		action_btn.disabled = false
		action_btn.modulate = Color(1, 1, 1, 1)  # 正常顏色
	else:
		# 玩家未擁有，顯示購買條件，禁止點擊
		action_btn.disabled = true
		action_btn.modulate = Color(0.8, 0.8, 0.8, 1)  # 顯示為灰色標籤
		if skin_data.is_achievement_unlock:
			if skin_data.achievement_desc != "":
				action_btn.text = skin_data.achievement_desc
			elif skin_data.price_text_override != "":
				action_btn.text = skin_data.price_text_override
			else:
				action_btn.text = "未解鎖"
		elif skin_data.price_text_override != "":
			action_btn.text = skin_data.price_text_override
		else:
			action_btn.text = "未解鎖"


# ==========================================
# 玩家點擊事件
# ==========================================
func _on_preview_pressed():
	# 通知商店開啟詳細預覽彈出視窗
	Audio.play_sfx(Audio.SFX.BUTTON_PRESS)
	detail_requested.emit(skin_data)


func _on_action_pressed():
	# 通知商店玩家按下了購買或裝備
	Audio.play_sfx(Audio.SFX.BUTTON_PRESS)
	action_requested.emit(skin_data)
