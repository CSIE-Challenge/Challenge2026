extends Node

signal skin_unlocked(skin_id)
signal skin_equipped(skin_id)

const SAVE_PATH = "user://player_data_v2.dat"
const ENCRYPT_PASS = "MySecretGodotGamePass2026!@#"
const REDEEM_CODES = {
	"23546eda29bfab9f12adca1725d3d183cc70fc5396e221f73b81535094b5302d": "default_skin",
	"a67930401e8c6fd412e8cf8862432c17a578c1230148af889914a596dbf6a2ce": "advanced_skin",
	"3ff03d8b4176e20372bf55fa43b280ca42dee1d3901f4d6f626e5f02f0001bfb": "phantom_skin",
	"374e2e90e319168a15eee176f3f307cbe934fb052e2c834f0c38663bb2aaabdb": "magma_skin",
	"1d97c04197a9429090e83ac0296d7ad90e0df3cddd9fdb691d344702d3085501": "slime_skin",
	"7a7c2a565bcc93a9c12f0fc7c29084e1726443c4546f2bfc95168f131c2c5ebf": "meteor_skin",
	"7207a125a4bd77e3ad0ff233945eb781bd300979ff3e45628664d670dc897f5f": "cyber_skin",
	"099e4cbefb7404c2066eae30b8e43e1b7f5bf226fa3b8cbe6f53e0905e3b3309": "thunder_skin",
	"3e241d49a84593189bdc33ccca1fc03aa0e9c74c3a1d45fc6b26682db2472eab": "golden_skin",
	"75b9866650c2b41fb63da1c091238c005652b6b9baad4b41f6a533d63a97e81a": "ninja_skin",
	"fcc7549ba1dda96ded3cba695b6d4e1f243df6b3d9a2c4ceb363b44230ecb67b": "attack_ball_skin",
	"cbc8df6fb4b452a1a1db5455e0cc9b1d1c24397c918eed2e413f53dee8e4cec0": "champion_skin",
	"dbc5077b4a7e4d2d2706db3b1c8315dec4c7cd0b49012cf5aa6eaad4c7961744": "singularity_skin",
	"61abd92d150567faca80109d1e4ca53705487b0408b58cce88887cce309560cb": "absolute_zero_skin",
	"715f5c4da094699f4a7386763c4aef1746d6c9be61a8d88f9852905cbb3410af": "retro_pixel_skin",
	"e92dff200199c95e618aafcdd535d8cc28f3207d7ea2738f01623870e4cd0fed": "chicken_skin",
	"468bca4cf3a7f99b8fe1029f1c96a3f093c771b5ecec5a24c992db9145eb18f4": "among_us_skin",
	"9539642517f75d9067977dbbe3dd6b6c3b26e1f6bdddfec9458c0ef0c035cd1d": "matrix_skin",
	"e13d147447354677737fe0de9ec3379bdbd0ace0f5f7f28eb8c7cca2169a93f5": "undertale_skin",
	"372e8ba7ce62b4d77e68a848a6ceed4d2a1b545b322b519dc60228be672bafa4": "coconut_king_skin",
	"cc2f55d090a86899aeff8915f84e4dda53cdc45cfc3b2c1ec20d90d183fa3b69": "claude_skin",
	"d031c4f465df0276f570a84d981a34e946f25e411f6e414d0416094802c38448": "perry_skin",
	"b8ecc695944657ff55e46cf5799950dd4f97e7270fc83f9ffe82d2b5a4122c47": "red_black_tree_skin",
	"0d4bb7907d956210fe58d62227286b38c857751f563aa9b822ff96225925bc52": "steel_brain_skin",
	"1d718f314a4484758db49181edccb4e45245724e9ee38dfa72f9b7f8ac470d02": "three_body_coconut_skin",
	"348ae37ab1ce6ab3340b24e3e57671fc73b81ce8690e721e894c8cc82d573fc0": "walile_skin",
	"1cc387c72e4c302f5d8bb28c4c4074b8114dcb6a25ef61860d2a1bd5aae5486f": "driftwood_skin",
	"f5180b81379222e56781cdeb70a6458e77b70ef5aafd81b8ebac1cd5229f3f3c": "drive_skin",
	"b355c1e254a16eec13b5b41a6460c6ada838ae6e9ce8b53c29c89861f98ef2f4": "inverted_palm_skin",
	"880467377209f84a74e1379d52067614d62162b88f1a63a9ea13d6f13f167ee1": "close_button_skin",
	"6b3fa673194d764cc52a0526717c3619efa8d2be0cc85e0f45c16ae05a14cb3c": "sans_skin"
}

var entered_codes: Array = []

var equipped_skin: String = "default_skin":
	set(value):
		if has_skin(value):
			equipped_skin = value
			skin_equipped.emit(equipped_skin)
			if not _is_loading:
				save_data()

var has_entered_hidden_game: bool = false
var last_selected_avatar: String = ""
var _is_loading: bool = false


func _ready():
	load_data()
	save_data()


func save_data():
	var file = FileAccess.open_encrypted_with_pass(SAVE_PATH, FileAccess.WRITE, ENCRYPT_PASS)
	if file:
		var data = {
			"entered_codes": entered_codes,
			"equipped_skin": equipped_skin,
			"has_entered_hidden_game": has_entered_hidden_game,
			"last_selected_avatar": last_selected_avatar
		}
		file.store_var(data)
		file.close()


func load_data():
	if FileAccess.file_exists(SAVE_PATH):
		_is_loading = true
		var file = FileAccess.open_encrypted_with_pass(SAVE_PATH, FileAccess.READ, ENCRYPT_PASS)
		if file:
			var data = file.get_var()
			if data and typeof(data) == TYPE_DICTIONARY:
				entered_codes = data.get("entered_codes", [])
				equipped_skin = data.get("equipped_skin", "default_skin")
				has_entered_hidden_game = data.get("has_entered_hidden_game", false)
				last_selected_avatar = data.get("last_selected_avatar", "")
			file.close()
		_is_loading = false
	else:
		save_data()


func has_skin(skin_id: String) -> bool:
	if skin_id == "default_skin":
		return true

	for code in entered_codes:
		if typeof(code) == TYPE_STRING:
			var h = code.sha256_text()
			if REDEEM_CODES.get(h) == skin_id:
				return true

	return false


func add_entered_code(code: String) -> bool:
	var code_upper = code.strip_edges().to_upper()
	if not entered_codes.has(code_upper):
		entered_codes.append(code_upper)
		save_data()
		return true
	return false
