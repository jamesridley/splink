extends Control

signal spell_cast(spell_name: String, intensity: float, cast_location: Vector2, spell_coords: Array)
signal spell_failed(ink_cost: float, cast_location: Vector2, spell_coords: Array)
signal ink_changed(current_ink: float, max_ink: float)

@export var grid_area: Control
@export var line_drawer: Control
@export var fail_animation_player: AnimationPlayer

@export var hex_radius: int = 3
@export var hex_cell_size: float = 42.0
@export var dot_radius: float = 5.0

@export var max_ink: float = 100.0
@export var wrong_spell_ink_cost: float = 8.0
@export var base_spell_ink_cost: float = 12.0
@export var ink_cost_per_dot: float = 2.0

@export var snap_radius_multiplier: float = 0.75
@export var shape_match_tolerance: float = 0.2
@export var minimum_shape_score: float = 0.65

@export var ink_line_width: float = 6.0
@export var ink_trail_lifetime: float = 0.45
@export var ink_trail_fade_speed: float = 2.8

@export var show_hex_outlines: bool = true
@export var show_hex_coords: bool = false

var current_ink: float
var is_drawing: bool = false
var hovered_hex = null

var selected_hexes: Array[Vector2i] = []
var hex_positions: Dictionary = {}
var ink_trail_points: Array[Dictionary] = []

var unlocked_spells: Array[String] = ["fire", "water", "air", "earth"]

var spell_patterns := {
	"fire": [
		Vector2i(0, -2),
		Vector2i(-2, 1),
		Vector2i(2, 1),
		Vector2i(0, -2)
	],

	"water": [
		Vector2i(-2, -1),
		Vector2i(2, -1),
		Vector2i(0, 2),
		Vector2i(-2, -1)
	],

	"air": [
		Vector2i(0, -2),
		Vector2i(-2, 1),
		Vector2i(2, 1),
		Vector2i(0, -2),
		Vector2i(-2, 0),
		Vector2i(2, 0)
	],

	"earth": [
		Vector2i(-2, -1),
		Vector2i(2, -1),
		Vector2i(0, 2),
		Vector2i(-2, -1),
		Vector2i(-2, 0),
		Vector2i(2, 0)
	]
}


func _ready() -> void:
	set_process(true)
	set_process_input(true)

	current_ink = max_ink
	ink_changed.emit(current_ink, max_ink)

	if line_drawer != null:
		line_drawer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line_drawer.draw.connect(_drawHexGrid)

	resized.connect(_rebuildGrid)
	_rebuildGrid()


func _process(delta: float) -> void:
	for point_data in ink_trail_points:
		point_data["life"] -= delta * ink_trail_fade_speed

	ink_trail_points = ink_trail_points.filter(func(point_data): return point_data["life"] > 0.0)

	if line_drawer != null:
		line_drawer.queue_redraw()


func _input(event: InputEvent) -> void:
	if not visible or grid_area == null:
		return

	var mouse_pos: Vector2 = grid_area.get_local_mouse_position()

	if not Rect2(Vector2.ZERO, grid_area.size).has_point(mouse_pos):
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_startDrawing(mouse_pos)
			else:
				_finishDrawing()

	if event is InputEventMouseMotion:
		hovered_hex = _getNearestHex(mouse_pos)

		if is_drawing:
			_addInkTrailPoint(mouse_pos)
			_tryAddHex(mouse_pos)

		if line_drawer != null:
			line_drawer.queue_redraw()


func openCaster() -> void:
	visible = true
	is_drawing = false
	hovered_hex = null
	selected_hexes.clear()
	ink_trail_points.clear()

	if line_drawer != null:
		line_drawer.queue_redraw()


func closeCaster() -> void:
	visible = false
	is_drawing = false
	hovered_hex = null
	selected_hexes.clear()
	ink_trail_points.clear()

	if line_drawer != null:
		line_drawer.queue_redraw()


