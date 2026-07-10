extends Node

@export_range(1, 100) var energy_amount := 10
@export_range(1, 100) var health_amount := 10
@export_range(0, 100) var initial_test_energy := 50

var _seeded_test_energy := false


func _ready() -> void:
	NetworkManager.energy_changed.connect(_on_energy_changed)
	NetworkManager.energy_rejected.connect(_on_energy_rejected)
	NetworkManager.health_changed.connect(_on_health_changed)
	NetworkManager.health_rejected.connect(_on_health_rejected)
	NetworkManager.connection_succeeded.connect(_seed_test_energy)

	_seed_test_energy()

	print(
		(
			"Network keyboard test ready: "
			+ "Z spend self energy, X spend opponent energy, "
			+ "C heal self, V heal opponent, B damage self, N damage opponent"
		)
	)
	_print_status()


func _seed_test_energy() -> void:
	if _seeded_test_energy or initial_test_energy <= 0:
		return

	var peer: MultiplayerPeer = multiplayer.multiplayer_peer
	if not (peer is OfflineMultiplayerPeer):
		if peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
			return

	NetworkManager.request_add_energy(initial_test_energy)
	_seeded_test_energy = true


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return

	match event.keycode:
		KEY_Z:
			NetworkManager.request_spend_energy(energy_amount)
			_accept_and_print("Z spend self energy")
		KEY_X:
			NetworkManager.request_spend_opponent_energy(energy_amount)
			_accept_and_print("X spend opponent energy")
		KEY_C:
			NetworkManager.request_heal_health(health_amount)
			_accept_and_print("C heal self")
		KEY_V:
			NetworkManager.request_heal_opponent_health(health_amount)
			_accept_and_print("V heal opponent")
		KEY_B:
			NetworkManager.request_damage_health(health_amount)
			_accept_and_print("B damage self")
		KEY_N:
			NetworkManager.request_damage_opponent_health(health_amount)
			_accept_and_print("N damage opponent")
		_:
			return


func _accept_and_print(action: String) -> void:
	get_viewport().set_input_as_handled()
	print("Network keyboard test action: %s" % action)
	_print_status.call_deferred()


func _print_status() -> void:
	var local_peer_id := multiplayer.get_unique_id()
	var opponent_peer_id := NetworkManager.get_opponent_peer_id()
	print(
		(
			(
				"Network keyboard test status: "
				+ "self=%d energy=%d health=%d | opponent=%d energy=%d health=%d"
			)
			% [
				local_peer_id,
				NetworkManager.get_energy(local_peer_id),
				NetworkManager.get_health(local_peer_id),
				opponent_peer_id,
				NetworkManager.get_energy(opponent_peer_id),
				NetworkManager.get_health(opponent_peer_id),
			]
		)
	)


func _on_energy_changed(peer_id: int, energy: int) -> void:
	print("Network keyboard test energy changed: peer=%d energy=%d" % [peer_id, energy])


func _on_energy_rejected(peer_id: int, reason: String) -> void:
	print("Network keyboard test energy rejected: peer=%d reason=%s" % [peer_id, reason])


func _on_health_changed(peer_id: int, health: int) -> void:
	print("Network keyboard test health changed: peer=%d health=%d" % [peer_id, health])


func _on_health_rejected(peer_id: int, reason: String) -> void:
	print("Network keyboard test health rejected: peer=%d reason=%s" % [peer_id, reason])
