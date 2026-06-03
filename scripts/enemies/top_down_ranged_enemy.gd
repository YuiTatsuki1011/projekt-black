extends CharacterBody2D
class_name TopDownRangedEnemy

const TOP_DOWN_ENEMY_GROUP := "top_down_enemies"
const LAST_SEEN_MARKER_NAME := "LastSeenPlayerMarker"
const LAST_SEEN_MARKER_SCRIPT := preload("res://scripts/enemies/player_sighting_marker.gd")

enum ShootState {
	IDLE,
	TRACKING,
	WINDUP,
	RECOVERY,
}

@export var target_path: NodePath = NodePath("../../Player")
@export var projectile_scene: PackedScene
@export var corpse_container_scene: PackedScene
@export var detection_range: float = 620.0
@export var preferred_range: float = 300.0
@export var retreat_range: float = 150.0
@export var move_speed: float = 82.0
@export var aim_tracking_time: float = 0.45
@export var shot_windup_time: float = 0.5
@export var shot_recovery_time: float = 1.1
@export var initial_shot_delay: float = 0.35
@export var projectile_damage: int = 14
@export var projectile_speed: float = 540.0
@export var telegraph_length: float = 760.0
@export var search_memory_time: float = 2.4
@export_flags_2d_physics var line_of_sight_blocker_mask: int = 1
@export var use_navigation: bool = true
@export var debug_state_visible: bool = true
@export var view_angle_degrees: float = 50.0
@export var close_detection_range: float = 42.0
@export var detection_time: float = 0.8
@export var detection_decay_time: float = 0.65
@export var shared_alert_range: float = 380.0
@export var alert_share_delay: float = 0.35
@export var investigation_time: float = 1.35
@export var debug_vision_visible: bool = true
@export var debug_vision_focus_distance: float = 440.0
@export var debug_vision_segments: int = 24
@export var debug_last_seen_marker_visible: bool = true
@export var hearing_sensitivity: float = 1.0
@export var hit_vfx_scene: PackedScene
@export var death_vfx_scene: PackedScene
@export var knockback_strength: float = 110.0
@export var knockback_recovery: float = 460.0
@export var hit_flash_time: float = 0.08

@onready var health: Node = $Health
@onready var body_visual: Polygon2D = $BodyVisual
@onready var eye_visual: Polygon2D = $BodyVisual/Eye
@onready var gun_root: Node2D = $GunRoot
@onready var muzzle: Marker2D = $GunRoot/Muzzle
@onready var telegraph_line: Line2D = $TelegraphLine
@onready var navigation_agent: NavigationAgent2D = get_node_or_null("NavigationAgent2D") as NavigationAgent2D
@onready var loot_dropper: Node = get_node_or_null("LootDropper")

var _target: Node2D
var _is_dead: bool = false
var _knockback_velocity: Vector2 = Vector2.ZERO
var _base_body_color: Color
var _base_eye_color: Color
var _flash_tween: Tween
var _shoot_state: ShootState = ShootState.RECOVERY
var _shot_timer: float = 0.0
var _locked_direction: Vector2 = Vector2.LEFT
var _has_last_seen_target: bool = false
var _last_seen_target_position: Vector2 = Vector2.ZERO
var _awareness_timer: float = 0.0
var _facing_direction: Vector2 = Vector2.LEFT
var _direct_sighting_share_timer: float = 0.0
var _has_shared_current_sighting: bool = false
var _is_investigating_last_seen: bool = false
var _investigation_timer: float = 0.0
var _detection_progress: float = 0.0
var _debug_label: Label
var _vision_cone: Polygon2D
var _detection_bar_root: Node2D
var _detection_bar_fill: Line2D


func _ready() -> void:
	add_to_group(TOP_DOWN_ENEMY_GROUP)
	_base_body_color = body_visual.color
	_base_eye_color = eye_visual.color
	_resolve_target()
	_configure_navigation_agent()
	_configure_debug_label()
	_configure_vision_cone()
	_configure_detection_bar()
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)
	_shot_timer = initial_shot_delay
	_set_telegraph_visible(false)


func set_target(target: Node2D) -> void:
	_target = target