func setUnlockedSpells(spells: Array[String]) -> void:
	unlocked_spells = spells


func unlockSpell(spell_name: String) -> void:
	if not unlocked_spells.has(spell_name):
		unlocked_spells.append(spell_name)


func _startDrawing(mouse_pos: Vector2) -> void:
	is_drawing = true
	selected_hexes.clear()
	ink_trail_points.clear()
	_tryAddHex(mouse_pos)


func _finishDrawing() -> void:
	is_drawing = false

	if selected_hexes.size() < 2:
		_clearDrawing()
		return

	var simplified_hexes: Array[Vector2i] = _simplifyCoords(selected_hexes)

	print("RAW: ", selected_hexes)
	print("SIMPLIFIED: ", simplified_hexes)

	var result: Dictionary = _getMatchedSpell(simplified_hexes)

	if result.is_empty():
		_failSpell()
		return

	var spell_name: String = result["spell_name"]

	if not unlocked_spells.has(spell_name):
		_failSpell()
		return

	var intensity: float = _calculateIntensity(simplified_hexes)
	var ink_cost: float = _calculateInkCost(simplified_hexes)

	if current_ink < ink_cost:
		_failSpell()
		return

	current_ink -= ink_cost
	ink_changed.emit(current_ink, max_ink)

	print("SPELL WORKED: ", spell_name)
	var cast_world_pos: Vector2 = _getSpellCenterWorldPosition(simplified_hexes)
	spell_cast.emit(
		spell_name,
		intensity,
		cast_world_pos,
		simplified_hexes.duplicate()
	)

	_clearDrawing()
func _getSpellCenterWorldPosition(coords: Array[Vector2i]) -> Vector2:
	if coords.is_empty() or grid_area == null:
		return Vector2.ZERO

	# Average the hex centers in grid_area's local space.
	var sum: Vector2 = Vector2.ZERO
	var count: int = 0

	for coord in coords:
		if hex_positions.has(coord):
			sum += hex_positions[coord]
			count += 1

	if count == 0:
		return Vector2.ZERO

	var center_local: Vector2 = sum / float(count)

	# Local -> viewport/screen space.
	# get_global_transform_with_canvas() accounts for any CanvasLayer the UI is under.
	var screen_pos: Vector2 = grid_area.get_global_transform_with_canvas() * center_local

	# Viewport -> world space.
	# canvas_transform reflects the active Camera2D (identity if none).
	return get_viewport().get_canvas_transform().affine_inverse() * screen_pos

func _tryAddHex(mouse_pos: Vector2) -> void:
	var hex_coord = _getNearestHex(mouse_pos)

	if hex_coord == null:
		return

	if selected_hexes.size() > 0:
		var last_hex: Vector2i = selected_hexes[-1]

		if hex_coord == last_hex:
			return

	selected_hexes.append(hex_coord)

	if line_drawer != null:
		line_drawer.queue_redraw()


func _getNearestHex(mouse_pos: Vector2):
	var best_hex = null
	var best_distance: float = INF

	for coord in hex_positions.keys():
		var distance: float = mouse_pos.distance_to(hex_positions[coord])

		if distance < best_distance:
			best_distance = distance
			best_hex = coord

	if best_distance <= hex_cell_size * snap_radius_multiplier:
		return best_hex

	return null


func _rebuildGrid() -> void:
	if grid_area == null:
		return

	hex_positions.clear()

	var center: Vector2 = grid_area.size * 0.5

	for q in range(-hex_radius, hex_radius + 1):
		for r in range(-hex_radius, hex_radius + 1):
			var s: int = -q - r

			if abs(s) > hex_radius:
				continue

			var coord: Vector2i = Vector2i(q, r)
			hex_positions[coord] = center + _hexToPixel(coord)

	if line_drawer != null:
		line_drawer.queue_redraw()


