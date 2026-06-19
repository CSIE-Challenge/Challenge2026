extends Node2D


func _enter_tree() -> void:
	if NetworkManager.get_startup_mode(OS.get_cmdline_user_args()) != "server":
		return

	var current_scene := get_node_or_null("CurrentScene")
	if current_scene == null:
		return

	remove_child(current_scene)
	current_scene.queue_free()