func _physics_process(delta: float) -> void:
	if _is_dead:
		return

	if _target == null or not is_instance_valid(_target):
		_resolve_target()

	_update_target_awareness(delta)
	_update_shoot_state(delta)
	_update_velocity()
	_update_debug_label()
	_update_debug_vision()
	_update_detection_bar()
	_knockback_velocity = _knockback_velocity.move_toward(Vector2.ZERO, knockback_recovery * delta)
	move_and_slide()


func apply_hit_reaction(direction: Vector2, _damage: int, hit_position: Vector2) -> void:
	var knockback_direction := direction.normalized()
	if knockback_direction == Vector2.ZERO:
		knockback_direction = Vector2.RIGHT

	_knockback_velocity = knockback_direction * knockback_strength
	_react_to_attack_source(knockback_direction)
	_spawn_vfx(hit_vfx_scene, hit_position)
	_flash()


func _resolve_target() -> void:
	_target = get_node_or_null(target_path) as Node2D
	if _target != null:
		return

	var current_scene := get_tree().current_scene
	if current_scene != null:
		_target = current_scene.get_node_or_null("Player") as Node2D


func _update_velocity() -> void:
	velocity = _knockback_velocity
	if not _has_last_seen_target:
		return
	if _is_investigating_last_seen:
		return

	var visible_target := _is_target_visible()
	var target_position := _target.global_position if visible_target else _last_seen_target_position
	var to_target := target_position - global_position
	var target_distance := to_target.length()
	if target_distance <= 0.01:
		return

	var target_direction := to_target / target_distance
	if visible_target and target_distance < retreat_range:
		velocity -= target_direction * move_speed
	elif visible_target and target_distance > preferred_range:
		velocity += _get_navigation_direction_to(target_position, target_direction) * move_speed
	elif not visible_target and target_distance > 24.0:
		_set_aim_direction(target_direction)
		velocity += _get_navigation_direction_to(target_position, target_direction) * move_speed


func _configure_navigation_agent() -> void:
	if navigation_agent == null:
		return

	navigation_agent.path_desired_distance = 12.0
	navigation_agent.target_desired_distance = 18.0


func _configure_debug_label() -> void:
	if not debug_state_visible:
		return

	_debug_label = Label.new()
	_debug_label.name = "DebugStateLabel"
	_debug_label.position = Vector2(-38.0, 26.0)
	_debug_label.size = Vector2(76.0, 16.0)
	_debug_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_debug_label.add_theme_font_size_override("font_size", 8)
	_debug_label.modulate = Color(0.92, 0.72, 0.58, 0.82)
	add_child(_debug_label)


func _configure_vision_cone() -> void:
	if not debug_vision_visible:
		return

	_vision_cone = Polygon2D.new()
	_vision_cone.name = "DebugVisionCone"
	_vision_cone.z_index = 1
	_vision_cone.color = Color(1.0, 0.42, 0.22, 0.12)
	add_child(_vision_cone)


func _configure_detection_bar() -> void:
	_detection_bar_root = Node2D.new()
	_detection_bar_root.name = "DetectionBar"
	_detection_bar_root.position = Vector2(-18.0, -48.0)
	_detection_bar_root.z_index = 24
	_detection_bar_root.visible = false
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


func _update_shoot_state(delta: float) -> void:
	if _target == null or not is_instance_valid(_target):
		_set_telegraph_visible(false)
		return

	match _shoot_state:
		ShootState.IDLE:
			if _can_shoot_target():
				_enter_tracking()
			else:
				_set_telegraph_visible(false)
		ShootState.TRACKING:
			if not _can_shoot_target():
				_enter_search()
				return

			_update_unlocked_aim()
			_shot_timer -= delta
			_update_telegraph_visual(false)
			if _shot_timer <= 0.0:
				_enter_windup()
		ShootState.WINDUP:
			_shot_timer -= delta
			_update_telegraph_visual(true)
			if _shot_timer <= 0.0:
				_fire_locked_shot()
				_enter_recovery(shot_recovery_time)
		ShootState.RECOVERY:
			_set_telegraph_visible(false)
			_shot_timer -= delta
			if _shot_timer <= 0.0:
				_shoot_state = ShootState.IDLE


