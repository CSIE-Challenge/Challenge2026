extends Control

enum Page { A, B, C, D }
enum MarqueeState { PAUSED_START, SCROLLING, SCROLL_BACK, PAUSED_END, STOPPED }

const MENU_SCENE := "res://Scenes/menu.tscn"
const GAMEPLAY_SCENE := "res://Scenes/gameplay.tscn"
const SETTINGS_PATH := "user://player_settings.cfg"
const SETTINGS_SECTION := "matchmaker"
const DEFAULT_AGENT_DIR := "agent/scripts"
const UPLOADED_AGENT_DIR := "uploaded_agents"
const MAX_AGENT_BYTES := 262144

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
var _poll_pending := false

var _countdown_text_d: String = ""
var _status_text_d: String = ""

var _pause_duration: float = 2.0
var _scroll_speed: float = 80.0
var _current_marquee_state: MarqueeState = MarqueeState.STOPPED
var _current_offset: float = 0.0
var _max_offset: float = 0.0
var _pause_timer: float = 0.0

@onready var ip_input: LineEdit = $Panel/Margins/Content/Panels/PanelA/IPContainer/IPInput
@onready var panel_a: VBoxContainer = $Panel/Margins/Content/Panels/PanelA
@onready var panel_b: VBoxContainer = $Panel/Margins/Content/Panels/PanelB
@onready var panel_c: VBoxContainer = $Panel/Margins/Content/Panels/PanelC
@onready var panel_d: VBoxContainer = $Panel/Margins/Content/Panels/PanelD

@onready var error_label_a: Label = $Panel/Margins/Content/Panels/PanelA/IPContainer/ErrorLabel
@onready var error_label_c: Label = $Panel/Margins/Content/Panels/PanelC/CodeContainer/ErrorLabel

@onready var create_room_button: Button = $Panel/Margins/Content/Panels/PanelA/CreateRoomButton
@onready var join_room_button: Button = $Panel/Margins/Content/Panels/PanelA/JoinRoomButton
@onready var countdown_b: Label = $Panel/Margins/Content/Panels/PanelB/CountdownLabel
@onready var code_label: Label = $Panel/Margins/Content/Panels/PanelB/CodeLabel
@onready var status_label: Label = $Panel/Margins/Content/Panels/PanelD/StatusLabel
@onready var marquee_node: Control = $Panel/Margins/Content/Panels/PanelD/MarqueeText
@onready var agent_label: Label = $Panel/Margins/Content/Panels/PanelD/MarqueeText/AgentLabel
@onready var ready_button: Button = $Panel/Margins/Content/Panels/PanelD/HBoxContainer/ReadyButton

@onready var code_input: LineEdit = $Panel/Margins/Content/Panels/PanelC/CodeContainer/CodeInput

@onready var http_request: HTTPRequest = $HTTPRequest
@onready var poll_http_request: HTTPRequest = $PollHTTPRequest


func _ready() -> void:
	Audio.set_bgm(Audio.BGM.MENU)
	_matchmaker_ip = _load_ip()
	ip_input.text = _matchmaker_ip
	if _matchmaker_ip != "":
		create_room_button.disabled = false
		join_room_button.disabled = false

	_poll_timer = Timer.new()
	_poll_timer.wait_time = 1.0 / 15.0
	_poll_timer.one_shot = false
	_poll_timer.timeout.connect(_on_poll_tick)
	add_child(_poll_timer)

	_countdown_timer = Timer.new()
	_countdown_timer.wait_time = 1.0
	_countdown_timer.one_shot = false
	_countdown_timer.timeout.connect(_on_countdown_tick)
	add_child(_countdown_timer)

	_show_panel(Page.A)
	ip_input.grab_focus()

	code_input.gui_input.connect(_on_code_input_gui_input)

	http_request.request_completed.connect(_on_request_completed)
	poll_http_request.request_completed.connect(_on_poll_request_completed)

	NetworkManager.server_disconnected.connect(_on_server_disconnected)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and not event.pressed and event.keycode == KEY_ESCAPE:
		match _current_panel:
			Page.A:
				_on_back_button_up()
			Page.B:
				_on_back_b_button_up()
			Page.C:
				_on_back_c_button_up()
			Page.D:
				# _on_back_d_button_up()
				pass
	elif event is InputEventKey and not event.pressed and event.keycode == KEY_ENTER:
		match _current_panel:
			Page.C:
				_on_confirm_join_button_up()
			Page.D:
				# _on_ready_button_up()
				pass


func _process(delta: float) -> void:
	match _current_marquee_state:
		MarqueeState.PAUSED_START:
			_pause_timer += delta
			if _pause_timer >= _pause_duration:
				_pause_timer = 0.0
				_current_marquee_state = MarqueeState.SCROLLING

		MarqueeState.SCROLLING:
			_current_offset += _scroll_speed * delta
			agent_label.position.x = -1.0 * _current_offset
			if _current_offset >= _max_offset:
				agent_label.position.x = -1.0 * _max_offset
				_current_marquee_state = MarqueeState.PAUSED_END

		MarqueeState.PAUSED_END:
			_pause_timer += delta
			if _pause_timer >= _pause_duration:
				_current_marquee_state = MarqueeState.SCROLL_BACK

		MarqueeState.SCROLL_BACK:
			_current_offset -= _scroll_speed * 25 * delta
			agent_label.position.x = -1.0 * _current_offset
			if _current_offset <= 0:
				agent_label.position.x = 0
				_reset_marquee()


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


