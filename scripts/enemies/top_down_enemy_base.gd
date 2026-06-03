extends CharacterBody2D
class_name TopDownEnemyBase

const TOP_DOWN_ENEMY_GROUP := "top_down_enemies"
const LAST_SEEN_MARKER_NAME := "LastSeenPlayerMarker"
const LAST_SEEN_MARKER_SCRIPT := preload("res://scripts/enemies/player_sighting_marker.gd")

enum AwarenessState {
	IDLE,
	ALERT,
	COMBAT,
	SEARCH,
}

@export var target_path: NodePath = NodePath("../../Player")
@export var corpse_container_scene: PackedScene
@export var move_speed: float = 90.0
@export var detection_range: float = 560.0
@export var view_angle_degrees: float = 55.0
@export var close_detection_range: float = 44.0
@export var detection_time: float = 0.75
@export var detection_decay_time: float = 0.65
@export var search_memory_time: float = 5.0
@export var search_scan_time: float = 1.6
@export var search_arrival_distance: float = 30.0
@export var search_scan_turn_speed_degrees: float = 280.0
@export var visual_tracking_turn_speed_degrees: float = 520.0
@export var shared_alert_range: float = 360.0
@export var alert_share_delay: float = 0.35
@export var hearing_sensitivity: float = 1.0
@export var hearing_confidence: float = 0.45
@export var gunshot_hearing_confidence: float = 0.85
@export_flags_2d_physics var line_of_sight_blocker_mask: int = 1
@export var use_navigation: bool = true
@export var debug_state_visible: bool = true
@export var debug_vision_visible: bool = true
@export var debug_vision_focus_distance: float = 420.0
@export var debug_vision_segments: int = 18
@export var debug_last_seen_marker_visible: bool = true
@export var enemy_separation_radius: float = 44.0
@export var enemy_separation_strength: float = 140.0
@export var hit_vfx_scene: PackedScene
@export var death_vfx_scene: PackedScene
@export var knockback_strength: float = 120.0
@export var knockback_recovery: float = 480.0
@export var hit_flash_time: float = 0.08
@export var mission_target_id: StringName = &""
@export var mission_target_label: String = ""
@export var mission_target_weight: int = 1

@onready var health: Node = get_node_or_null("Health")
@onready var body_visual: Polygon2D = get_node_or_null("BodyVisual") as Polygon2D
@onready var eye_visual: Polygon2D = get_node_or_null("BodyVisual/Eye") as Polygon2D
@onready var navigation_agent: NavigationAgent2D = get_node_or_null("NavigationAgent2D") as NavigationAgent2D
@onready var loot_dropper: Node = get_node_or_null("LootDropper")

var _target: Node2D
var _is_dead: bool = false
var _desired_velocity: Vector2 = Vector2.ZERO
var _knockback_velocity: Vector2 = Vector2.ZERO
var _base_body_color: Color = Color.WHITE
var _base_eye_color: Color = Color.WHITE
var _flash_tween: Tween
var _awareness_state: AwarenessState = AwarenessState.IDLE
var _detection_progress: float = 0.0
var _has_last_known_target: bool = false
var _last_known_target_position: Vector2 = Vector2.ZERO
var _awareness_timer: float = 0.0
var _search_scan_timer: float = 0.0
var _facing_direction: Vector2 = Vector2.LEFT
var _direct_sighting_share_timer: float = 0.0
var _has_shared_current_sighting: bool = false
var _last_stimulus_type: StringName = &"none"
var _debug_label: Label
var _vision_cone: Polygon2D
var _detection_bar_root: Node2D
var _detection_bar_fill: Line2D
var _mission_target_marker: Label


func _ready() -> void:
	add_to_group(TOP_DOWN_ENEMY_GROUP)
	if body_visual != null:
		_base_body_color = body_visual.color
	if eye_visual != null:
		_base_eye_color = eye_visual.color

	_resolve_target()
	_configure_navigation_agent()
	_configure_debug_label()
	_configure_vision_cone()
	_configure_detection_bar()
	_configure_mission_target_marker()
	_connect_health_signals()
	_enemy_ready()