func _enter_tracking() -> void:
	_shoot_state = ShootState.TRACKING
	_shot_timer = aim_tracking_time
	_share_player_sighting(_last_seen_target_position)
	body_visual.color = Color(0.22, 0.18, 0.15, 1.0)
	eye_visual.color = Color(1.0, 0.25, 0.08, 1.0)
	_set_telegraph_visible(true)
	_update_unlocked_aim()
	_update_telegraph_visual(false)


func _enter_windup() -> void:
	_locked_direction = _get_direction_to_target()
	if _locked_direction.length_squared() <= 0.01:
		_locked_direction = Vector2.LEFT

	_set_aim_direction(_locked_direction)
	_shoot_state = ShootState.WINDUP
	_shot_timer = shot_windup_time
	body_visual.color = Color(0.24, 0.2, 0.16, 1.0)
	eye_visual.color = Color(1.0, 0.18, 0.08, 1.0)
	_set_telegraph_visible(true)
	_update_telegraph_visual(true)


func _enter_recovery(duration: float) -> void:
	_shoot_state = ShootState.RECOVERY
	_shot_timer = duration
	_set_telegraph_visible(false)
	body_visual.color = _base_body_color
	eye_visual.color = _base_eye_color


func _enter_search() -> void:
	_shoot_state = ShootState.IDLE
	_shot_timer = 0.0
	_set_telegraph_visible(false)
	body_visual.color = _base_body_color
	eye_visual.color = _base_eye_color


func _fire_locked_shot() -> void:
	if projectile_scene == null:
		return

	var projectile := projectile_scene.instantiate()
	var projectile_parent := get_tree().current_scene
	if projectile_parent == null:
		projectile_parent = get_parent()
	projectile_parent.add_child(projectile)

	if projectile is Node2D:
		var projectile_2d := projectile as Node2D
		projectile_2d.global_position = muzzle.global_position
		projectile_2d.global_rotation = _locked_direction.angle()

	projectile.set("damage", projectile_damage)
	projectile.set("speed", projectile_speed)
	if projectile.has_method("launch"):
		projectile.call("launch", _locked_direction)

	_share_player_sighting(_last_seen_target_position)
	body_visual.color = Color(0.46, 0.12, 0.08, 1.0)
	eye_visual.color = Color.WHITE


func _update_unlocked_aim() -> void:
	var direction := _get_direction_to_target()
	if direction.length_squared() <= 0.01:
		return

	_set_aim_direction(direction)


func _get_direction_to_target() -> Vector2:
	var aim_position := _get_aim_position()
	if aim_position == Vector2.INF:
		return _locked_direction

	return (aim_position - muzzle.global_position).normalized()


func _set_aim_direction(direction: Vector2) -> void:
	if direction.length_squared() <= 0.01:
		return

	var normalized_direction := direction.normalized()
	_facing_direction = normalized_direction
	var facing := signf(normalized_direction.x)
	if facing == 0.0:
		facing = body_visual.scale.x
	if facing == 0.0:
		facing = 1.0

	body_visual.scale.x = facing
	gun_root.position = Vector2(facing * 11.0, -2.0)
	gun_root.rotation = normalized_direction.angle()
	_locked_direction = normalized_direction


func _can_shoot_target() -> bool:
	return _is_target_visible()


func _update_target_awareness(delta: float) -> void:
	if _target == null or not is_instance_valid(_target):
		_clear_target_awareness()
		return

	if _can_see_target():
		_hide_last_seen_marker()
		if not _has_last_seen_target:
			_detection_progress = minf(1.0, _detection_progress + delta / maxf(detection_time, 0.01))
			if _detection_progress < 1.0:
				return

		_remember_target_position(_target.global_position, true)
		_direct_sighting_share_timer += delta
		if _direct_sighting_share_timer >= alert_share_delay and not _has_shared_current_sighting:
			_share_player_sighting(_last_seen_target_position)
		return

	_direct_sighting_share_timer = 0.0
	_has_shared_current_sighting = false
	if not _has_last_seen_target:
		_detection_progress = maxf(0.0, _detection_progress - delta / maxf(detection_decay_time, 0.01))
		return

	_show_last_seen_marker_if_all_targets_lost(_last_seen_target_position)
	if global_position.distance_squared_to(_last_seen_target_position) <= 24.0 * 24.0:
		if not _is_investigating_last_seen:
			_is_investigating_last_seen = true
			_investigation_timer = investigation_time
		_investigation_timer -= delta
		if _investigation_timer <= 0.0:
			_clear_target_awareness()
		return

	_is_investigating_last_seen = false
	_awareness_timer -= delta
	if _awareness_timer <= 0.0:
		_clear_target_awareness()