func _show_panel(panel: Page) -> void:
	_current_panel = panel

	if panel == Page.A:
		error_label_a.visible = false
		error_label_a.text = ""
	elif panel == Page.C:
		error_label_c.visible = false
		error_label_c.text = ""

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


func _http_get(path: String, _tag: String) -> void:
	_poll_pending = true
	var url := "http://" + _matchmaker_ip + path
	var err := poll_http_request.request(url)
	if err != OK:
		_poll_pending = false
		_handle_error("HTTP request failed")


func _handle_error(msg: String) -> void:
	match _current_panel:
		Page.A:
			error_label_a.visible = true
			error_label_a.text = msg
		Page.C:
			error_label_c.visible = true
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


func _on_poll_request_completed(
	result: int, _code: int, _headers: PackedStringArray, body: PackedByteArray
) -> void:
	_poll_pending = false
	var body_str := body.get_string_from_utf8()

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

	_on_poll_status_response(data)


# ── Panel A ────────────────────────────────────────────────────────────────


func _on_ip_text_changed(new_text: String) -> void:
	if new_text == "":
		create_room_button.disabled = true
		join_room_button.disabled = true
	else:
		create_room_button.disabled = false
		join_room_button.disabled = false
	_matchmaker_ip = new_text
	_save_ip(new_text)


func _on_create_room_button_up() -> void:
	Audio.play_sfx(Audio.SFX.BUTTON_PRESS)
	if _matchmaker_ip == "":
		_handle_error("Please enter a server address")
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
		_handle_error("Cannot connect to server")
		return

	code_label.text = _room_code
	_timer_b = 60
	_update_countdown_label_b()
	_show_panel(Page.B)
	_countdown_timer.start()
	_poll_timer.start()


func _on_join_room_button_up() -> void:
	Audio.play_sfx(Audio.SFX.BUTTON_PRESS)
	code_input.text = ""
	_show_panel(Page.C)
	code_input.grab_focus()


func _on_back_button_up() -> void:
	Audio.play_sfx(Audio.SFX.BUTTON_PRESS)
	_stop_all_timers()
	SceneTransition.transition_to(MENU_SCENE)


# ── Panel B ────────────────────────────────────────────────────────────────


func _update_countdown_label_b() -> void:
	countdown_b.text = "Time Remaining: " + str(_timer_b) + "s"


func _on_back_b_button_up() -> void:
	Audio.play_sfx(Audio.SFX.BUTTON_PRESS)
	_stop_all_timers()
	NetworkManager.stop_network()
	_show_panel(Page.A)


func _on_expire_b() -> void:
	_stop_all_timers()
	code_label.text = "Room expired"
	countdown_b.text = "Room expired"
	await get_tree().create_timer(3.0).timeout
	NetworkManager.stop_network()
	_show_panel(Page.A)


# ── Panel C ────────────────────────────────────────────────────────────────


func _on_code_input_gui_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ENTER:
		get_viewport().set_input_as_handled()


func _on_code_text_changed(new_text: String) -> void:
	var caret_pos = code_input.caret_column
	code_input.text = new_text.to_upper()
	code_input.caret_column = caret_pos


func _on_confirm_join_button_up() -> void:
	Audio.play_sfx(Audio.SFX.BUTTON_PRESS)
	var code := code_input.text.strip_edges().to_upper()
	if code == "":
		_handle_error("Please enter a room code")
		return
	if _matchmaker_ip == "":
		_handle_error("Please enter a server address")
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
		_handle_error("Unable to connect to server")
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
	_show_panel(Page.D)
	_timer_d = 90
	_update_countdown_label_d()
	_update_status_label()
	_update_agent_label()
	ready_button.disabled = false
	ready_button.text = "Confirm"
	_confirmed = false
	_countdown_timer.start()
	_poll_timer.start()


func _update_countdown_label_d() -> void:
	_countdown_text_d = str(_timer_d) + "s"
	status_label.text = _countdown_text_d + " - " + _status_text_d


func _update_status_label() -> void:
	if _confirmed:
		_status_text_d = "Waiting for Opponent..."
	else:
		_status_text_d = "Waiting for Players..."
	status_label.text = _countdown_text_d + " - " + _status_text_d


func _update_agent_label() -> void:
	if _selected_agent == "":
		agent_label.text = "Default Agent"
	else:
		agent_label.text = _selected_agent
	await get_tree().process_frame  # wait for the label to change size
	await get_tree().process_frame
	_reset_marquee()


func _on_choose_agent_button_up() -> void:
	Audio.play_sfx(Audio.SFX.BUTTON_PRESS)
	_open_file_dialog()


func _on_default_agent_button_up() -> void:
	Audio.play_sfx(Audio.SFX.BUTTON_PRESS)
	_selected_agent = ""
	_update_agent_label()


