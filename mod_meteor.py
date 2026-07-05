import re

with open(
    "d:/2026_Challenge/Challenge2026/Scripts/menu/falling_note.gd",
    "r",
    encoding="utf-8",
) as f:
    text = f.read()

# Remove trail_timer
text = text.replace("var trail_timer: float = 0.0\n", "")
text = text.replace("var trail_timer: float = 0.0", "")

# Insert Line2D variable
text = text.replace("var player: Node2D\n", "var player: Node2D\nvar trail: Line2D\n")

# In init(), initialize the Line2D
init_idx = text.find("scale = Vector2(0.3, 0.3)")
end_init = text.find("\n", init_idx) + 1
init_addition = """
	trail = Line2D.new()
	trail.top_level = true
	trail.width = note_width * 0.3
	trail.joint_mode = Line2D.LINE_JOINT_ROUND
	trail.begin_cap_mode = Line2D.LINE_CAP_ROUND
	trail.end_cap_mode = Line2D.LINE_CAP_ROUND
	trail.antialiased = true
	
	var grad = Gradient.new()
	grad.add_point(0.0, Color(0.5, 1.5, 3.0, 0.0))
	grad.add_point(1.0, Color(0.5, 1.5, 3.0, 0.8))
	trail.gradient = grad
	
	var curve = Curve.new()
	curve.add_point(Vector2(0, 0.1))
	curve.add_point(Vector2(1, 1.0))
	trail.width_curve = curve
	
	add_child(trail)
	move_child(trail, 0)
"""
text = text[:end_init] + init_addition + text[end_init:]

# Remove ghost spawning in _process
ghost_pattern = r"# 生產流光拖尾.*?tw\.tween_callback\(ghost\.queue_free\)"
text = re.sub(ghost_pattern, "", text, flags=re.DOTALL)

# Add line point updating
process_idx = text.find("global_position.x = lerp(center_global_x, target_global_x, t)")
end_process = text.find("\n", process_idx) + 1
process_addition = """
	if is_instance_valid(trail):
		trail.width = note_width * scale.x
		trail.add_point(global_position)
		if trail.get_point_count() > 20:
			trail.remove_point(0)
"""
text = text[:end_process] + process_addition + text[end_process:]

# In _trigger_judgment, fade out the trail
trigger_idx = text.find(
    'tween.parallel().tween_property($ColorRect, "modulate:a", 0.0, 0.06)'
)
end_trigger = text.find("\n", trigger_idx) + 1
trigger_addition = """
	if is_instance_valid(trail):
		tween.parallel().tween_property(trail, "modulate:a", 0.0, 0.06)
"""
text = text[:end_trigger] + trigger_addition + text[end_trigger:]

with open(
    "d:/2026_Challenge/Challenge2026/Scripts/menu/falling_note.gd",
    "w",
    encoding="utf-8",
) as f:
    f.write(text)

print("Meteor trail applied to falling note!")