func _get_debug_state_text() -> String:
	match _shoot_state:
		ShootState.TRACKING:
			return "TRACK"
		ShootState.WINDUP:
			return "LOCK"
		ShootState.RECOVERY:
			return "RECOVER"

	if _is_target_visible():
		return "READY"
	if _can_see_target() and not _has_last_seen_target:
		return "DETECT"
	if _is_investigating_last_seen:
		return "INVEST"
	if _has_last_seen_target:
		return "SEARCH"
	return "IDLE"


func _update_debug_label() -> void:
	if _debug_label == null:
		return

	_debug_label.visible = debug_state_visible
	_debug_label.text = _get_debug_state_text()


func receive_shared_player_sighting(sighting_position: Vector2, source: Node) -> void:
	if _is_dead or source == self:
		return

	_remember_target_position(sighting_position, false)


func receive_noise_event(noise_position: Vector2, radius: float, source: Node, _noise_type: StringName = &"generic") -> void:
	if _is_dead or source == self:
		return

	var hearing_radius := maxf(radius * hearing_sensitivity, 0.0)
	if global_position.distance_squared_to(noise_position) > hearing_radius * hearing_radius:
		return

	var to_noise := noise_position - global_position
	if to_noise.length_squared() > 0.01:
		_set_aim_direction(to_noise.normalized())
	_remember_target_position(noise_position, false)


func has_direct_target_sighting() -> bool:
	return not _is_dead and _can_see_target()


func has_active_player_sighting() -> bool:
	return not _is_dead and _has_last_seen_target


func is_in_combat_with_target() -> bool:
	if _is_dead:
		return false
	if _shoot_state == ShootState.TRACKING or _shoot_state == ShootState.WINDUP:
		return true
	return _is_target_visible()


func _is_target_visible() -> bool:
	return _has_last_seen_target and _can_see_target()


func _can_see_target() -> bool:
	if _target == null or not is_instance_valid(_target):
		return false
	if global_position.distance_squared_to(_target.global_position) > detection_range * detection_range:
		return false
	if not _is_target_inside_view_cone():
		return false

	return _has_line_of_sight_to_target()


func _is_target_inside_view_cone() -> bool:
	var to_target := _target.global_position - _get_vision_origin()
	var target_distance := to_target.length()
	if target_distance <= close_detection_range:
		return true
	if target_distance <= 0.01:
		return true

	var half_angle := deg_to_rad(view_angle_degrees * 0.5)
	return absf(_facing_direction.normalized().angle_to(to_target.normalized())) <= half_angle


func _get_aim_position() -> Vector2:
	if _target != null and is_instance_valid(_target) and _is_target_visible():
		return _target.global_position
	if _has_last_seen_target:
		return _last_seen_target_position

	return Vector2.INF


func _has_line_of_sight_to_target() -> bool:
	if _target == null or not is_instance_valid(_target):
		return false

	return _has_line_of_sight_to_position(_target.global_position)


func _has_line_of_sight_to_position(target_position: Vector2) -> bool:
	if global_position.distance_squared_to(target_position) <= 1.0:
		return true

	var space_state := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.new()
	query.from = _get_vision_origin()
	query.to = target_position
	query.collision_mask = line_of_sight_blocker_mask
	query.exclude = [get_rid()]
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return space_state.intersect_ray(query).is_empty()


func _get_vision_origin() -> Vector2:
	return global_position


func _remember_target_position(target_position: Vector2, is_direct_sighting: bool) -> void:
	_has_last_seen_target = true
	_last_seen_target_position = target_position
	_awareness_timer = search_memory_time
	_is_investigating_last_seen = false
	_investigation_timer = 0.0
	if is_direct_sighting and debug_last_seen_marker_visible:
		_hide_last_seen_marker()


