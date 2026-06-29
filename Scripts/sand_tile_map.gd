extends TileMapLayer

var all_sand_tiles: Array[Vector2i] = []


func _ready():
	for x in range(4):
		for y in range(4):
			all_sand_tiles.append(Vector2i(x, y))
	randomize_beach()


func randomize_beach():
	var used_cells = get_used_cells()
	var source_id = 0
	if used_cells.size() > 0:
		source_id = get_cell_source_id(used_cells[0])
	for cell in used_cells:
		var random_tile = all_sand_tiles.pick_random()
		set_cell(cell, source_id, random_tile)
