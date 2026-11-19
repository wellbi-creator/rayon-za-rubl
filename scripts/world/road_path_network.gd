extends RefCounted
class_name RoadPathNetwork

const Grid = preload("res://scripts/world/isometric_grid.gd")

## Lightweight graph for the currently painted cross-shaped road network.
## It returns world-space waypoints; it does not simulate vehicles or traffic.

var map_width: int = 0
var map_height: int = 0
var horizontal_road_y: int = 0
var vertical_road_x: int = 0
var _road_cells: Dictionary = {}

func configure(width: int, height: int, road_y: int, road_x: int) -> void:
	map_width = maxi(0, width)
	map_height = maxi(0, height)
	horizontal_road_y = road_y
	vertical_road_x = road_x
	_road_cells.clear()
	if horizontal_road_y >= 0 and horizontal_road_y < map_height:
		for x in range(map_width):
			_road_cells[Vector2i(x, horizontal_road_y)] = true
	if vertical_road_x >= 0 and vertical_road_x < map_width:
		for y in range(map_height):
			_road_cells[Vector2i(vertical_road_x, y)] = true

func is_road_cell(cell: Vector2i) -> bool:
	return _road_cells.has(cell)

func get_road_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for cell in _road_cells.keys():
		cells.append(cell)
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		if a.y == b.y:
			return a.x < b.x
		return a.y < b.y
	)
	return cells

func get_route(start_cell: Vector2i, end_cell: Vector2i, tile_size: Vector2 = Vector2(128.0, 64.0)) -> Array[Vector2]:
	var route: Array[Vector2] = []
	if not is_road_cell(start_cell) or not is_road_cell(end_cell):
		return route
	if start_cell == end_cell:
		route.append(Grid.grid_to_world(start_cell, tile_size))
		return route
	var frontier: Array[Vector2i] = [start_cell]
	var came_from: Dictionary = {start_cell: start_cell}
	var directions: Array[Vector2i] = [
		Vector2i(-1, 0), Vector2i(0, -1),
		Vector2i(0, 1), Vector2i(1, 0)
	]
	var found := false
	while not frontier.is_empty():
		var current: Vector2i = frontier.pop_front()
		if current == end_cell:
			found = true
			break
		for direction in directions:
			var next_cell := current + direction
			if not is_road_cell(next_cell) or came_from.has(next_cell):
				continue
			came_from[next_cell] = current
			frontier.append(next_cell)
	if not found:
		return route
	var reversed_cells: Array[Vector2i] = []
	var cursor := end_cell
	while cursor != start_cell:
		reversed_cells.append(cursor)
		cursor = came_from[cursor]
	reversed_cells.append(start_cell)
	reversed_cells.reverse()
	for cell in reversed_cells:
		route.append(Grid.grid_to_world(cell, tile_size))
	return route
