extends RefCounted
class_name RoadPathNetwork

const Grid = preload("res://scripts/world/isometric_grid.gd")

## Editable, connected road graph. Rendering and pathfinding read the same cell set.

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

func is_cell_in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < map_width and cell.y < map_height

func add_road_cell(cell: Vector2i) -> bool:
	if not is_cell_in_bounds(cell) or is_road_cell(cell):
		return false
	if not _road_cells.is_empty() and _get_road_neighbor_count(cell) == 0:
		return false
	_road_cells[cell] = true
	return true

func remove_road_cell(cell: Vector2i) -> bool:
	if not is_road_cell(cell):
		return false
	_road_cells.erase(cell)
	if not _are_all_road_cells_connected(_road_cells):
		_road_cells[cell] = true
		return false
	return true

func _get_road_neighbor_count(cell: Vector2i) -> int:
	var count := 0
	for direction in _get_directions():
		if is_road_cell(cell + direction):
			count += 1
	return count

func _get_directions() -> Array[Vector2i]:
	return [
		Vector2i(-1, 0), Vector2i(0, -1),
		Vector2i(0, 1), Vector2i(1, 0)
	]

func _are_all_road_cells_connected(cells: Dictionary) -> bool:
	if cells.size() <= 1:
		return true
	var first_cell: Vector2i = cells.keys()[0]
	var visited: Dictionary = {first_cell: true}
	var frontier: Array[Vector2i] = [first_cell]
	while not frontier.is_empty():
		var current: Vector2i = frontier.pop_front()
		for direction in _get_directions():
			var next_cell := current + direction
			if cells.has(next_cell) and not visited.has(next_cell):
				visited[next_cell] = true
				frontier.append(next_cell)
	return visited.size() == cells.size()

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

func get_save_data() -> Dictionary:
	var saved_cells: Array[Dictionary] = []
	for cell in get_road_cells():
		saved_cells.append({"x": cell.x, "y": cell.y})
	return {
		"map_width": map_width,
		"map_height": map_height,
		"cells": saved_cells
	}

func load_save_data(data: Dictionary) -> bool:
	var saved_width := int(data.get("map_width", map_width))
	var saved_height := int(data.get("map_height", map_height))
	var saved_cells: Variant = data.get("cells", [])
	if saved_width != map_width or saved_height != map_height or not saved_cells is Array:
		return false
	var previous_cells := _road_cells.duplicate()
	_road_cells.clear()
	for entry in saved_cells:
		if not entry is Dictionary:
			_road_cells = previous_cells
			return false
		var cell := Vector2i(int(entry.get("x", -1)), int(entry.get("y", -1)))
		if not add_road_cell(cell):
			_road_cells = previous_cells
			return false
	if not _are_all_road_cells_connected(_road_cells):
		_road_cells = previous_cells
		return false
	return true

func get_route(start_cell: Vector2i, end_cell: Vector2i, tile_size: Vector2 = Vector2(128.0, 64.0)) -> Array[Vector2]:
	var route: Array[Vector2] = []
	if not is_road_cell(start_cell) or not is_road_cell(end_cell):
		return route
	if start_cell == end_cell:
		route.append(Grid.grid_to_world(start_cell, tile_size))
		return route
	var frontier: Array[Vector2i] = [start_cell]
	var came_from: Dictionary = {start_cell: start_cell}
	var directions := _get_directions()
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
