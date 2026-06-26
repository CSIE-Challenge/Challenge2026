extends Node2D


func _enter_tree() -> void:
	print("[Main] _enter_tree() — removing gameplay scene in ~server~ mode")
	if NetworkManager.get_startup_mode(OS.get_cmdline_user_args()) != "server":
		print("[Main] keeping gameplay scene (not server mode)")
		return

	var current_scene := get_node_or_null("CurrentScene")
	if current_scene == null:
		return

	remove_child(current_scene)
	current_scene.queue_free()
