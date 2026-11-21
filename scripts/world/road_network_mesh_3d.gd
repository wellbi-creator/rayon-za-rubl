extends MeshInstance3D
## Builds the prototype's complete connected asphalt footprint as one triangulated mesh.
## Coordinates are local to RoadNetwork: X is east-west and Z is north-south.

const ROAD_HALF_WIDTH := 2.25
const ROAD_HALF_LENGTH := 80.0
const CROSS_STREET_HALF_LENGTH := 60.0
const WEST_STREET_X := -35.0
const EAST_STREET_X := 35.0
const CORNER_RADIUS := 1.15
const CORNER_SEGMENTS := 5
const SURFACE_Y := 0.075

func _ready() -> void:
	_build_road_mesh()


func _build_road_mesh() -> void:
	var half := ROAD_HALF_WIDTH
	var cross_half := ROAD_HALF_WIDTH
	var west_left := WEST_STREET_X - cross_half
	var west_right := WEST_STREET_X + cross_half
	var east_left := EAST_STREET_X - cross_half
	var east_right := EAST_STREET_X + cross_half
	var south_end := 4.0 - CROSS_STREET_HALF_LENGTH
	var north_end := 4.0 + CROSS_STREET_HALF_LENGTH

	# One perimeter describes the union of the east-west avenue and both
	# north-south streets. There are no overlapping road slabs or CSG parts.
	var perimeter := PackedVector2Array([
		Vector2(-ROAD_HALF_LENGTH, -half),
		Vector2(west_left, -half),
		Vector2(west_left, south_end),
		Vector2(west_right, south_end),
		Vector2(west_right, -half),
		Vector2(east_left, -half),
		Vector2(east_left, south_end),
		Vector2(east_right, south_end),
		Vector2(east_right, -half),
		Vector2(ROAD_HALF_LENGTH, -half),
		Vector2(ROAD_HALF_LENGTH, half),
		Vector2(east_right, half),
		Vector2(east_right, north_end),
		Vector2(east_left, north_end),
		Vector2(east_left, half),
		Vector2(west_right, half),
		Vector2(west_right, north_end),
		Vector2(west_left, north_end),
		Vector2(west_left, half),
		Vector2(-ROAD_HALF_LENGTH, half)
	])
	perimeter = _round_polygon_corners(perimeter, CORNER_RADIUS, CORNER_SEGMENTS)

	var triangles := Geometry2D.triangulate_polygon(perimeter)
	if triangles.is_empty():
		push_error("RoadNetwork: failed to triangulate the unified road outline.")
		return

	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	for point in perimeter:
		vertices.append(Vector3(point.x, SURFACE_Y, point.y))
		normals.append(Vector3.UP)

	var indices := PackedInt32Array()
	for i in range(0, triangles.size(), 3):
		var a: int = triangles[i]
		var b: int = triangles[i + 1]
		var c: int = triangles[i + 2]
		var ab := vertices[b] - vertices[a]
		var ac := vertices[c] - vertices[a]
		# In the X/Z plane, reverse winding when needed so every face points up.
		if ab.cross(ac).y > 0.0:
			indices.append_array(PackedInt32Array([a, b, c]))
		else:
			indices.append_array(PackedInt32Array([a, c, b]))

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices

	var road_mesh := ArrayMesh.new()
	road_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh = road_mesh


func _round_polygon_corners(
	polygon: PackedVector2Array,
	radius: float,
	segments: int
) -> PackedVector2Array:
	var rounded := PackedVector2Array()
	var count := polygon.size()
	for i in range(count):
		var previous: Vector2 = polygon[(i - 1 + count) % count]
		var corner: Vector2 = polygon[i]
		var following: Vector2 = polygon[(i + 1) % count]
		var incoming_length := corner.distance_to(previous)
		var outgoing_length := corner.distance_to(following)
		var cut := minf(radius, minf(incoming_length, outgoing_length) * 0.42)
		var start := corner + (previous - corner).normalized() * cut
		var finish := corner + (following - corner).normalized() * cut
		for step in range(segments + 1):
			var t := float(step) / float(segments)
			var one_minus_t := 1.0 - t
			var point := one_minus_t * one_minus_t * start \
				+ 2.0 * one_minus_t * t * corner \
				+ t * t * finish
			rounded.append(point)
	return rounded
