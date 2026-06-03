extends Node2D
class_name TopDownTestLevel

const TOP_DOWN_ENEMY_GROUP := "top_down_enemies"
const NOISE_RIPPLE_SCRIPT := preload("res://scripts/perception/noise_ripple.gd")
const STEALTH_VIGNETTE_SCRIPT := preload("res://scripts/ui/stealth_vignette_overlay.gd")

enum MissionObjectiveType {
	INTERACT,
	ELIMINATION,
}

@export var navigation_inner_margin: float = 24.0
@export var navigation_obstacle_margin: float = 12.0
@export var navigation_cell_size: float = 20.0
@export var enemy_debug_vision_visible: bool = true
@export var enemy_debug_vision_toggle_key: Key = KEY_F2
@export var debug_noise_visible: bool = false
@export var debug_noise_toggle_key: Key = KEY_F3
@export var stealth_vignette_color: Color = Color(0.0, 0.0, 0.0, 0.62)
@export var stealth_vignette_edge_fraction: float = 0.18
@export var stealth_vignette_min_thickness: float = 128.0
@export var stealth_vignette_steps: int = 40
@export_enum("Interact", "Elimination") var mission_objective_type: int = MissionObjectiveType.ELIMINATION
@export var mission_objective_id: StringName = &"prototype_cache"
@export var mission_objective_text: String = "Eliminate the marked gunner"
@export var mission_extract_text: String = "Reach extraction"
@export var mission_elimination_target_id: StringName = &"mission_gunner"
@export var mission_required_kills: int = 1
@export var extraction_requires_objective: bool = false

var _enemy_debug_vision_toggle_was_pressed: bool = false
var _debug_noise_toggle_was_pressed: bool = false
var _stealth_overlay_layer: CanvasLayer
var _stealth_vignette: Control
var _player: Node
var _mission_hud: MissionStatusHud
var _run_result_screen: RunResultScreen
var _extraction_point: Node
var _mission_objective_complete: bool = false
var _mission_complete: bool = false
var _run_extracted: bool = false
var _run_start_msec: int = 0
var _enemies_defeated: int = 0
var _mission_kill_count: int = 0


func _ready() -> void:
	_build_test_navigation_region()
	_run_start_msec = Time.get_ticks_msec()
	_player = get_node_or_null("Player")
	_mission_hud = get_node_or_null("MissionStatusHud") as MissionStatusHud
	_run_result_screen = get_node_or_null("RunResultScreen") as RunResultScreen
	_extraction_point = get_node_or_null("ExtractionPoint")
	_create_stealth_overlay()
	_update_mission_display()


func _process(_delta: float) -> void:
	var toggle_pressed := Input.is_key_pressed(enemy_debug_vision_toggle_key)
	if toggle_pressed and not _enemy_debug_vision_toggle_was_pressed:
		enemy_debug_vision_visible = not enemy_debug_vision_visible
	_enemy_debug_vision_toggle_was_pressed = toggle_pressed

	var noise_toggle_pressed := Input.is_key_pressed(debug_noise_toggle_key)
	if noise_toggle_pressed and not _debug_noise_toggle_was_pressed:
		debug_noise_visible = not debug_noise_visible
	_debug_noise_toggle_was_pressed = noise_toggle_pressed
	_update_stealth_overlay()


func is_enemy_debug_vision_visible() -> bool:
	return enemy_debug_vision_visible


func is_debug_noise_visible() -> bool:
	return debug_noise_visible


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
	if debug_noise_visible or _is_player_stealth_mode_active():
		_spawn_noise_ripple(noise_position, resolved_radius, noise_type)

	for enemy in get_tree().get_nodes_in_group(TOP_DOWN_ENEMY_GROUP):
		if enemy == null or not is_instance_valid(enemy) or enemy == source:
			continue
		if enemy.has_method("receive_noise_event"):
			enemy.call("receive_noise_event", noise_position, resolved_radius, source, noise_type)


func notify_enemy_defeated(_enemy: Node = null) -> void:
	if _mission_complete:
		return

	_enemies_defeated += 1


func complete_mission_objective(objective_id: StringName, _source: Node = null) -> bool:
	if _mission_complete:
		return false
	if mission_objective_type != MissionObjectiveType.INTERACT:
		show_mission_message("Objective requires elimination.")
		return false
	if objective_id != mission_objective_id:
		show_mission_message("Unknown objective.")
		return false
	if _mission_objective_complete:
		show_mission_message("Objective already secured.")
		return true

	_mission_objective_complete = true
	show_mission_message("Objective secured.")
	_update_mission_display()
	return true


func notify_mission_enemy_defeated(target_id: StringName, count: int = 1, _source: Node = null) -> void:
	if _mission_complete or _mission_objective_complete:
		return
	if mission_objective_type != MissionObjectiveType.ELIMINATION:
		return
	if target_id != mission_elimination_target_id:
		return

	_mission_kill_count = mini(_mission_kill_count + maxi(count, 1), maxi(mission_required_kills, 1))
	if _mission_kill_count >= maxi(mission_required_kills, 1):
		_mission_objective_complete = true
		show_mission_message("Target eliminated. Quest progress secured.")
	else:
		show_mission_message("Target eliminated. %d/%d" % [_mission_kill_count, mission_required_kills])
	_update_mission_display()


