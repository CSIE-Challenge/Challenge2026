extends Control

enum Page { A, B, C, D }

const MENU_SCENE := "res://Scenes/menu.tscn"
const GAMEPLAY_SCENE := "res://Scenes/gameplay.tscn"
const SETTINGS_PATH := "user://player_settings.cfg"
const SETTINGS_SECTION := "matchmaker"
const DEFAULT_AGENT_DIR := "agent/scripts"

var _matchmaker_ip := ""
var _room_code := ""
var _game_ip := ""
var _game_port := 0
var _player_id := ""
var _selected_agent := ""
var _confirmed := false

var _file_dialog: FileDialog

var _current_panel := Page.A

var _timer_b: int = 60
var _timer_d: int = 90
var _countdown_timer: Timer
var _poll_timer: Timer
var _pending_request := ""

@onready var ip_input: LineEdit = $Panel/VBoxContainer/IPInput
@onready var panel_a: VBoxContainer = $Panel/PanelA
@onready var panel_b: VBoxContainer = $Panel/PanelB
@onready var panel_c: VBoxContainer = $Panel/PanelC
@onready var panel_d: VBoxContainer = $Panel/PanelD

@onready var error_label_a: Label = $Panel/PanelA/ErrorLabel
@onready var error_label_c: Label = $Panel/PanelC/ErrorLabel

@onready var countdown_b: Label = $Panel/PanelB/CountdownLabel
@onready var code_label: Label = $Panel/PanelB/CodeLabel
@onready var countdown_d: Label = $Panel/PanelD/CountdownLabel
@onready var status_label: Label = $Panel/PanelD/StatusLabel
@onready var agent_label: Label = $Panel/PanelD/AgentLabel
@onready var ready_button: Button = $Panel/PanelD/ReadyButton

@onready var code_input: LineEdit = $Panel/PanelC/CodeInput

@onready var http_request: HTTPRequest = $HTTPRequest


func _ready() -> void:
	Audio.set_bgm(Audio.BGM.MENU)
	_matchmaker_ip = _load_ip()
	ip_input.text = _matchmaker_ip

	_poll_timer = Timer.new()
	_poll_timer.wait_time = 1.0
	_poll_timer.one_shot = false
	_poll_timer.timeout.connect(_on_poll_tick)
	add_child(_poll_timer)

	_countdown_timer = Timer.new()
	_countdown_timer.wait_time = 1.0
	_countdown_timer.one_shot = false
	_countdown_timer.timeout.connect(_on_countdown_tick)
	add_child(_countdown_timer)

	_show_panel(Page.A)

	http_request.request_completed.connect(_on_request_completed)

	NetworkManager.server_disconnected.connect(_on_server_disconnected)


func _load_ip() -> String:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return ""
	return cfg.get_value(SETTINGS_SECTION, "ip", "")


func _save_ip(ip: String) -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	if ip == "":
		if cfg.has_section(SETTINGS_SECTION):
			cfg.erase_section_key(SETTINGS_SECTION, "ip")
	else:
		cfg.set_value(SETTINGS_SECTION, "ip", ip)
	cfg.save(SETTINGS_PATH)


func _show_panel(panel: Panel) -> void:
	_current_panel = panel
	panel_a.visible = (panel == Page.A)
	panel_b.visible = (panel == Page.B)
	panel_c.visible = (panel == Page.C)
	panel_d.visible = (panel == Page.D)


func _post(path: String, body: Dictionary, tag: String) -> void:
	_pending_request = tag
	var url := "http://" + _matchmaker_ip + path
	var json_body := JSON.stringify(body)
	var headers := PackedStringArray(["Content-Type: application/json"])
	var err := http_request.request(url, headers, HTTPClient.METHOD_POST, json_body)
	if err != OK:
		_handle_error("HTTP request failed")


func _http_get(path: String, tag: String) -> void:
	_pending_request = tag
	var url := "http://" + _matchmaker_ip + path
	var err := http_request.request(url)
	if err != OK:
		_handle_error("HTTP request failed")


func _handle_error(msg: String) -> void:
	match _current_panel:
		Page.A:
			error_label_a.text = msg
		Page.C:
			error_label_c.text = msg
		_:
			printerr("[Matchmaker] ", msg)


func _on_request_completed(
	result: int, _code: int, _headers: PackedStringArray, body: PackedByteArray
) -> void:
	var body_str := body.get_string_from_utf8()
	var tag := _pending_request
	_pending_request = ""

	var data: Dictionary
	var test_json := JSON.new()
	if test_json.parse(body_str) == OK:
		data = test_json.get_data()
	else:
		_handle_error("Invalid response from server")
		return

	if result != HTTPRequest.RESULT_SUCCESS:
		var error_msg := data.get("error", "Request failed") as String
		_handle_error(error_msg)
		return

	match tag:
		"create_room":
			_on_create_room_response(data)
		"join_room":
			_on_join_room_response(data)
		"ready":
			_on_ready_response(data)
		"poll_status":
			_on_poll_status_response(data)