func _react_to_attack_source(hit_direction: Vector2) -> void:
	var source_position := Vector2.ZERO
	var has_source := false
	if _target != null and is_instance_valid(_target):
		source_position = _target.global_position
		has_source = true
	elif hit_direction.length_squared() > 0.01:
		source_position = global_position - hit_direction.normalized() * 120.0
		has_source = true
	if not has_source:
		return

	var to_source := source_position - global_position
	if to_source.length_squared() > 0.01:
		_set_aim_direction(to_source.normalized())
	_remember_target_position(source_position, false)


func _share_player_sighting(sighting_position: Vector2) -> void:
	_has_shared_current_sighting = true
	if debug_last_seen_marker_visible:
		_show_last_seen_marker_if_all_targets_lost(sighting_position)

	for enemy in get_tree().get_nodes_in_group(TOP_DOWN_ENEMY_GROUP):
		if enemy == self or not is_instance_valid(enemy):
			continue
		if not enemy is Node2D:
			continue

		var enemy_2d := enemy as Node2D
		if global_position.distance_squared_to(enemy_2d.global_position) > shared_alert_range * shared_alert_range:
			continue
		if enemy.has_method("receive_shared_player_sighting"):
			enemy.call("receive_shared_player_sighting", sighting_position, self)


func _clear_target_awareness() -> void:
	_has_last_seen_target = false
	_awareness_timer = 0.0
	_direct_sighting_share_timer = 0.0
	_has_shared_current_sighting = false
	_is_investigating_last_seen = false
	_investigation_timer = 0.0
	_detection_progress = 0.0
	_hide_last_seen_marker_if_no_active_sightings()


func _show_last_seen_marker(marker_position: Vector2) -> void:
	var marker_parent := get_tree().current_scene
	if marker_parent == null:
		marker_parent = get_tree().root

	var marker := marker_parent.get_node_or_null(LAST_SEEN_MARKER_NAME)
	if marker == null:
		marker = Node2D.new()
		marker.name = LAST_SEEN_MARKER_NAME
		marker.set_script(LAST_SEEN_MARKER_SCRIPT)
		marker_parent.add_child(marker)

	if marker.has_method("show_sighting"):
		marker.call("show_sighting", marker_position)


func _show_last_seen_marker_if_all_targets_lost(marker_position: Vector2) -> void:
	if not debug_last_seen_marker_visible:
		return
	if _has_any_direct_target_sighting():
		_hide_last_seen_marker()
		return

	_show_last_seen_marker(marker_position)


func _hide_last_seen_marker() -> void:
	var marker_parent := get_tree().current_scene
	if marker_parent == null:
		marker_parent = get_tree().root

	var marker := marker_parent.get_node_or_null(LAST_SEEN_MARKER_NAME)
	if marker != null and marker.has_method("hide_sighting"):
		marker.call("hide_sighting")


func _hide_last_seen_marker_if_no_active_sightings() -> void:
	if _has_any_active_player_sighting():
		return

	_hide_last_seen_marker()


func _has_any_direct_target_sighting() -> bool:
	for enemy in get_tree().get_nodes_in_group(TOP_DOWN_ENEMY_GROUP):
		if enemy != null and is_instance_valid(enemy) and enemy.has_method("has_direct_target_sighting"):
			if bool(enemy.call("has_direct_target_sighting")):
				return true
	return false


func _has_any_active_player_sighting() -> bool:
	for enemy in get_tree().get_nodes_in_group(TOP_DOWN_ENEMY_GROUP):
		if enemy != null and is_instance_valid(enemy) and enemy.has_method("has_active_player_sighting"):
			if bool(enemy.call("has_active_player_sighting")):
				return true
	return false


func _set_telegraph_visible(is_visible: bool) -> void:
	if telegraph_line == null:
		return

	telegraph_line.visible = is_visible