func _hexToPixel(coord: Vector2i) -> Vector2:
	var q: float = float(coord.x)
	var r: float = float(coord.y)

	var x_pos: float = hex_cell_size * sqrt(3.0) * (q + r * 0.5)
	var y_pos: float = hex_cell_size * 1.5 * r

	return Vector2(x_pos, y_pos)


func _getHexCorners(center: Vector2) -> PackedVector2Array:
	var corners := PackedVector2Array()

	for i in range(6):
		var angle: float = deg_to_rad(60.0 * float(i) - 30.0)
		var point: Vector2 = center + Vector2(cos(angle), sin(angle)) * hex_cell_size
		corners.append(point)

	return corners


func _simplifyCoords(coords: Array[Vector2i]) -> Array[Vector2i]:
	var simplified: Array[Vector2i] = []

	for coord in coords:
		if simplified.is_empty() or simplified[-1] != coord:
			simplified.append(coord)

	if simplified.size() <= 2:
		return simplified

	var result: Array[Vector2i] = []
	result.append(simplified[0])

	for i in range(1, simplified.size() - 1):
		var previous: Vector2i = simplified[i - 1]
		var current: Vector2i = simplified[i]
		var next: Vector2i = simplified[i + 1]

		var direction_a: Vector2i = Vector2i(
			sign(current.x - previous.x),
			sign(current.y - previous.y)
		)

		var direction_b: Vector2i = Vector2i(
			sign(next.x - current.x),
			sign(next.y - current.y)
		)

		if direction_a != direction_b:
			result.append(current)

	result.append(simplified[-1])
	return result


func _getMatchedSpell(coords: Array[Vector2i]) -> Dictionary:
	var triangle_direction: String = _getTriangleDirection(coords)
	var has_middle_line: bool = _hasExtraLine(coords)

	if triangle_direction == "upright":
		if has_middle_line:
			return {"spell_name": "air"}
		return {"spell_name": "fire"}

	if triangle_direction == "downward":
		if has_middle_line:
			return {"spell_name": "earth"}
		return {"spell_name": "water"}

	return {}

func _hasExtraLine(coords: Array[Vector2i]) -> bool:
	var unique_points: Array[Vector2i] = []

	for coord in coords:
		if not unique_points.has(coord):
			unique_points.append(coord)

	# Triangle only usually has 3 unique points.
	# Triangle + middle line has more.
	return unique_points.size() > 3
	

func _getTriangleDirection(coords: Array) -> String:
	var unique_points: Array[Vector2i] = []

	for coord in coords:
		if not unique_points.has(coord):
			unique_points.append(coord)

	if unique_points.size() < 3:
		return ""

	var top_y: float = INF
	var bottom_y: float = -INF

	for coord in unique_points:
		var pos: Vector2 = _hexToPixel(coord)

		top_y = min(top_y, pos.y)
		bottom_y = max(bottom_y, pos.y)

	var top_count: int = 0
	var bottom_count: int = 0

	for coord in unique_points:
		var pos: Vector2 = _hexToPixel(coord)

		if abs(pos.y - top_y) < 1.0:
			top_count += 1

		if abs(pos.y - bottom_y) < 1.0:
			bottom_count += 1

	if top_count == 1 and bottom_count >= 2:
		return "upright"

	if top_count >= 2 and bottom_count == 1:
		return "downward"

	return ""


func _getShapeMatchScore(input_coords: Array, pattern_coords: Array) -> float:
	var input_points: Array[Vector2] = _normalize(input_coords)
	var pattern_points: Array[Vector2] = _normalize(pattern_coords)

	if input_points.is_empty() or pattern_points.is_empty():
		return 0.0

	var input_match_count: int = 0

	for input_point in input_points:
		for pattern_point in pattern_points:
			if input_point.distance_to(pattern_point) <= shape_match_tolerance:
				input_match_count += 1
				break

	var pattern_match_count: int = 0

	for pattern_point in pattern_points:
		for input_point in input_points:
			if pattern_point.distance_to(input_point) <= shape_match_tolerance:
				pattern_match_count += 1
				break

	var input_score: float = float(input_match_count) / float(input_points.size())
	var pattern_score: float = float(pattern_match_count) / float(pattern_points.size())

	var count_penalty: float = 1.0 - abs(float(input_points.size() - pattern_points.size())) * 0.15
	count_penalty = clamp(count_penalty, 0.0, 1.0)

	return ((input_score + pattern_score) * 0.5) * count_penalty