func _physics_process(delta: float) -> void:
	if _is_dead:
		return

	if _target == null or not is_instance_valid(_target):
		_resolve_target()

	_update_awareness(delta)
	_desired_velocity = Vector2.ZERO
	_enemy_physics_update(delta)
	velocity = _desired_velocity + _knockback_velocity
	_apply_enemy_separation_velocity()
	_update_debug_label()
	_update_debug_vision()
	_update_detection_bar()
	_knockback_velocity = _knockback_velocity.move_toward(Vector2.ZERO, knockback_recovery * delta)
	move_and_slide()


func _enemy_ready() -> void:
	pass


func _enemy_physics_update(_delta: float) -> void:
	pass


func set_target(target: Node2D) -> void:
	_target = target


func apply_hit_reaction(direction: Vector2, _damage: int, hit_position: Vector2) -> void:
	var knockback_direction := direction.normalized()
	if knockback_direction == Vector2.ZERO:
		knockback_direction = Vector2.RIGHT

	_knockback_velocity = knockback_direction * knockback_strength
	var suspected_source_position := hit_position - knockback_direction * 160.0
	if _target != null and is_instance_valid(_target):
		if _has_line_of_sight_to_target():
			suspected_source_position = _target.global_position

	_receive_stimulus(suspected_source_position, 0.9, &"hit", true)
	_turn_toward((suspected_source_position - global_position).normalized(), 0.0, true)
	_spawn_vfx(hit_vfx_scene, hit_position)
	_flash()


func receive_noise_event(noise_position: Vector2, radius: float, source: Node, noise_type: StringName = &"generic") -> void:
	if _is_dead or source == self:
		return

	var distance := global_position.distance_to(noise_position)
	var audible_radius := radius * maxf(hearing_sensitivity, 0.0)
	if distance > audible_radius:
		return

	var falloff := 1.0 - clampf(distance / maxf(audible_radius, 1.0), 0.0, 1.0)
	var confidence := hearing_confidence
	if noise_type == &"gunshot":
		confidence = gunshot_hearing_confidence
	_receive_stimulus(noise_position, confidence * falloff, noise_type, false)


func receive_shared_player_sighting(sighting_position: Vector2, source: Node) -> void:
	if _is_dead or source == self:
		return
	if global_position.distance_squared_to(sighting_position) > shared_alert_range * shared_alert_range:
		return

	_receive_stimulus(sighting_position, 0.7, &"shared", false)


func is_in_combat_with_target() -> bool:
	return _awareness_state == AwarenessState.COMBAT


func has_known_target() -> bool:
	return _has_last_known_target


func is_target_visible() -> bool:
	return _target != null and is_instance_valid(_target) and _has_line_of_sight_to_target()


func is_target_confirmed_visible() -> bool:
	return _awareness_state == AwarenessState.COMBAT and is_target_visible()


func get_target_or_memory_position() -> Vector2:
	if is_target_visible():
		return _target.global_position
	return _last_known_target_position


func get_facing_direction() -> Vector2:
	return _facing_direction


func get_awareness_state() -> int:
	return _awareness_state


func is_searching_at_memory() -> bool:
	return _awareness_state == AwarenessState.SEARCH and _search_scan_timer > 0.0


func add_desired_velocity(next_velocity: Vector2) -> void:
	_desired_velocity += next_velocity


func clear_target_awareness() -> void:
	_awareness_state = AwarenessState.IDLE
	_detection_progress = 0.0
	_has_last_known_target = false
	_awareness_timer = 0.0
	_search_scan_timer = 0.0
	_direct_sighting_share_timer = 0.0
	_has_shared_current_sighting = false
	_last_stimulus_type = &"none"
	_hide_last_seen_marker()


