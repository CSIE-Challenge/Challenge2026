import re

with open(
    "d:/2026_Challenge/Challenge2026/Scenes/menu/hidden_game.tscn",
    "r",
    encoding="utf-8",
) as f:
    text = f.read()

# Replace bg stylebox colors to pure black (for shader parsing)
text = text.replace(
    "bg_color = Color(0.08, 0.0, 0.04, 0.7)", "bg_color = Color(0, 0, 0, 1)"
)
# Remove border and shadow from bg stylebox since shader takes over
text = re.sub(r"border_width_.*?\n", "", text)
text = re.sub(r"border_color = Color\(.*?\)\n", "", text)
text = re.sub(r"shadow_color = Color\(.*?\)\n", "", text)
text = re.sub(r"shadow_size = .*?\n", "", text)

# Replace fill stylebox colors to pure red
text = text.replace(
    "bg_color = Color(0.9, 0.1, 0.3, 1)", "bg_color = Color(1, 0, 0, 1)"
)

# Insert the shader resource if not already there
if "boss_hp_bar.gdshader" not in text:
    last_ext_idx = text.rfind("[ext_resource")
    end_of_last_ext = text.find("]", last_ext_idx) + 1
    insert_ext = '\n[ext_resource type="Shader" path="res://Shaders/boss_hp_bar.gdshader" id="200_hp"]'
    text = text[:end_of_last_ext] + insert_ext + text[end_of_last_ext:]

# Insert the ShaderMaterial subresource
if "ShaderMaterial_hp" not in text:
    first_sub_idx = text.find("[sub_resource")
    insert_sub = '[sub_resource type="ShaderMaterial" id="ShaderMaterial_hp"]\nshader = ExtResource("200_hp")\n\n'
    text = text[:first_sub_idx] + insert_sub + text[first_sub_idx:]

# Insert the material to BossHpBar node
if 'material = SubResource("ShaderMaterial_hp")' not in text:
    hpbar_idx = text.find('[node name="BossHpBar"')
    end_of_hpbar = text.find("]", hpbar_idx) + 1
    insert_mat = '\nmaterial = SubResource("ShaderMaterial_hp")'
    text = text[:end_of_hpbar] + insert_mat + text[end_of_hpbar:]

with open(
    "d:/2026_Challenge/Challenge2026/Scenes/menu/hidden_game.tscn",
    "w",
    encoding="utf-8",
) as f:
    f.write(text)

print("Applied shader to HP Bar")