func _normalize(coords: Array) -> Array[Vector2]:
	var points: Array[Vector2] = []

	if coords.is_empty():
		return points

	var min_x: float = INF
	var min_y: float = INF
	var max_x: float = -INF
	var max_y: float = -INF

	for coord in coords:
		var pos: Vector2 = _hexToPixel(coord)

		min_x = min(min_x, pos.x)
		min_y = min(min_y, pos.y)
		max_x = max(max_x, pos.x)
		max_y = max(max_y, pos.y)

	var size_value: float = max(max_x - min_x, max_y - min_y, 1.0)

	for coord in coords:
		var pos: Vector2 = _hexToPixel(coord)
		points.append(Vector2(
			(pos.x - min_x) / size_value,
			(pos.y - min_y) / size_value
		))

	return points


func _calculateIntensity(coords: Array[Vector2i]) -> float:
	return clamp(float(coords.size()) / 10.0, 0.2, 1.0)


func _calculateInkCost(coords: Array[Vector2i]) -> float:
	return base_spell_ink_cost + float(coords.size()) * ink_cost_per_dot


func _failSpell() -> void:
	print("SPELL FAILED")

	current_ink -= wrong_spell_ink_cost
	current_ink = max(current_ink, 0.0)

	ink_changed.emit(current_ink, max_ink)

	spell_failed.emit(
		wrong_spell_ink_cost,
		get_global_mouse_position(),
		selected_hexes.duplicate()
	)

	if fail_animation_player != null and fail_animation_player.has_animation("fail"):
		fail_animation_player.play("fail")

	_clearDrawing()

	if current_ink <= 0.0:
		#get_tree().reload_current_scene()
		print("out of ink")


func _addInkTrailPoint(mouse_pos: Vector2) -> void:
	ink_trail_points.append({
		"position": mouse_pos,
		"life": ink_trail_lifetime
	})

func resetInk() -> void:
	current_ink = max_ink
	ink_changed.emit(current_ink, max_ink)

func _clearDrawing() -> void:
	selected_hexes.clear()
	ink_trail_points.clear()

	if line_drawer != null:
		line_drawer.queue_redraw()


func _draw() -> void:
	pass


func _drawHexGrid() -> void:
	if line_drawer == null:
		return

	# Draw dots only
	for coord in hex_positions.keys():
		var center: Vector2 = hex_positions[coord]

		var dot_color: Color = Color.BLUE_VIOLET

		if selected_hexes.has(coord):
			dot_color = Color.BLUE_VIOLET

		if coord == hovered_hex:
			dot_color = Color.BLUE_VIOLET

		line_drawer.draw_circle(center, dot_radius, dot_color)

	# Ink trail
	for i in range(ink_trail_points.size() - 1):
		var a = ink_trail_points[i]
		var b = ink_trail_points[i + 1]

		var alpha: float = clamp(a["life"] / ink_trail_lifetime, 0.0, 1.0)

		line_drawer.draw_line(
			a["position"],
			b["position"],
			Color.BLUE_VIOLET,
			ink_line_width
		)

	# Draw snapped spell lines
	for i in range(selected_hexes.size() - 1):
		var start_pos: Vector2 = hex_positions[selected_hexes[i]]
		var end_pos: Vector2 = hex_positions[selected_hexes[i + 1]]

		line_drawer.draw_line(
			start_pos,
			end_pos,
			Color(1, 1, 1, 1.0),
			ink_line_width + 1.0
		)