# ── Panel A ────────────────────────────────────────────────────────────────


func _on_ip_text_changed(new_text: String) -> void:
	_matchmaker_ip = new_text
	_save_ip(new_text)


func _on_create_room_button_up() -> void:
	Audio.play_sfx(Audio.SFX.BUTTON_PRESS)
	error_label_a.text = ""
	if _matchmaker_ip == "":
		_handle_error("請輸入 Matchmaker Server 位置")
		return
	_post("/qiaohu/room", {}, "create_room")


func _on_create_room_response(data: Dictionary) -> void:
	if data.get("error") != null:
		_handle_error(_error_message(data.get("error", "")))
		return
	_room_code = data.get("code", "")
	_game_ip = data.get("game_ip", "")
	_game_port = data.get("game_port", 0)
	_player_id = data.get("player_id", "")

	print("[Matchmaker] Room created: ", _room_code, " game at ", _game_ip, ":", _game_port)

	var err := NetworkManager.join_server(_game_ip, _game_port)
	if err != OK:
		_handle_error("無法連線到遊戲伺服器")
		return

	code_label.text = _room_code
	_timer_b = 60
	_update_countdown_label_b()
	_show_panel(Page.B)
	_countdown_timer.start()
	_poll_timer.start()


func _on_join_room_button_up() -> void:
	Audio.play_sfx(Audio.SFX.BUTTON_PRESS)
	error_label_a.text = ""
	code_input.text = ""
	_show_panel(Page.C)


func _on_back_button_up() -> void:
	Audio.play_sfx(Audio.SFX.BUTTON_PRESS)
	_stop_all_timers()
	SceneTransition.transition_to(MENU_SCENE)


# ── Panel B ────────────────────────────────────────────────────────────────


func _update_countdown_label_b() -> void:
	countdown_b.text = "剩餘 " + str(_timer_b) + " 秒"


func _on_back_b_button_up() -> void:
	Audio.play_sfx(Audio.SFX.BUTTON_PRESS)
	_stop_all_timers()
	NetworkManager.stop_network()
	_show_panel(Page.A)


func _on_expire_b() -> void:
	_stop_all_timers()
	code_label.text = "房間已過期"
	countdown_b.text = "房間已過期"
	await get_tree().create_timer(3.0).timeout
	NetworkManager.stop_network()
	_show_panel(Page.A)


# ── Panel C ────────────────────────────────────────────────────────────────


func _on_confirm_join_button_up() -> void:
	Audio.play_sfx(Audio.SFX.BUTTON_PRESS)
	error_label_c.text = ""
	var code := code_input.text.strip_edges().to_upper()
	if code == "":
		_handle_error("請輸入房間號碼")
		return
	if _matchmaker_ip == "":
		_handle_error("請輸入 Matchmaker Server 位置")
		return
	_post("/qiaohu/join", {"code": code}, "join_room")


func _on_join_room_response(data: Dictionary) -> void:
	if data.get("error") != null:
		_handle_error(_error_message(data.get("error", "")))
		return
	_game_ip = data.get("game_ip", "")
	_game_port = data.get("game_port", 0)
	_player_id = data.get("player_id", "")
	_room_code = code_input.text.strip_edges().to_upper()

	print("[Matchmaker] Joined room ", _room_code, " game at ", _game_ip, ":", _game_port)

	var err := NetworkManager.join_server(_game_ip, _game_port)
	if err != OK:
		_handle_error("無法連線到遊戲伺服器")
		return

	_timer_d = 90
	_update_countdown_label_d()
	_update_status_label()
	_show_panel(Page.D)
	_countdown_timer.start()
	_poll_timer.start()


func _on_back_c_button_up() -> void:
	Audio.play_sfx(Audio.SFX.BUTTON_PRESS)
	_show_panel(Page.A)


# ── Panel D ────────────────────────────────────────────────────────────────


func _enter_panel_d() -> void:
	_timer_d = 90
	_update_countdown_label_d()
	_update_status_label()
	_update_agent_label()
	ready_button.disabled = false
	ready_button.text = "確認"
	_confirmed = false
	_countdown_timer.start()
	_poll_timer.start()


func _update_countdown_label_d() -> void:
	countdown_d.text = "剩餘 " + str(_timer_d) + " 秒"


func _update_status_label() -> void:
	if _confirmed:
		status_label.text = "已確認，等待對手..."
	else:
		status_label.text = "等待雙方確認..."


func _update_agent_label() -> void:
	if _selected_agent == "":
		agent_label.text = "Agent: 使用預設"
	else:
		agent_label.text = "Agent: " + _selected_agent.get_file()


func _on_choose_agent_button_up() -> void:
	Audio.play_sfx(Audio.SFX.BUTTON_PRESS)
	_open_file_dialog()


func _on_default_agent_button_up() -> void:
	Audio.play_sfx(Audio.SFX.BUTTON_PRESS)
	_selected_agent = ""
	_update_agent_label()


