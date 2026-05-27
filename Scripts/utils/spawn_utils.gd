class_name SpawnUtils


## Returns a Rect2 value indicating the area
static func get_arena_border(walls: Node) -> Rect2:
	var right_wall: StaticBody2D = walls.get_node("RightWall")
	var left_wall: StaticBody2D = walls.get_node("LeftWall")
	var up_wall: StaticBody2D = walls.get_node("UpWall")
	var down_wall: StaticBody2D = walls.get_node("DownWall")

	var left := left_wall.global_position.x
	var right := right_wall.global_position.x
	var top := up_wall.global_position.y
	var bottom := down_wall.global_position.y

	return Rect2(Vector2(left, top), Vector2(right - left, bottom - top))


## Returns a randomly-generated Vector2 coordinate inside rect
static func random_position_in_rect_area(rect: Rect2) -> Vector2:
	return Vector2(
		randf_range(rect.position.x, rect.end.x), randf_range(rect.position.y, rect.end.y)
	)


## Returns a randomly-generated Vector2 coordinate on rect's edges
static func random_position_on_rect_edge(rect: Rect2) -> Vector2:
	match randi() % 4:
		0:
			return Vector2(randf_range(rect.position.x, rect.end.x), rect.position.y)
		1:
			return Vector2(randf_range(rect.position.x, rect.end.x), rect.end.y)
		2:
			return Vector2(rect.position.x, randf_range(rect.position.y, rect.end.y))
		3:
			return Vector2(rect.end.x, randf_range(rect.position.y, rect.end.y))
	return rect.position
