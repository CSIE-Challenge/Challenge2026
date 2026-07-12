# skin_data.gd
class_name SkinData extends Resource  # 繼承自 Resource 是關鍵！

# -- 基本資訊 --
@export var skin_id: String = "skin_001"  # 程式內部辨識用的唯一ID
@export var true_name: String = "預設皮膚"  # 皮膚的真實名稱
@export var description: String = "這是一個很酷的皮膚！"  # 皮膚的介紹文字
@export var hide_name: bool = false  # 如果玩家未擁有，是否要將名稱顯示為亂碼？

# -- 獲取條件 --
@export var price: int = 100  # 商店顯示的價格（元）
@export var is_achievement_unlock: bool = false  # 是否為特殊成就解鎖（非金錢）
@export var achievement_desc: String = ""  # 例如："通關困難模式解鎖"

# -- 視覺表現 --
@export var is_silhouette: bool = false  # 未解鎖時是否只顯示黑影且鎖定預覽？
@export var preview_texture: Texture2D  # 顯示在商店格子裡的靜態圖片
# 如果你有皮膚的場景 (PackedScene)，可以加在這裡供實際掛載與詳細預覽頁面使用
@export var skin_prefab: PackedScene
# 不同的 skin 有不同的 health icon
@export var health_icon_texture: Texture2D
@export var health_icon_texture2: Texture2D