func _on_ready_button_up() -> void:
	Audio.play_sfx(Audio.SFX.BUTTON_PRESS)
	_confirmed = true
	ready_button.disabled = true
	ready_button.text = "已確認"
	_update_status_label()
	_post("/qiaohu/ready", {"code": _room_code, "player_id": _player_id}, "ready")


func _on_ready_response(data: Dictionary) -> void:
	var status: String = data.get("status", "")
	if status == "start":
		# Both ready — wait for next poll to trigger game start
		pass


func _on_back_d_button_up() -> void:
	Audio.play_sfx(Audio.SFX.BUTTON_PRESS)
	_stop_all_timers()
	NetworkManager.stop_network()
	_show_panel(Page.A)


func _on_expire_d() -> void:
	_stop_all_timers()
	status_label.text = "配對逾時"
	countdown_d.text = "配對逾時"
	await get_tree().create_timer(3.0).timeout
	NetworkManager.stop_network()
	_show_panel(Page.A)


# ── Polling ────────────────────────────────────────────────────────────────


func _on_poll_tick() -> void:
	if _pending_request != "":
		return
	_http_get("/qiaohu/status?code=" + _room_code, "poll_status")


func _on_poll_status_response(data: Dictionary) -> void:
	if data.get("error") != null:
		var error := data.get("error", "") as String
		if error == "room not found":
			_stop_all_timers()
			_handle_error("房間已失效")
			NetworkManager.stop_network()
			_show_panel(Page.A)
		return

	var player_count: int = data.get("player_count", 0)
	var game_started: bool = data.get("game_started", false)

	if _current_panel == Page.B and player_count >= 2:
		_poll_timer.stop()
		_enter_panel_d()

	if game_started:
		_stop_all_timers()
		Global.single_player = false
		Global.agent_file = _selected_agent
		Audio.play_sfx(Audio.SFX.BUTTON_PRESS)
		SceneTransition.transition_to(GAMEPLAY_SCENE)


# ── Countdown ──────────────────────────────────────────────────────────────


func _on_countdown_tick() -> void:
	if _current_panel == Page.B:
		_timer_b -= 1
		_update_countdown_label_b()
		if _timer_b <= 0:
			_countdown_timer.stop()
			_on_expire_b()
	elif _current_panel == Page.D:
		_timer_d -= 1
		_update_countdown_label_d()
		if _timer_d <= 0:
			_on_expire_d()


# ── Network disconnect ─────────────────────────────────────────────────────


func _on_server_disconnected() -> void:
	if _current_panel == Page.A:
		return
	_stop_all_timers()
	match _current_panel:
		Page.B, Page.C, Page.D:
			_handle_error("連線中斷")
			_show_panel(Page.A)


# ── Agent file dialog ──────────────────────────────────────────────────────


func _open_file_dialog() -> void:
	var initial_directory := _resolve_initial_directory()
	if _file_dialog == null:
		_file_dialog = FileDialog.new()
		_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
		_file_dialog.use_native_dialog = true
		_file_dialog.add_filter("*.py", "Python agent")
		_file_dialog.file_selected.connect(_on_agent_file_selected)
		add_child(_file_dialog)
	if _selected_agent != "" and FileAccess.file_exists(_selected_agent):
		_file_dialog.current_dir = _selected_agent.get_base_dir()
		_file_dialog.current_file = _selected_agent.get_file()
	else:
		_file_dialog.current_dir = initial_directory
		_file_dialog.current_file = ""
	_file_dialog.popup_centered_ratio(0.6)


func _on_agent_file_selected(path: String) -> void:
	_selected_agent = path
	_update_agent_label()


func _resolve_initial_directory() -> String:
	if OS.has_feature("editor"):
		var editor_candidate := ProjectSettings.globalize_path("res://").path_join(
			DEFAULT_AGENT_DIR
		)
		if DirAccess.dir_exists_absolute(editor_candidate):
			return editor_candidate
		return ProjectSettings.globalize_path("res://")

	var executable_base_dir := OS.get_executable_path().get_base_dir()
	if OS.has_feature("macos"):
		executable_base_dir = executable_base_dir.get_base_dir().get_base_dir().get_base_dir()
	var runtime_candidate := executable_base_dir.path_join(DEFAULT_AGENT_DIR)
	if DirAccess.dir_exists_absolute(runtime_candidate):
		return runtime_candidate
	return executable_base_dir


# ── Helpers ────────────────────────────────────────────────────────────────


func _stop_all_timers() -> void:
	_countdown_timer.stop()
	_poll_timer.stop()


func _error_message(error: String) -> String:
	match error:
		"room not found":
			return "房間不存在"
		"room expired":
			return "房間已過期"
		"no free ports":
			return "伺服器已滿，請稍後再試"
		"failed to start game server":
			return "伺服器啟動失敗"
		"invalid player_id":
			return "驗證失敗"
		"game already started":
			return "遊戲已開始"
	return "無法連線到伺服器"
