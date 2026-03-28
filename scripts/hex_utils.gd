extends RefCounted
## Hex Grid Utilities for world map
## Handles hex coordinate math, layout, and conversions

class_name HexUtils

# Flat-top hex layout
const SQRT3: float = 1.7320508075688772

# --- Coordinate Conversions ---

## Convert axial hex coordinates to pixel position
static func hex_to_pixel(q: int, r: int, hex_size: float, offset: Vector2 = Vector2.ZERO) -> Vector2:
	var x: float = hex_size * (SQRT3 * float(q) + SQRT3 / 2.0 * float(r)) + offset.x
	var y: float = hex_size * (3.0 / 2.0 * float(r)) + offset.y
	return Vector2(x, y)


## Convert pixel position to nearest hex coordinate
static func pixel_to_hex(x: float, y: float, hex_size: float) -> Vector2i:
	var q: float = (SQRT3 / 3.0 * x - 1.0 / 3.0 * y) / hex_size
	var r: float = (2.0 / 3.0 * y) / hex_size
	return axial_round(q, r)


## Round fractional axial coordinates to nearest hex
static func axial_round(q: float, r: float) -> Vector2i:
	var s: float = -q - r
	var rq: float = roundf(q)
	var rr: float = roundf(r)
	var rs: float = roundf(s)

	var q_diff: float = absf(rq - q)
	var r_diff: float = absf(rr - r)
	var s_diff: float = absf(rs - s)

	if q_diff > r_diff and q_diff > s_diff:
		rq = -rr - rs
	elif r_diff > s_diff:
		rr = -rq - rs

	return Vector2i(int(rq), int(rr))


## Convert offset coordinates (col, row) to axial (q, r)
static func offset_to_axial(col: int, row: int) -> Vector2i:
	var q: int = col
	var r: int = row - (col - (col & 1)) / 2
	return Vector2i(q, r)


## Convert axial (q, r) to offset (col, row)
static func axial_to_offset(q: int, r: int) -> Vector2i:
	var col: int = q
	var row: int = r + (q - (q & 1)) / 2
	return Vector2i(col, row)


# --- Geometry ---

## Get the 6 corner points of a flat-top hexagon
static func get_hex_corners(center: Vector2, size: float) -> PackedVector2Array:
	var corners: PackedVector2Array = []
	for i: int in range(6):
		var angle: float = deg_to_rad(60.0 * float(i))
		corners.append(center + Vector2(size * cos(angle), size * sin(angle)))
	return corners


## Get corner points with flat-top orientation (rotated -30deg)
static func get_hex_polygon_points(center: Vector2, size: float) -> PackedVector2Array:
	var corners: PackedVector2Array = []
	for i: int in range(6):
		var angle: float = deg_to_rad(60.0 * float(i) - 30.0)
		corners.append(center + Vector2(size * cos(angle), size * sin(angle)))
	return corners


# --- Neighbor / Distance ---

## Get all 6 neighbor coordinates of a hex
static func get_neighbors(q: int, r: int) -> Array:
	return [
		{"q": q + 1, "r": r},
		{"q": q - 1, "r": r},
		{"q": q, "r": r + 1},
		{"q": q, "r": r - 1},
		{"q": q + 1, "r": r - 1},
		{"q": q - 1, "r": r + 1},
	]


## Calculate hex distance between two hex coordinates
static func hex_distance(q1: int, r1: int, q2: int, r2: int) -> int:
	return int(
		(absf(float(q1 - q2)) + absf(float(q1 + r1 - q2 - r2)) + absf(float(r1 - r2))) / 2.0
	)


## Get all hexes within a given radius
static func get_hexes_in_radius(q: int, r: int, radius: int) -> Array:
	var results: Array = []
	for dq: int in range(-radius, radius + 1):
		for dr: int in range(maxi(-radius, -dq - radius), mini(radius, -dq + radius) + 1):
			results.append({"q": q + dq, "r": r + dr})
	return results


# --- Grid Generation ---

## Generate a rectangular hex grid
static func generate_rect_grid(cols: int, rows: int) -> Array:
	var grid: Array = []
	for col: int in range(cols):
		for row: int in range(rows):
			var q: int = col
			var r: int = row - (col / 2)
			grid.append({"q": q, "r": r, "col": col, "row": row})
	return grid