func move_toward_position(target_position: Vector2, speed: float, arrival_distance: float = 0.0) -> void:
	var to_target := target_position - global_position
	var distance := to_target.length()
	if distance <= maxf(arrival_distance, 0.0) or distance <= 0.01:
		return

	var fallback_direction := to_target / distance
	var move_direction := _get_navigation_direction_to(target_position, fallback_direction)
	add_desired_velocity(move_direction * speed)
	if _has_line_of_sight_to_position(target_position):
		_turn_toward(fallback_direction, get_physics_process_delta_time())
	else:
		_turn_toward(move_direction, get_physics_process_delta_time())


func turn_toward_position(target_position: Vector2, delta: float, instant: bool = false) -> void:
	var direction := target_position - global_position
	if direction.length_squared() <= 0.01:
		return
	_turn_toward(direction.normalized(), delta, instant)


func _resolve_target() -> void:
	_target = get_node_or_null(target_path) as Node2D
	if _target != null:
		return

	var current_scene := get_tree().current_scene
	if current_scene != null:
		_target = current_scene.get_node_or_null("Player") as Node2D


func _connect_health_signals() -> void:
	if health == null:
		return
	if health.has_signal("damaged"):
		health.damaged.connect(_on_damaged)
	if health.has_signal("died"):
		health.died.connect(_on_died)


func _configure_navigation_agent() -> void:
	if navigation_agent == null:
		return
	navigation_agent.path_desired_distance = 10.0
	navigation_agent.target_desired_distance = 12.0
	navigation_agent.avoidance_enabled = false


func _configure_debug_label() -> void:
	if not debug_state_visible:
		return

	_debug_label = Label.new()
	_debug_label.name = "DebugState"
	_debug_label.position = Vector2(-32.0, 26.0)
	_debug_label.z_index = 20
	_debug_label.add_theme_font_size_override("font_size", 9)
	_debug_label.add_theme_color_override("font_color", Color(0.76, 0.95, 0.72, 0.9))
	add_child(_debug_label)


func _configure_vision_cone() -> void:
	_vision_cone = Polygon2D.new()
	_vision_cone.name = "DebugVisionCone"
	_vision_cone.z_index = -1
	_vision_cone.color = Color(0.65, 0.75, 0.45, 0.13)
	add_child(_vision_cone)


func _configure_detection_bar() -> void:
	_detection_bar_root = Node2D.new()
	_detection_bar_root.name = "DetectionBar"
	_detection_bar_root.position = Vector2(-18.0, -42.0)
	_detection_bar_root.z_index = 21
	add_child(_detection_bar_root)

	var background := Line2D.new()
	background.name = "Background"
	background.points = PackedVector2Array([Vector2.ZERO, Vector2(36.0, 0.0)])
	background.width = 4.0
	background.default_color = Color(0.02, 0.02, 0.02, 0.78)
	_detection_bar_root.add_child(background)

	_detection_bar_fill = Line2D.new()
	_detection_bar_fill.name = "Fill"
	_detection_bar_fill.points = PackedVector2Array([Vector2.ZERO, Vector2.ZERO])
	_detection_bar_fill.width = 3.0
	_detection_bar_fill.default_color = Color(1.0, 0.75, 0.16, 0.95)
	_detection_bar_root.add_child(_detection_bar_fill)


func _configure_mission_target_marker() -> void:
	if mission_target_id == &"":
		return

	_mission_target_marker = Label.new()
	_mission_target_marker.name = "MissionTargetMarker"
	_mission_target_marker.position = Vector2(-32.0, -58.0)
	_mission_target_marker.z_index = 22
	_mission_target_marker.text = mission_target_label if not mission_target_label.is_empty() else "TARGET"
	_mission_target_marker.add_theme_font_size_override("font_size", 10)
	_mission_target_marker.add_theme_color_override("font_color", Color(1.0, 0.68, 0.2, 0.95))
	add_child(_mission_target_marker)


