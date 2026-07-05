import re

with open(
    "d:/2026_Challenge/Challenge2026/Scripts/menu/falling_note.gd",
    "r",
    encoding="utf-8",
) as f:
    text = f.read()

# Add trail_timer back
if "var trail_timer: float = 0.0" not in text:
    text = text.replace("var trail: Line2D\n", "var trail_timer: float = 0.0\n")

# Remove Line2D initialization
init_pattern = r"\s*trail = Line2D\.new\(\).*?move_child\(trail, 0\)"
text = re.sub(init_pattern, "", text, flags=re.DOTALL)

# Replace _process trail logic
process_pattern = r"\s*if is_instance_valid\(trail\):.*?trail\.remove_point\(0\)"
ghost_code = """
	# 生產流光拖尾 (殘影)，改回連續生成完美水平的矩形，以避免 Line2D 的法線傾斜問題
	trail_timer += delta
	if trail_timer >= 0.015:
		trail_timer = 0.0
		var phantom = ColorRect.new()
		phantom.size = $ColorRect.size
		phantom.position = $ColorRect.position
		phantom.modulate = $ColorRect.modulate
		phantom.modulate.a = 0.5
		
		var ghost = Node2D.new()
		ghost.add_child(phantom)
		get_parent().add_child(ghost)
		
		ghost.position = position
		ghost.scale = scale
		
		var tw = ghost.create_tween()
		tw.tween_property(ghost, "scale", Vector2(scale.x * 0.2, scale.y * 0.2), 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(phantom, "modulate:a", 0.0, 0.3)
		tw.tween_callback(ghost.queue_free)
"""
text = re.sub(process_pattern, ghost_code, text, flags=re.DOTALL)

# Remove trail fadeout in _trigger_judgment
trigger_pattern = r'\s*if is_instance_valid\(trail\):.*?modulate:a", 0\.0, 0\.06\)'
text = re.sub(trigger_pattern, "", text, flags=re.DOTALL)

with open(
    "d:/2026_Challenge/Challenge2026/Scripts/menu/falling_note.gd",
    "w",
    encoding="utf-8",
) as f:
    f.write(text)

print("Reverted to ghost trail")
