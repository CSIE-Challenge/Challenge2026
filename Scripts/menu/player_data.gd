extends Node

signal skin_unlocked(skin_id)
signal skin_equipped(skin_id)

# 存檔路徑與加密密碼
const SAVE_PATH = "user://player_save.dat"
const ENCRYPT_PASS = "MySecretGodotGamePass2026!@#"  # 請隨意更改為你喜歡的密碼

var unlocked_skins: Array = ["default_skin"]

var equipped_skin: String = "default_skin":
	set(value):
		equipped_skin = value
		skin_equipped.emit(equipped_skin)
		save_data()  # 裝備變更時自動存檔


func _ready():
	# 遊戲啟動時自動讀取存檔
	load_data()


# ==========================================
# 存檔與讀檔系統 (加密版)
# ==========================================


func save_data():
	# 使用加密模式開啟檔案寫入
	var file = FileAccess.open_encrypted_with_pass(SAVE_PATH, FileAccess.WRITE, ENCRYPT_PASS)
	if file:
		var data = {"unlocked_skins": unlocked_skins, "equipped_skin": equipped_skin}
		# store_var 會將 Dictionary 自動轉換並加密寫入
		file.store_var(data)
		file.close()
	else:
		printerr("存檔失敗！無法寫入檔案。")


func load_data():
	if FileAccess.file_exists(SAVE_PATH):
		# 使用加密模式開啟檔案讀取
		var file = FileAccess.open_encrypted_with_pass(SAVE_PATH, FileAccess.READ, ENCRYPT_PASS)
		if file:
			var data = file.get_var()
			if data and typeof(data) == TYPE_DICTIONARY:
				# 使用 data.get(key, default_value) 確保就算存檔缺漏也不會報錯
				unlocked_skins = data.get("unlocked_skins", ["default_skin"])
				equipped_skin = data.get("equipped_skin", "default_skin")
			file.close()
		else:
			printerr("讀檔失敗！可能是檔案損毀或密碼錯誤。")
	else:
		print("沒有找到存檔，使用預設值並建立新存檔。")
		save_data()


# ==========================================
# 商店幫助函數
# ==========================================


func has_skin(skin_id: String) -> bool:
	return unlocked_skins.has(skin_id)