func _update_awareness(delta: float) -> void:
	var can_see := _can_see_target()
	if can_see:
		_hide_last_seen_marker()
		if _awareness_state != AwarenessState.COMBAT:
			_detection_progress = minf(1.0, _detection_progress + delta / maxf(detection_time, 0.01))
			if _detection_progress < 1.0:
				turn_toward_position(_target.global_position, delta)
				return
			_enter_combat(_target.global_position)
		else:
			_remember_target(_target.global_position)
		_share_current_sighting(delta)
		turn_toward_position(_target.global_position, delta)
		return

	_direct_sighting_share_timer = 0.0
	_has_shared_current_sighting = false
	if _awareness_state == AwarenessState.COMBAT:
		_enter_search()
		return

	if _awareness_state == AwarenessState.ALERT:
		_awareness_timer -= delta
		if _awareness_timer <= 0.0:
			_enter_search()
		return

	if _awareness_state == AwarenessState.SEARCH:
		_update_search_state(delta)
		return

	_detection_progress = maxf(0.0, _detection_progress - delta / maxf(detection_decay_time, 0.01))


func _receive_stimulus(position: Vector2, confidence: float, stimulus_type: StringName, force_search: bool) -> void:
	if confidence <= 0.01:
		return

	_remember_target(position)
	_last_stimulus_type = stimulus_type
	_detection_progress = maxf(_detection_progress, clampf(confidence, 0.0, 0.95))
	if force_search or _awareness_state == AwarenessState.IDLE:
		_awareness_state = AwarenessState.ALERT
	_awareness_timer = maxf(_awareness_timer, search_memory_time)
	_search_scan_timer = 0.0


func _enter_combat(target_position: Vector2) -> void:
	_awareness_state = AwarenessState.COMBAT
	_detection_progress = 1.0
	_awareness_timer = search_memory_time
	_search_scan_timer = 0.0
	_remember_target(target_position)


func _enter_search() -> void:
	if not _has_last_known_target:
		clear_target_awareness()
		return

	_awareness_state = AwarenessState.SEARCH
	_detection_progress = 0.0
	_awareness_timer = search_memory_time
	_search_scan_timer = 0.0
	_show_last_seen_marker_if_all_targets_lost(_last_known_target_position)


func _update_search_state(delta: float) -> void:
	if not _has_last_known_target:
		clear_target_awareness()
		return

	_awareness_timer -= delta
	if global_position.distance_squared_to(_last_known_target_position) <= search_arrival_distance * search_arrival_distance:
		if _search_scan_timer <= 0.0:
			_search_scan_timer = search_scan_time
		else:
			_search_scan_timer -= delta
			var scan_angle := sin(Time.get_ticks_msec() * 0.005) * deg_to_rad(65.0)
			_turn_toward((_last_known_target_position - global_position).normalized().rotated(scan_angle), delta)

	if _awareness_timer <= 0.0 or (_search_scan_timer > 0.0 and _search_scan_timer <= delta):
		clear_target_awareness()


func _remember_target(target_position: Vector2) -> void:
	_has_last_known_target = true
	_last_known_target_position = target_position


func _share_current_sighting(delta: float) -> void:
	_direct_sighting_share_timer += delta
	if _direct_sighting_share_timer < alert_share_delay or _has_shared_current_sighting:
		return

	_has_shared_current_sighting = true
	for enemy in get_tree().get_nodes_in_group(TOP_DOWN_ENEMY_GROUP):
		if enemy == self or enemy == null or not is_instance_valid(enemy):
			continue
		if not enemy is Node2D:
			continue

		var enemy_2d := enemy as Node2D
		if global_position.distance_squared_to(enemy_2d.global_position) > shared_alert_range * shared_alert_range:
			continue
		if enemy.has_method("receive_shared_player_sighting"):
			enemy.call("receive_shared_player_sighting", _last_known_target_position, self)


