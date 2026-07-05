with open(
    "d:/2026_Challenge/Challenge2026/Scenes/menu/hidden_game.tscn",
    "r",
    encoding="utf-8",
) as f:
    text = f.read()

# Replace StyleBoxFlat_i6agr definition and add background StyleBox
old_style_def = """[sub_resource type="StyleBoxFlat" id="StyleBoxFlat_i6agr"]
bg_color = Color(1, 0, 0, 1)"""

new_style_def = """[sub_resource type="StyleBoxFlat" id="StyleBoxFlat_hp_bg"]
bg_color = Color(0.08, 0.0, 0.04, 0.7)
border_width_left = 3
border_width_top = 3
border_width_right = 3
border_width_bottom = 3
border_color = Color(0.2, 0.0, 0.1, 0.9)
corner_radius_top_left = 8
corner_radius_top_right = 8
corner_radius_bottom_right = 8
corner_radius_bottom_left = 8
shadow_color = Color(0, 0, 0, 0.6)
shadow_size = 10

[sub_resource type="StyleBoxFlat" id="StyleBoxFlat_i6agr"]
bg_color = Color(0.9, 0.1, 0.3, 1)
border_width_left = 2
border_width_top = 2
border_width_right = 2
border_width_bottom = 2
border_color = Color(1, 0.5, 0.6, 1)
corner_radius_top_left = 6
corner_radius_top_right = 6
corner_radius_bottom_right = 6
corner_radius_bottom_left = 6
shadow_color = Color(1, 0.1, 0.3, 0.5)
shadow_size = 12
anti_aliasing = true"""

text = text.replace(old_style_def, new_style_def)

# Add background style to BossHpBar
old_hpbar_prop = 'theme_override_styles/fill = SubResource("StyleBoxFlat_i6agr")'
new_hpbar_prop = 'theme_override_styles/background = SubResource("StyleBoxFlat_hp_bg")\ntheme_override_styles/fill = SubResource("StyleBoxFlat_i6agr")'

text = text.replace(old_hpbar_prop, new_hpbar_prop)

with open(
    "d:/2026_Challenge/Challenge2026/Scenes/menu/hidden_game.tscn",
    "w",
    encoding="utf-8",
) as f:
    f.write(text)

print("Updated HP Bar")
