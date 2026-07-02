import re

with open(
    "d:/2026_Challenge/Challenge2026/Scenes/menu/skin_shop.tscn", "r", encoding="utf-8"
) as f:
    text = f.read()

# Insert ext_resource after the last ext_resource
last_ext_idx = text.rfind("[ext_resource")
end_of_last_ext = text.find("]", last_ext_idx) + 1
insert_str = '\n[ext_resource type="Resource" uid="uid://amongus" path="res://Data/Skins/among_us_skin.tres" id="21_amongus"]'
text = text[:end_of_last_ext] + insert_str + text[end_of_last_ext:]

# Append to all_skins array
all_skins_pattern = r'(all_skins = Array\[ExtResource\("2_h3ndm"\)\]\(\[.*?)(?=\]\))'
match = re.search(all_skins_pattern, text)
if match:
    new_all_skins = match.group(1) + ', ExtResource("21_amongus")'
    text = text[: match.start()] + new_all_skins + text[match.end() :]
else:
    print("Failed to find all_skins")

with open(
    "d:/2026_Challenge/Challenge2026/Scenes/menu/skin_shop.tscn", "w", encoding="utf-8"
) as f:
    f.write(text)

print("Done")