func _can_see_target() -> bool:
	if _target == null or not is_instance_valid(_target):
		return false

	var origin := _get_vision_origin()
	var to_target := _target.global_position - origin
	var distance := to_target.length()
	if distance > detection_range:
		return false
	if distance <= close_detection_range:
		return _has_line_of_sight_to_target()

	var target_direction := to_target / maxf(distance, 0.01)
	var facing := _facing_direction.normalized()
	if facing.length_squared() <= 0.01:
		facing = target_direction
	var angle := absf(facing.angle_to(target_direction))
	if angle > deg_to_rad(view_angle_degrees * 0.5):
		return false

	return _has_line_of_sight_to_target()


func _has_line_of_sight_to_target() -> bool:
	if _target == null or not is_instance_valid(_target):
		return false
	return _has_line_of_sight_to_position(_target.global_position)


func _has_line_of_sight_to_position(target_position: Vector2) -> bool:
	var space_state := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.new()
	query.from = _get_vision_origin()
	query.to = target_position
	query.collision_mask = line_of_sight_blocker_mask
	query.exclude = [get_rid()]
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var hit := space_state.intersect_ray(query)
	if hit.is_empty():
		return true

	return hit.get("collider") == _target


func _get_navigation_direction_to(target_position: Vector2, fallback_direction: Vector2) -> Vector2:
	if not use_navigation or navigation_agent == null or not is_instance_valid(navigation_agent):
		return fallback_direction
	if _has_line_of_sight_to_position(target_position):
		return fallback_direction

	navigation_agent.target_position = target_position
	var next_path_position := navigation_agent.get_next_path_position()
	var to_next := next_path_position - global_position
	if to_next.length_squared() <= 4.0:
		return fallback_direction

	return to_next.normalized()


func _turn_toward(direction: Vector2, delta: float, instant: bool = false) -> void:
	if direction.length_squared() <= 0.01:
		return

	var desired_direction := direction.normalized()
	if instant or delta <= 0.0:
		_set_facing(desired_direction)
		return

	var current_direction := _facing_direction.normalized()
	if current_direction.length_squared() <= 0.01:
		current_direction = desired_direction
	var angle_delta := current_direction.angle_to(desired_direction)
	var max_turn := deg_to_rad(visual_tracking_turn_speed_degrees) * delta
	if absf(angle_delta) <= max_turn:
		_set_facing(desired_direction)
	else:
		_set_facing(current_direction.rotated(signf(angle_delta) * max_turn))


func _set_facing(direction: Vector2) -> void:
	if direction.length_squared() <= 0.01:
		return

	_facing_direction = direction.normalized()
	if body_visual != null:
		body_visual.rotation = _facing_direction.angle()


func _get_vision_origin() -> Vector2:
	return global_position


func _apply_enemy_separation_velocity() -> void:
	if enemy_separation_radius <= 0.0 or enemy_separation_strength <= 0.0:
		return

	var separation := Vector2.ZERO
	var radius_squared := enemy_separation_radius * enemy_separation_radius
	for enemy in get_tree().get_nodes_in_group(TOP_DOWN_ENEMY_GROUP):
		if enemy == self or enemy == null or not is_instance_valid(enemy):
			continue
		if not enemy is Node2D:
			continue

		var enemy_2d := enemy as Node2D
		var away := global_position - enemy_2d.global_position
		var distance_squared := away.length_squared()
		if distance_squared <= 0.01 or distance_squared > radius_squared:
			continue

		var distance := sqrt(distance_squared)
		var strength := 1.0 - clampf(distance / enemy_separation_radius, 0.0, 1.0)
		separation += away / distance * strength

	if separation.length_squared() > 0.01:
		velocity += separation.normalized() * enemy_separation_strength


func _update_debug_label() -> void:
	if _debug_label == null:
		return

	_debug_label.visible = debug_state_visible
	if not debug_state_visible:
		return

	_debug_label.text = _get_awareness_label()


func _get_awareness_label() -> String:
	match _awareness_state:
		AwarenessState.ALERT:
			return "ALERT"
		AwarenessState.COMBAT:
			return "COMBAT"
		AwarenessState.SEARCH:
			return "SEARCH"
		_:
			return "IDLE"


