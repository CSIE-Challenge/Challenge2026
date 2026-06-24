extends Control

var peer_to_panel: Dictionary = {}

@onready var left_panel: Control = $HBoxContainer/LeftPanel
@onready var right_panel: Control = $HBoxContainer/RightPanel


func _ready() -> void:
	NetworkManager.set_local_role("spectator")
	NetworkManager.broadcast_state_changed.connect(_on_broadcast_state_changed)


func _on_broadcast_state_changed(peer_id: int, state: Dictionary) -> void:
	if not peer_to_panel.has(peer_id):
		if peer_to_panel.size() == 0:
			peer_to_panel[peer_id] = left_panel
		elif peer_to_panel.size() == 1:
			peer_to_panel[peer_id] = right_panel
		else:
			return

	peer_to_panel[peer_id].set_peer_state(peer_id, state)
