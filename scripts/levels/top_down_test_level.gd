extends Node2D
class_name TopDownTestLevel

@export var navigation_inner_margin: float = 24.0
@export var navigation_obstacle_margin: float = 28.0
@export var navigation_cell_size: float = 40.0
@export var enemy_debug_vision_visible: bool = true
@export var enemy_debug_vision_toggle_key: Key = KEY_F2

var _enemy_debug_vision_toggle_was_pressed: bool = false


func _ready() -> void:
	_build_test_navigation_region()


func _process(_delta: float) -> void:
	var toggle_pressed := Input.is_key_pressed(enemy_debug_vision_toggle_key)
	if toggle_pressed and not _enemy_debug_vision_toggle_was_pressed:
		enemy_debug_vision_visible = not enemy_debug_vision_visible
	_enemy_debug_vision_toggle_was_pressed = toggle_pressed


func is_enemy_debug_vision_visible() -> bool:
	return enemy_debug_vision_visible


func _build_test_navigation_region() -> void:
	if get_node_or_null("GeneratedNavigation") != null:
		return

	var navigation_region := NavigationRegion2D.new()
	navigation_region.name = "GeneratedNavigation"
	navigation_region.navigation_polygon = _create_navigation_polygon()
	add_child(navigation_region)


func _create_navigation_polygon() -> NavigationPolygon:
	var polygon := NavigationPolygon.new()
	var inner_margin := maxf(navigation_inner_margin, 0.0)
	var bounds := Rect2(
		Vector2(inner_margin, inner_margin),
		Vector2(960.0 - inner_margin * 2.0, 640.0 - inner_margin * 2.0)
	)
	var obstacles: Array[Rect2] = []
	for obstacle_rect in _get_navigation_obstacle_rects():
		obstacles.append(obstacle_rect.grow(navigation_obstacle_margin))

	var vertices := PackedVector2Array()
	var vertex_indices := {}
	var polygons: Array[PackedInt32Array] = []
	var cell_size := maxf(navigation_cell_size, 8.0)
	var y := bounds.position.y
	while y < bounds.end.y - 0.01:
		var next_y := minf(y + cell_size, bounds.end.y)
		var x := bounds.position.x
		while x < bounds.end.x - 0.01:
			var next_x := minf(x + cell_size, bounds.end.x)
			var cell_rect := Rect2(Vector2(x, y), Vector2(next_x - x, next_y - y))
			if not _is_navigation_cell_blocked(cell_rect, obstacles):
				polygons.append(PackedInt32Array([
					_get_navigation_vertex_index(vertices, vertex_indices, cell_rect.position),
					_get_navigation_vertex_index(vertices, vertex_indices, Vector2(cell_rect.position.x, cell_rect.end.y)),
					_get_navigation_vertex_index(vertices, vertex_indices, cell_rect.end),
					_get_navigation_vertex_index(vertices, vertex_indices, Vector2(cell_rect.end.x, cell_rect.position.y)),
				]))
			x = next_x
		y = next_y

	polygon.vertices = vertices
	for polygon_indices in polygons:
		polygon.add_polygon(polygon_indices)
	return polygon


func _get_navigation_obstacle_rects() -> Array[Rect2]:
	return [
		Rect2(Vector2(520.0, 250.0) - Vector2(64.0, 27.0), Vector2(128.0, 54.0)),
		Rect2(Vector2(700.0, 432.0) - Vector2(32.0, 65.0), Vector2(64.0, 130.0)),
		Rect2(Vector2(330.0, 468.0) - Vector2(90.0, 18.0), Vector2(180.0, 36.0)),
	]


func _is_navigation_cell_blocked(cell_rect: Rect2, obstacles: Array[Rect2]) -> bool:
	var test_rect := cell_rect.grow(-2.0)
	for obstacle_rect in obstacles:
		if test_rect.intersects(obstacle_rect):
			return true

	return false


func _get_navigation_vertex_index(vertices: PackedVector2Array, vertex_indices: Dictionary, point: Vector2) -> int:
	var key := "%d:%d" % [roundi(point.x * 10.0), roundi(point.y * 10.0)]
	if vertex_indices.has(key):
		return int(vertex_indices[key])

	var next_index := vertices.size()
	vertices.append(point)
	vertex_indices[key] = next_index
	return next_index