func _update_debug_vision() -> void:
	if _vision_cone == null:
		return

	var should_show := debug_vision_visible and _is_scene_debug_vision_visible()
	_vision_cone.visible = should_show
	if not should_show:
		return

	_vision_cone.color = _get_vision_color()
	_vision_cone.polygon = _build_vision_polygon()


func _get_vision_color() -> Color:
	match _awareness_state:
		AwarenessState.COMBAT:
			return Color(1.0, 0.22, 0.12, 0.16)
		AwarenessState.ALERT:
			return Color(1.0, 0.72, 0.2, 0.14)
		AwarenessState.SEARCH:
			return Color(0.85, 0.92, 0.45, 0.13)
		_:
			return Color(0.48, 0.78, 0.48, 0.1)


func _build_vision_polygon() -> PackedVector2Array:
	var points := PackedVector2Array()
	points.append(to_local(_get_vision_origin()))
	var facing_angle := _facing_direction.angle()
	var half_angle := deg_to_rad(view_angle_degrees * 0.5)
	var segments := maxi(debug_vision_segments, 3)
	var max_distance := minf(detection_range, debug_vision_focus_distance)
	for index in range(segments + 1):
		var t := float(index) / float(segments)
		var angle := facing_angle - half_angle + half_angle * 2.0 * t
		var direction := Vector2.RIGHT.rotated(angle)
		points.append(_get_blocked_vision_point(_get_vision_origin(), direction, max_distance))
	return points


func _get_blocked_vision_point(origin: Vector2, direction: Vector2, vision_range: float) -> Vector2:
	var end_position := origin + direction.normalized() * vision_range
	var space_state := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.new()
	query.from = origin
	query.to = end_position
	query.collision_mask = line_of_sight_blocker_mask
	query.exclude = [get_rid()]
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var hit := space_state.intersect_ray(query)
	if hit.has("position"):
		return to_local(hit.get("position", end_position))
	return to_local(end_position)


func _is_scene_debug_vision_visible() -> bool:
	var current_scene := get_tree().current_scene
	if current_scene != null and current_scene.has_method("is_enemy_debug_vision_visible"):
		return bool(current_scene.call("is_enemy_debug_vision_visible"))
	return true


func _update_detection_bar() -> void:
	if _detection_bar_root == null or _detection_bar_fill == null:
		return

	var should_show := _detection_progress > 0.01 and _awareness_state != AwarenessState.COMBAT
	_detection_bar_root.visible = should_show
	if not should_show:
		return

	var fill_end := Vector2(36.0 * clampf(_detection_progress, 0.0, 1.0), 0.0)
	_detection_bar_fill.points = PackedVector2Array([Vector2.ZERO, fill_end])
	_detection_bar_fill.default_color = Color(1.0, 0.75, 0.16, 0.95).lerp(
		Color(1.0, 0.15, 0.08, 0.98),
		_detection_progress
	)


func _show_last_seen_marker_if_all_targets_lost(marker_position: Vector2) -> void:
	if not debug_last_seen_marker_visible:
		return
	for enemy in get_tree().get_nodes_in_group(TOP_DOWN_ENEMY_GROUP):
		if enemy == null or not is_instance_valid(enemy):
			continue
		if enemy.has_method("is_target_confirmed_visible") and bool(enemy.call("is_target_confirmed_visible")):
			_hide_last_seen_marker()
			return

	var marker := _get_or_create_last_seen_marker()
	if marker != null and marker.has_method("show_sighting"):
		marker.call("show_sighting", marker_position)


func _hide_last_seen_marker() -> void:
	var marker := _get_last_seen_marker()
	if marker != null and marker.has_method("hide_sighting"):
		marker.call("hide_sighting")


