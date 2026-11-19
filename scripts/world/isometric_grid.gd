extends RefCounted
class_name IsometricGrid

## Shared coordinate conversion for the district's isometric world.
## Grid positions describe ground cells; sprite height is a visual offset only.

const DEFAULT_TILE_SIZE := Vector2(128.0, 64.0)

static func grid_to_world(
	cell: Vector2i,
	tile_size: Vector2 = DEFAULT_TILE_SIZE,
	elevation: float = 0.0
) -> Vector2:
	if tile_size.x <= 0.0 or tile_size.y <= 0.0:
		return Vector2.ZERO
	var half_width := tile_size.x * 0.5
	var half_height := tile_size.y * 0.5
	return Vector2(
		(float(cell.x) - float(cell.y)) * half_width,
		(float(cell.x) + float(cell.y)) * half_height - elevation
	)

static func world_to_grid(
	world_position: Vector2,
	tile_size: Vector2 = DEFAULT_TILE_SIZE
) -> Vector2i:
	if tile_size.x <= 0.0 or tile_size.y <= 0.0:
		return Vector2i.ZERO
	var normalized_x := world_position.x / tile_size.x
	var normalized_y := world_position.y / tile_size.y
	return Vector2i(
		roundi(normalized_x + normalized_y),
		roundi(normalized_y - normalized_x)
	)

static func is_inside_cell(
	local_position: Vector2,
	tile_size: Vector2 = DEFAULT_TILE_SIZE
) -> bool:
	if tile_size.x <= 0.0 or tile_size.y <= 0.0:
		return false
	var normalized_x := absf(local_position.x) / (tile_size.x * 0.5)
	var normalized_y := absf(local_position.y) / (tile_size.y * 0.5)
	return normalized_x + normalized_y <= 1.0

static func depth_key(cell: Vector2i) -> int:
	## Stable ground-depth key. Use cell.x as a secondary key for ties.
	return cell.x + cell.y

static func is_before_in_draw_order(a: Vector2i, b: Vector2i) -> bool:
	var depth_a := depth_key(a)
	var depth_b := depth_key(b)
	if depth_a == depth_b:
		return a.x < b.x
	return depth_a < depth_b