func _update_telegraph_visual(is_locked_warning: bool = false) -> void:
	if telegraph_line == null:
		return

	var start_position := to_local(muzzle.global_position)
	var end_position := to_local(_get_telegraph_end_position())
	telegraph_line.points = PackedVector2Array([start_position, end_position])

	if is_locked_warning:
		var pulse := 0.34 + sin(Time.get_ticks_msec() * 0.042) * 0.24
		telegraph_line.default_color = Color(1.0, 0.08 + pulse, 0.04, 0.55 + pulse)
	else:
		telegraph_line.default_color = Color(1.0, 0.14, 0.08, 0.38)


func _update_debug_vision() -> void:
	if _vision_cone == null:
		return

	_vision_cone.visible = _is_debug_vision_enabled() and _should_show_debug_vision()
	if not _vision_cone.visible:
		return

	_vision_cone.color = _get_debug_vision_color()
	var points := PackedVector2Array([Vector2.ZERO])
	var half_angle := deg_to_rad(view_angle_degrees * 0.5)
	var segments := maxi(debug_vision_segments, 4)
	for index in range(segments + 1):
		var ratio := float(index) / float(segments)
		var angle := -half_angle + half_angle * 2.0 * ratio
		points.append(_get_clipped_debug_vision_point(_facing_direction.normalized().rotated(angle), detection_range))
	_vision_cone.polygon = points


func _is_debug_vision_enabled() -> bool:
	if not debug_vision_visible:
		return false

	var current_scene := get_tree().current_scene
	if current_scene != null and current_scene.has_method("is_enemy_debug_vision_visible"):
		return bool(current_scene.call("is_enemy_debug_vision_visible"))

	return true


func _should_show_debug_vision() -> bool:
	if _target == null or not is_instance_valid(_target):
		return _has_last_seen_target
	if _has_last_seen_target or _detection_progress > 0.01:
		return true

	return global_position.distance_squared_to(_target.global_position) <= debug_vision_focus_distance * debug_vision_focus_distance


func _get_debug_vision_color() -> Color:
	if _is_target_visible():
		return Color(1.0, 0.14, 0.08, 0.2)
	if _detection_progress > 0.01:
		return Color(1.0, 0.74, 0.1, 0.12 + 0.12 * _detection_progress)
	if _has_last_seen_target:
		return Color(0.42, 0.62, 1.0, 0.09)

	return Color(0.9, 0.52, 0.36, 0.045)


func _get_clipped_debug_vision_point(direction: Vector2, vision_range: float) -> Vector2:
	var origin := _get_vision_origin()
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


func _update_detection_bar() -> void:
	if _detection_bar_root == null or _detection_bar_fill == null:
		return

	var should_show := _detection_progress > 0.01 and not _has_last_seen_target
	_detection_bar_root.visible = should_show
	if not should_show:
		return

	var fill_end := Vector2(36.0 * clampf(_detection_progress, 0.0, 1.0), 0.0)
	_detection_bar_fill.points = PackedVector2Array([Vector2.ZERO, fill_end])
	_detection_bar_fill.default_color = Color(1.0, 0.75, 0.16, 0.95).lerp(
		Color(1.0, 0.15, 0.08, 0.98),
		_detection_progress
	)


func _get_telegraph_end_position() -> Vector2:
	var start_position := muzzle.global_position
	var end_position := start_position + _locked_direction * telegraph_length
	var space_state := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.new()
	query.from = start_position
	query.to = end_position
	query.collision_mask = line_of_sight_blocker_mask
	query.exclude = [get_rid()]
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var hit := space_state.intersect_ray(query)
	if hit.has("position"):
		return hit.get("position", end_position)

	return end_position


func _on_damaged(_amount: int, _current_health: int, _max_health: int) -> void:
	_flash()


func _on_died() -> void:
	if _is_dead:
		return

	_is_dead = true
	collision_layer = 0
	collision_mask = 0
	_set_telegraph_visible(false)
	_spawn_vfx(death_vfx_scene, global_position)
	_spawn_loot_container()
	queue_free()


func _flash() -> void:
	if _flash_tween != null:
		_flash_tween.kill()

	body_visual.color = Color(0.95, 0.82, 0.72, 1.0)
	eye_visual.color = Color.WHITE
	_flash_tween = create_tween()
	_flash_tween.tween_property(body_visual, "color", _base_body_color, hit_flash_time)
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
		return loot_dropper.call("roll_loot")
	return []
