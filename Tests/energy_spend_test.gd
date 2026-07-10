extends Node

@export_range(1, 100) var spend_amount := 10
@export var spend_key: Key = KEY_P


func _ready() -> void:
	NetworkManager.energy_rejected.connect(_on_energy_rejected)


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode != spend_key and event.physical_keycode != spend_key:
		return

	get_viewport().set_input_as_handled()
	print("Spend-energy test requested: %d" % spend_amount)
	NetworkManager.request_spend_energy(spend_amount)


func _on_energy_rejected(peer_id: int, reason: String) -> void:
	if peer_id == multiplayer.get_unique_id():
		print("Spend-energy test rejected: %s" % reason)