func request_extraction(_source: Node = null) -> bool:
	if _mission_complete:
		return true

	if extraction_requires_objective and not _mission_objective_complete:
		show_mission_message("Extraction locked. Complete the objective first.")
		return false

	_finish_run(true)
	return true


func request_run_failure(_source: Node = null) -> void:
	if _mission_complete:
		return

	_finish_run(false)


func show_mission_message(message: String) -> void:
	if _mission_hud != null:
		_mission_hud.show_message(message)


func _update_mission_display() -> void:
	if _mission_hud != null:
		if _mission_complete:
			_mission_hud.set_objective_text("OBJECTIVE COMPLETE" if _mission_objective_complete else "OBJECTIVE INCOMPLETE")
			_mission_hud.set_status_text("EXTRACTED" if _run_extracted else "KIA")
		elif _mission_objective_complete:
			_mission_hud.set_objective_text("OBJECTIVE: %s" % mission_extract_text.to_upper())
			_mission_hud.set_status_text("EXTRACT WHEN READY")
		elif mission_objective_type == MissionObjectiveType.ELIMINATION:
			_mission_hud.set_objective_text("OBJECTIVE: %s %d/%d" % [
				mission_objective_text.to_upper(),
				_mission_kill_count,
				maxi(mission_required_kills, 1),
			])
			_mission_hud.set_status_text("EXTRACTION AVAILABLE")
		else:
			_mission_hud.set_objective_text("OBJECTIVE: %s" % mission_objective_text.to_upper())
			_mission_hud.set_status_text("EXTRACTION AVAILABLE")

	if _extraction_point != null and _extraction_point.has_method("set_extraction_ready"):
		var extraction_ready := not _mission_complete and (not extraction_requires_objective or _mission_objective_complete)
		_extraction_point.call("set_extraction_ready", extraction_ready)


func _finish_run(extracted: bool) -> void:
	_mission_complete = true
	_run_extracted = extracted
	_update_mission_display()

	var title: String = "EXTRACTION COMPLETE" if extracted else "RUN FAILED"
	var subtitle: String = "QUEST OBJECTIVE COMPLETE" if _mission_objective_complete else "NO QUEST PROGRESS"
	var stats: Dictionary = _build_run_result_stats(extracted, subtitle)
	if _run_result_screen != null:
		_run_result_screen.show_result(title, subtitle, stats)
	elif _mission_hud != null:
		_mission_hud.show_complete(title, subtitle)


func _build_run_result_stats(extracted: bool, quest_status: String) -> Dictionary:
	var inventory_summary: Dictionary = _get_player_inventory_summary()
	return {
		"extracted": extracted,
		"elapsed_seconds": _get_run_elapsed_seconds(),
		"enemies_killed": _enemies_defeated,
		"quest_status": quest_status,
		"item_stacks": int(inventory_summary.get("stacks", 0)),
		"item_units": int(inventory_summary.get("units", 0)),
	}


func _get_run_elapsed_seconds() -> int:
	if _run_start_msec <= 0:
		return 0

	return maxi(0, floori(float(Time.get_ticks_msec() - _run_start_msec) / 1000.0))


func _get_player_inventory_summary() -> Dictionary:
	var summary: Dictionary = {
		"stacks": 0,
		"units": 0,
	}
	var inventory: Node = _get_player_inventory()
	if inventory == null or not inventory.has_method("get_entries"):
		return summary

	var entries: Array = inventory.call("get_entries")
	summary["stacks"] = entries.size()
	var unit_count: int = 0
	for entry in entries:
		if not entry is Dictionary:
			continue
		var entry_dictionary: Dictionary = entry
		unit_count += maxi(int(entry_dictionary.get("quantity", 1)), 1)
	summary["units"] = unit_count
	return summary


func _get_player_inventory() -> Node:
	if _player == null or not is_instance_valid(_player):
		_player = get_node_or_null("Player")
	if _player == null:
		return null

	return _player.get_node_or_null("Inventory")


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

	_stealth_vignette = STEALTH_VIGNETTE_SCRIPT.new()
	_stealth_vignette.name = "Vignette"
	_stealth_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stealth_overlay_layer.add_child(_stealth_vignette)
	if _stealth_vignette.has_method("configure"):
		_stealth_vignette.call(
			"configure",
			stealth_vignette_color,
			stealth_vignette_edge_fraction,
			stealth_vignette_min_thickness,
			stealth_vignette_steps
		)

	_update_stealth_overlay_layout()
	_set_stealth_overlay_visible(false)


func _update_stealth_overlay() -> void:
	if _stealth_overlay_layer == null:
		return

	_update_stealth_overlay_layout()
	_set_stealth_overlay_visible(_is_player_stealth_mode_active())


func _update_stealth_overlay_layout() -> void:
	if _stealth_vignette == null:
		return

	var viewport_size := get_viewport_rect().size
	_stealth_vignette.position = Vector2.ZERO
	_stealth_vignette.size = viewport_size


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