func _on_ready_button_up() -> void:
	Audio.play_sfx(Audio.SFX.BUTTON_PRESS)
	var agent_payload := _build_agent_upload_payload()
	if agent_payload.get("error", "") != "":
		_handle_error(agent_payload["error"])
		return

	_confirmed = true
	ready_button.disabled = true
	ready_button.text = "Confirmed"
	_update_status_label()
	_post(
		"/qiaohu/ready",
		{
			"code": _room_code,
			"player_id": _player_id,
			"agent": agent_payload.get("agent"),
			"skin": PlayerData.equipped_skin,
		},
		"ready"
	)


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
	status_label.text = "Matchmaking timed out"
	await get_tree().create_timer(3.0).timeout
	NetworkManager.stop_network()
	_show_panel(Page.A)


func _reset_marquee():
	_current_offset = 0
	_pause_timer = 0
	_max_offset = agent_label.get_minimum_size().x - marquee_node.size.x

	agent_label.position = Vector2(0, 0)
	if _max_offset <= 0:
		agent_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_current_marquee_state = MarqueeState.STOPPED
	else:
		agent_label.set_anchors_and_offsets_preset(PRESET_LEFT_WIDE)
		_current_marquee_state = MarqueeState.PAUSED_START
		_scroll_speed = (_max_offset) / (_max_offset + 700) * 235


# ── Polling ────────────────────────────────────────────────────────────────


func _on_poll_tick() -> void:
	if _poll_pending:
		return
	_http_get("/qiaohu/status?code=%s&player_id=%s" % [_room_code, _player_id], "poll_status")


func _on_poll_status_response(data: Dictionary) -> void:
	if data.get("error") != null:
		var error := data.get("error", "") as String
		if error == "room not found":
			_stop_all_timers()
			_handle_error("Room no longer available")
			NetworkManager.stop_network()
			_show_panel(Page.A)
		return

	var player_count: int = data.get("player_count", 0)
	var game_started: bool = data.get("game_started", false)

	if _current_panel == Page.B and player_count >= 2:
		_poll_timer.stop()
		_enter_panel_d()

	if game_started:
		var agent_path: Variant = _save_match_agent(data.get("opponent_agent"))
		if agent_path == null:
			return

		_stop_all_timers()
		NetworkManager.cancel_ready_timeout.rpc_id(1)
		Global.single_player = false
		Global.agent_file = str(agent_path)
		Global.skin_override = str(data.get("match_skin", ""))
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
			_handle_error("Connection lost")
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


func _build_agent_upload_payload() -> Dictionary:
	if _selected_agent == "":
		return {"agent": null, "error": ""}
	if not FileAccess.file_exists(_selected_agent):
		return {"agent": null, "error": "Selected agent file does not exist"}

	var bytes := FileAccess.get_file_as_bytes(_selected_agent)
	if bytes.is_empty() and FileAccess.get_open_error() != OK:
		return {"agent": null, "error": "Unable to read selected agent"}
	if bytes.size() > MAX_AGENT_BYTES:
		return {"agent": null, "error": "Selected agent is too large"}

	print("[Matchmaker] Uploading agent %s (%d bytes)" % [_selected_agent, bytes.size()])
	return {
		"agent":
		{
			"filename": _selected_agent.get_file(),
			"source": bytes.get_string_from_utf8(),
		},
		"error": "",
	}


func _save_match_agent(agent_value: Variant) -> Variant:
	if agent_value == null:
		return ""
	if typeof(agent_value) != TYPE_DICTIONARY:
		_handle_error("Invalid agent from server")
		return null

	var agent_data: Dictionary = agent_value
	var source := str(agent_data.get("source", ""))
	if source == "":
		return ""

	var root_dir := DirAccess.open("user://")
	if root_dir == null or root_dir.make_dir_recursive(UPLOADED_AGENT_DIR) != OK:
		_handle_error("Unable to prepare agent directory")
		return null

	var filename := _safe_agent_filename(str(agent_data.get("filename", "agent.py")))
	var path := (
		"user://%s/%s_%s_%s"
		% [
			UPLOADED_AGENT_DIR,
			_safe_agent_filename(_room_code),
			_safe_agent_filename(_player_id),
			filename,
		]
	)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_handle_error("Unable to save agent")
		return null
	file.store_string(source)
	file.close()
	var global_path := ProjectSettings.globalize_path(path)
	print("[Matchmaker] Saved match agent to %s" % global_path)
	return global_path


func _safe_agent_filename(value: String) -> String:
	const ALLOWED := "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_.-"
	var safe := ""
	for index in value.length():
		var character := value.substr(index, 1)
		if ALLOWED.contains(character):
			safe += character
		else:
			safe += "_"
	if safe == "":
		return "agent.py"
	return safe


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
			return "Room does not exist"
		"room expired":
			return "Room expired"
		"no free ports":
			return "Server is full, please try again later"
		"failed to start game server":
			return "Failed to start game server"
		"invalid player_id":
			return "Authentication failed"
		"game already started":
			return "Game has already started"
	return "Unable to connect to server"
