with open(
    "d:/2026_Challenge/Challenge2026/Scenes/menu/hidden_game.tscn",
    "r",
    encoding="utf-8",
) as f:
    text = f.read()

# Insert ext_resource
last_ext_idx = text.rfind("[ext_resource")
end_of_last_ext = text.find("]", last_ext_idx) + 1
insert_ext = '\n[ext_resource type="Shader" path="res://Shaders/hidden_game_bg.gdshader" id="100_bg"]'
text = text[:end_of_last_ext] + insert_ext + text[end_of_last_ext:]

# Insert sub_resource
first_sub_idx = text.find("[sub_resource")
insert_sub = '[sub_resource type="ShaderMaterial" id="ShaderMaterial_bg"]\nshader = ExtResource("100_bg")\n\n'
text = text[:first_sub_idx] + insert_sub + text[first_sub_idx:]

# Insert material to Panel
panel_node_idx = text.find('[node name="Panel" type="Panel"')
end_of_panel_node = text.find("]", panel_node_idx) + 1
insert_mat = '\nmaterial = SubResource("ShaderMaterial_bg")'
text = text[:end_of_panel_node] + insert_mat + text[end_of_panel_node:]

with open(
    "d:/2026_Challenge/Challenge2026/Scenes/menu/hidden_game.tscn",
    "w",
    encoding="utf-8",
) as f:
    f.write(text)

print("Shader applied to hidden_game.tscn")