func _get_or_create_last_seen_marker() -> Node2D:
	var marker := _get_last_seen_marker()
	if marker != null:
		return marker

	var current_scene := get_tree().current_scene
	if current_scene == null:
		return null

	marker = LAST_SEEN_MARKER_SCRIPT.new()
	marker.name = LAST_SEEN_MARKER_NAME
	current_scene.add_child(marker)
	return marker


func _get_last_seen_marker() -> Node2D:
	var current_scene := get_tree().current_scene
	if current_scene == null:
		return null
	return current_scene.get_node_or_null(LAST_SEEN_MARKER_NAME) as Node2D


func _on_damaged(_amount: int, _current_health: int, _max_health: int) -> void:
	_flash()


func _on_died() -> void:
	if _is_dead:
		return

	_is_dead = true
	collision_layer = 0
	collision_mask = 0
	_notify_mission_enemy_defeated()
	_enemy_died()
	_spawn_vfx(death_vfx_scene, global_position)
	_spawn_loot_container()
	queue_free()


func _notify_mission_enemy_defeated() -> void:
	if mission_target_id == &"":
		return

	var current_scene := get_tree().current_scene
	if current_scene != null and current_scene.has_method("notify_mission_enemy_defeated"):
		current_scene.call("notify_mission_enemy_defeated", mission_target_id, maxi(mission_target_weight, 1), self)


func _enemy_died() -> void:
	pass


func _flash() -> void:
	if body_visual == null:
		return
	if _flash_tween != null:
		_flash_tween.kill()

	body_visual.color = Color(1.0, 0.78, 0.68, 1.0)
	if eye_visual != null:
		eye_visual.color = Color.WHITE
	_flash_tween = create_tween()
	_flash_tween.tween_property(body_visual, "color", _base_body_color, hit_flash_time)
	if eye_visual != null:
		_flash_tween.parallel().tween_property(eye_visual, "color", _base_eye_color, hit_flash_time)


func _spawn_vfx(vfx_scene: PackedScene, spawn_position: Vector2) -> void:
	if vfx_scene == null:
		return

	var vfx := vfx_scene.instantiate()
	var vfx_parent := get_tree().current_scene
	if vfx_parent == null:
		vfx_parent = get_tree().root
	vfx_parent.add_child(vfx)
	if vfx is Node2D:
		var vfx_2d := vfx as Node2D
		vfx_2d.global_position = spawn_position


func _spawn_loot_container() -> void:
	if corpse_container_scene == null:
		if loot_dropper != null and loot_dropper.has_method("drop_at"):
			loot_dropper.call("drop_at", global_position, get_parent())
		return

	var corpse := corpse_container_scene.instantiate()
	var corpse_parent := get_parent()
	if corpse_parent == null:
		corpse_parent = get_tree().current_scene
	if corpse_parent == null:
		corpse_parent = get_tree().root
	corpse_parent.add_child(corpse)

	if corpse is Node2D:
		var corpse_2d := corpse as Node2D
		corpse_2d.global_position = global_position

	var corpse_inventory := corpse.get_node_or_null("Inventory")
	if corpse_inventory == null:
		return

	for loot_entry in _roll_loot_entries():
		var item_id: StringName = loot_entry.get("item_id", &"")
		var quantity: int = int(loot_entry.get("quantity", 1))
		var metadata: Dictionary = loot_entry.get("metadata", {})
		if item_id == &"":
			continue
		if not metadata.is_empty() and corpse_inventory.has_method("add_item_with_metadata"):
			corpse_inventory.call("add_item_with_metadata", item_id, metadata)
		elif corpse_inventory.has_method("add_item"):
			corpse_inventory.call("add_item", item_id, quantity)


func _roll_loot_entries() -> Array[Dictionary]:
	if loot_dropper == null:
		return []
	if loot_dropper.has_method("roll_loot"):
		var result: Variant = loot_dropper.call("roll_loot")
		if result is Array:
			var typed_result: Array[Dictionary] = []
			for entry in result:
				if entry is Dictionary:
					typed_result.append((entry as Dictionary).duplicate(true))
			return typed_result
	return []
