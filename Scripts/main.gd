extends Node2D

const BROADCAST_VIEW_SCENE = preload("res://Scenes/broadcast_view.tscn")


func _enter_tree() -> void:
	var args := OS.get_cmdline_user_args()
	var startup_mode := NetworkManager.get_startup_mode(args)

	if startup_mode == "spectator":
		NetworkManager.set_local_role("spectator")
		var spectator_current_scene := get_node_or_null("CurrentScene")
		if spectator_current_scene != null:
			remove_child(spectator_current_scene)
			spectator_current_scene.queue_free()

		add_child(BROADCAST_VIEW_SCENE.instantiate())
		return

	if startup_mode != "server":
		return

	var current_scene := get_node_or_null("CurrentScene")
	if current_scene == null:
		return

	remove_child(current_scene)
	current_scene.queue_free()
