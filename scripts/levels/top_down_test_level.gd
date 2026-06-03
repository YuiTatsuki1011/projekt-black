extends Node2D
class_name TopDownTestLevel

const TOP_DOWN_ENEMY_GROUP := "top_down_enemies"
const NOISE_RIPPLE_SCRIPT := preload("res://scripts/perception/noise_ripple.gd")

@export var navigation_inner_margin: float = 24.0
@export var navigation_obstacle_margin: float = 28.0
@export var navigation_cell_size: float = 40.0
@export var enemy_debug_vision_visible: bool = true
@export var enemy_debug_vision_toggle_key: Key = KEY_F2
@export var stealth_overlay_color: Color = Color(0.12, 0.28, 0.42, 0.18)
@export var stealth_vignette_color: Color = Color(0.0, 0.01, 0.025, 0.42)

var _enemy_debug_vision_toggle_was_pressed: bool = false
var _stealth_overlay_layer: CanvasLayer
var _stealth_tint: ColorRect
var _stealth_edges: Array[ColorRect] = []
var _player: Node


func _ready() -> void:
	_build_test_navigation_region()
	_player = get_node_or_null("Player")
	_create_stealth_overlay()


func _process(_delta: float) -> void:
	var toggle_pressed := Input.is_key_pressed(enemy_debug_vision_toggle_key)
	if toggle_pressed and not _enemy_debug_vision_toggle_was_pressed:
		enemy_debug_vision_visible = not enemy_debug_vision_visible
	_enemy_debug_vision_toggle_was_pressed = toggle_pressed
	_update_stealth_overlay()


func is_enemy_debug_vision_visible() -> bool:
	return enemy_debug_vision_visible


func is_player_in_enemy_combat_state() -> bool:
	for enemy in get_tree().get_nodes_in_group(TOP_DOWN_ENEMY_GROUP):
		if enemy != null and is_instance_valid(enemy) and enemy.has_method("is_in_combat_with_target"):
			if bool(enemy.call("is_in_combat_with_target")):
				return true
	return false


func emit_noise_event(
	noise_position: Vector2,
	radius: float,
	source: Node = null,
	noise_type: StringName = &"generic"
) -> void:
	var resolved_radius := maxf(radius, 1.0)
	if _is_player_stealth_mode_active():
		_spawn_noise_ripple(noise_position, resolved_radius, noise_type)

	for enemy in get_tree().get_nodes_in_group(TOP_DOWN_ENEMY_GROUP):
		if enemy == null or not is_instance_valid(enemy) or enemy == source:
			continue
		if enemy.has_method("receive_noise_event"):
			enemy.call("receive_noise_event", noise_position, resolved_radius, source, noise_type)


func _is_player_stealth_mode_active() -> bool:
	if _player == null or not is_instance_valid(_player):
		_player = get_node_or_null("Player")
	if _player != null and _player.has_method("is_stealth_mode_active"):
		return bool(_player.call("is_stealth_mode_active"))
	return false


func _spawn_noise_ripple(noise_position: Vector2, radius: float, noise_type: StringName) -> void:
	var ripple := NOISE_RIPPLE_SCRIPT.new()
	add_child(ripple)
	ripple.global_position = noise_position
	var alpha := 0.28
	if noise_type == &"gunshot":
		alpha = 0.5
	elif noise_type == &"footstep":
		alpha = 0.18
	ripple.setup(radius, 0.58, Color(1.0, 1.0, 1.0, alpha))


func _create_stealth_overlay() -> void:
	_stealth_overlay_layer = CanvasLayer.new()
	_stealth_overlay_layer.name = "StealthOverlay"
	_stealth_overlay_layer.layer = 30
	add_child(_stealth_overlay_layer)

	_stealth_tint = ColorRect.new()
	_stealth_tint.name = "Tint"
	_stealth_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stealth_tint.color = stealth_overlay_color
	_stealth_overlay_layer.add_child(_stealth_tint)

	for edge_name in ["Top", "Bottom", "Left", "Right"]:
		var edge := ColorRect.new()
		edge.name = edge_name
		edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		edge.color = stealth_vignette_color
		_stealth_overlay_layer.add_child(edge)
		_stealth_edges.append(edge)

	_update_stealth_overlay_layout()
	_set_stealth_overlay_visible(false)


func _update_stealth_overlay() -> void:
	if _stealth_overlay_layer == null:
		return

	_update_stealth_overlay_layout()
	_set_stealth_overlay_visible(_is_player_stealth_mode_active())


func _update_stealth_overlay_layout() -> void:
	if _stealth_tint == null:
		return

	var viewport_size := get_viewport_rect().size
	_stealth_tint.position = Vector2.ZERO
	_stealth_tint.size = viewport_size

	var edge_thickness := maxf(minf(viewport_size.x, viewport_size.y) * 0.12, 96.0)
	if _stealth_edges.size() >= 4:
		_stealth_edges[0].position = Vector2.ZERO
		_stealth_edges[0].size = Vector2(viewport_size.x, edge_thickness)
		_stealth_edges[1].position = Vector2(0.0, viewport_size.y - edge_thickness)
		_stealth_edges[1].size = Vector2(viewport_size.x, edge_thickness)
		_stealth_edges[2].position = Vector2.ZERO
		_stealth_edges[2].size = Vector2(edge_thickness, viewport_size.y)
		_stealth_edges[3].position = Vector2(viewport_size.x - edge_thickness, 0.0)
		_stealth_edges[3].size = Vector2(edge_thickness, viewport_size.y)


func _set_stealth_overlay_visible(is_visible: bool) -> void:
	if _stealth_overlay_layer != null:
		_stealth_overlay_layer.visible = is_visible


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
