extends Control

const GAMEPLAY_SCENE := "res://Scenes/gameplay.tscn"

var _local_ready := false

@onready var status_label: Label = $Panel/VBoxContainer/StatusLabel
@onready var detail_label: Label = $Panel/VBoxContainer/DetailLabel
@onready var ready_button: Button = $Panel/VBoxContainer/ReadyButton


func _ready() -> void:
	Global.single_player = false
	Global.agent_file = ""
	ready_button.disabled = true

	_connect_network_signals()
	_start_client_connection()
	_update_status()


func _exit_tree() -> void:
	_disconnect_network_signals()


func _connect_network_signals() -> void:
	var player_count_changed := NetworkManager.multiplayer_player_count_changed
	if not NetworkManager.connection_succeeded.is_connected(_on_connection_succeeded):
		NetworkManager.connection_succeeded.connect(_on_connection_succeeded)
	if not NetworkManager.connection_failed.is_connected(_on_connection_failed):
		NetworkManager.connection_failed.connect(_on_connection_failed)
	if not NetworkManager.server_disconnected.is_connected(_on_server_disconnected):
		NetworkManager.server_disconnected.connect(_on_server_disconnected)
	if not NetworkManager.player_connected.is_connected(_on_player_list_changed):
		NetworkManager.player_connected.connect(_on_player_list_changed)
	if not NetworkManager.player_disconnected.is_connected(_on_player_list_changed):
		NetworkManager.player_disconnected.connect(_on_player_list_changed)
	if not player_count_changed.is_connected(_on_multiplayer_player_count_changed):
		player_count_changed.connect(_on_multiplayer_player_count_changed)
	if not NetworkManager.multiplayer_ready_changed.is_connected(_on_multiplayer_ready_changed):
		NetworkManager.multiplayer_ready_changed.connect(_on_multiplayer_ready_changed)
	if not NetworkManager.multiplayer_match_started.is_connected(_on_multiplayer_match_started):
		NetworkManager.multiplayer_match_started.connect(_on_multiplayer_match_started)


func _disconnect_network_signals() -> void:
	var player_count_changed := NetworkManager.multiplayer_player_count_changed
	if NetworkManager.connection_succeeded.is_connected(_on_connection_succeeded):
		NetworkManager.connection_succeeded.disconnect(_on_connection_succeeded)
	if NetworkManager.connection_failed.is_connected(_on_connection_failed):
		NetworkManager.connection_failed.disconnect(_on_connection_failed)
	if NetworkManager.server_disconnected.is_connected(_on_server_disconnected):
		NetworkManager.server_disconnected.disconnect(_on_server_disconnected)
	if NetworkManager.player_connected.is_connected(_on_player_list_changed):
		NetworkManager.player_connected.disconnect(_on_player_list_changed)
	if NetworkManager.player_disconnected.is_connected(_on_player_list_changed):
		NetworkManager.player_disconnected.disconnect(_on_player_list_changed)
	if player_count_changed.is_connected(_on_multiplayer_player_count_changed):
		player_count_changed.disconnect(_on_multiplayer_player_count_changed)
	if NetworkManager.multiplayer_ready_changed.is_connected(_on_multiplayer_ready_changed):
		NetworkManager.multiplayer_ready_changed.disconnect(_on_multiplayer_ready_changed)
	if NetworkManager.multiplayer_match_started.is_connected(_on_multiplayer_match_started):
		NetworkManager.multiplayer_match_started.disconnect(_on_multiplayer_match_started)


func _start_client_connection() -> void:
	var args := OS.get_cmdline_user_args()
	var address := NetworkManager.get_server_address(args)
	var port := NetworkManager.get_server_port(args)
	NetworkManager.join_server(address, port)


func _on_connection_succeeded() -> void:
	_update_status()


func _on_connection_failed() -> void:
	status_label.text = "連線失敗"
	detail_label.text = "請確認 server 已啟動，或用 --connect/--port 指定正確位置。"
	ready_button.disabled = true


func _on_server_disconnected() -> void:
	status_label.text = "已與 server 斷線"
	detail_label.text = "請返回選單重新連線。"
	ready_button.disabled = true


func _on_player_list_changed(_peer_id: int) -> void:
	_update_status()


func _on_multiplayer_ready_changed(_peer_id: int, _is_ready: bool) -> void:
	_update_status()


func _on_multiplayer_player_count_changed(_player_count: int) -> void:
	_update_status()


func _on_multiplayer_match_started() -> void:
	SceneTransition.transition_to(GAMEPLAY_SCENE)


func _on_ready_button_button_up() -> void:
	if ready_button.disabled:
		return

	Audio.play_sfx(Audio.SFX.BUTTON_PRESS)
	_local_ready = true
	ready_button.disabled = true
	NetworkManager.request_multiplayer_ready()
	_update_status()


func _on_back_button_button_up() -> void:
	Audio.play_sfx(Audio.SFX.BUTTON_PRESS)
	NetworkManager.stop_network()
	SceneTransition.transition_to("res://Scenes/menu.tscn")


func _update_status() -> void:
	var peer := multiplayer.multiplayer_peer
	var connected := peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED
	var player_count := NetworkManager.get_multiplayer_player_count()
	var has_required_players := connected and NetworkManager.has_required_multiplayer_players()

	if not connected:
		status_label.text = "連線中..."
		detail_label.text = "等待連線到 server。"
		ready_button.disabled = true
		return

	if not has_required_players:
		status_label.text = "已連線，等待另一位玩家"
		detail_label.text = (
			"Local Peer: %d | Players: %d/2" % [multiplayer.get_unique_id(), player_count]
		)
		ready_button.disabled = true
		return

	status_label.text = "兩位玩家已連線"
	detail_label.text = (
		"Local Peer: %d | Players: %d/2" % [multiplayer.get_unique_id(), player_count]
	)
	ready_button.disabled = _local_ready
	if _local_ready:
		ready_button.text = "等待對方 Ready..."
	else:
		ready_button.text = "Ready"
