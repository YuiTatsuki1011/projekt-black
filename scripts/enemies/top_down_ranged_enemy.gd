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

enum AwarenessState {
	IDLE,
	SUSPICIOUS,
	INVESTIGATE,
	COMBAT,
	SEARCH,
}

enum EnemyArchetype {
	LIGHT_MELEE,
	LIGHT_FIREARM,
	HEAVY_ASSAULT,
	SUPPORT,
	BEAST,
}

enum EnemyPersonality {
	BALANCED,
	BRAVE,
	CAUTIOUS,
	COWARDLY,
	PROTECTIVE,
	SELFISH,
}

enum GroupTacticRole {
	NONE,
	DIRECT,
	LEFT_FLANK,
	RIGHT_FLANK,
	REAR_PRESSURE,
	SUPPRESS,
	GUARD,
	FALLBACK,
}

enum LostTargetDecision {
	NONE,
	AGGRESSIVE_SEARCH,
	CAUTIOUS_SEARCH,
	FIGHTING_RETREAT,
	PANIC_FLEE,
	REGROUP,
}

enum LostTargetSquadRole {
	NONE,
	OVERWATCH,
	SWEEP_LEFT,
	SWEEP_RIGHT,
	PRESSURE,
}

enum CoverActionState {
	NONE,
	MOVING,
	HIDE,
	PEEK,
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
@export var post_combat_search_memory_time: float = 6.0
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
@export var post_combat_investigation_time: float = 3.0
@export var suspicious_pause_time: float = 0.4
@export var shared_sighting_confidence: float = 0.75
@export var hearing_confidence: float = 0.45
@export var gunshot_hearing_confidence: float = 0.7
@export var hit_confidence: float = 0.9
@export var visual_tracking_turn_speed_degrees: float = 500.0
@export var pursuit_prediction_time: float = 0.55
@export var max_pursuit_prediction_distance: float = 96.0
@export var combat_peripheral_tracking_time: float = 0.5
@export var clearing_scan_angle_degrees: float = 62.0
@export var clearing_scan_step_time: float = 0.3
@export var corner_clearing_angle_degrees: float = 24.0
@export var corner_clearing_sweep_speed: float = 4.8
@export var search_probe_radius: float = 96.0
@export var search_probe_investigation_time: float = 0.9
@export_enum("Light Melee", "Light Firearm", "Heavy Assault", "Support", "Beast") var ai_archetype: int = EnemyArchetype.LIGHT_FIREARM
@export_enum("Balanced", "Brave", "Cautious", "Cowardly", "Protective", "Selfish") var ai_personality: int = EnemyPersonality.CAUTIOUS
@export_range(0, 10, 1) var unit_importance: int = 2
@export_range(0.0, 1.0, 0.05) var ally_priority: float = 0.3
@export_range(0.0, 1.0, 0.05) var self_preservation: float = 0.55
@export var morale_enabled: bool = true
@export_range(0.0, 100.0, 1.0) var base_morale: float = 58.0
@export_range(0.0, 100.0, 1.0) var morale_break_threshold: float = 30.0
@export_range(0.0, 40.0, 1.0) var morale_recover_margin: float = 12.0
@export var morale_low_health_penalty: float = 36.0
@export var morale_alone_penalty: float = 18.0
@export var morale_ally_bonus: float = 8.0
@export var morale_fallback_distance: float = 150.0
@export var morale_fallback_speed_multiplier: float = 1.08
@export var group_tactics_enabled: bool = true
@export var group_tactic_range: float = 320.0
@export var flank_offset_distance: float = 96.0
@export var rear_pressure_offset_distance: float = 128.0
@export var cover_usage_enabled: bool = true
@export var cover_search_radius: float = 190.0
@export var cover_probe_count: int = 18
@export var cover_repath_interval: float = 0.7
@export var cover_arrival_distance: float = 18.0
@export var cover_shape_radius: float = 16.0
@export var cover_min_threat_distance: float = 130.0
@export var cover_adjacency_distance: float = 64.0
@export var cover_hide_offset: float = 34.0
@export var cover_peek_hold_time_min: float = 0.75
@export var cover_peek_hold_time_max: float = 1.35
@export var cover_hide_hold_time_min: float = 0.45
@export var cover_hide_hold_time_max: float = 1.0
@export var lost_target_tactics_enabled: bool = true
@export var lost_target_advantage_threshold: float = 18.0
@export var lost_target_disadvantage_threshold: float = -18.0
@export var aggressive_search_memory_multiplier: float = 1.8
@export var cautious_search_memory_multiplier: float = 1.25
@export var retreat_search_memory_multiplier: float = 1.15
@export var aggressive_search_speed_multiplier: float = 1.12
@export var cautious_search_speed_multiplier: float = 0.76
@export var fighting_retreat_speed_multiplier: float = 0.92
@export var panic_flee_speed_multiplier: float = 1.18
@export var lost_target_retreat_distance: float = 230.0
@export var lost_target_regroup_range: float = 360.0
@export var lost_target_squad_tactics_enabled: bool = true
@export var lost_target_sweep_offset_distance: float = 132.0
@export var lost_target_sweep_forward_distance: float = 86.0
@export var lost_target_overwatch_hold_distance: float = 220.0
@export var lost_target_overwatch_scan_angle_degrees: float = 18.0
@export var lost_target_overwatch_scan_speed: float = 2.2
@export var tactical_ammo_capacity: int = 8
@export var tactical_low_ammo_threshold: int = 2
@export var debug_vision_visible: bool = true
@export var debug_vision_focus_distance: float = 440.0
@export var debug_vision_segments: int = 24
@export var debug_last_seen_marker_visible: bool = true
@export var enemy_separation_radius: float = 44.0
@export var enemy_separation_strength: float = 145.0
@export var enemy_local_avoidance_enabled: bool = true
@export var enemy_avoidance_lookahead: float = 74.0
@export var enemy_avoidance_width: float = 34.0
@export var enemy_avoidance_strength: float = 165.0
@export_range(0.0, 1.0, 0.05) var enemy_avoidance_slowdown: float = 0.62
@export var enemy_avoidance_side_hold_time: float = 0.36
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
var _awareness_state: AwarenessState = AwarenessState.IDLE
var _stimulus_confidence: float = 0.0
var _suspicious_timer: float = 0.0
var _last_stimulus_type: StringName = &"none"
var _has_visual_target_sample: bool = false
var _last_visual_target_position: Vector2 = Vector2.ZERO
var _estimated_target_velocity: Vector2 = Vector2.ZERO
var _combat_peripheral_tracking_timer: float = 0.0
var _clearing_scan_directions: Array[Vector2] = []
var _clearing_scan_index: int = 0
var _clearing_scan_step_timer: float = 0.0
var _corner_clearing_phase: float = 0.0
var _is_post_combat_search: bool = false
var _search_probe_points: Array[Vector2] = []
var _search_probe_index: int = 0
var _has_search_probe_plan: bool = false
var _is_search_probe_target: bool = false
var _current_group_role: int = GroupTacticRole.NONE
var _is_fallback_active: bool = false
var _cover_target_position: Vector2 = Vector2.INF
var _cover_repath_timer: float = 0.0
var _is_using_cover: bool = false
var _cover_action_state: int = CoverActionState.NONE
var _cover_action_timer: float = 0.0
var _cover_peek_position: Vector2 = Vector2.INF
var _cover_hide_position: Vector2 = Vector2.INF
var _lost_target_decision: int = LostTargetDecision.NONE
var _lost_target_squad_role: int = LostTargetSquadRole.NONE
var _lost_target_advantage_score: float = 0.0
var _tactical_ammo_remaining: int = 0
var _enemy_avoidance_side: float = 0.0
var _enemy_avoidance_side_timer: float = 0.0
var _is_avoiding_enemy: bool = false
var _is_blocked_by_enemy: bool = false
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
	_tactical_ammo_remaining = tactical_ammo_capacity
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
	_update_visual_tracking(delta)
	_update_shoot_state(delta)
	_cover_repath_timer = maxf(_cover_repath_timer - delta, 0.0)
	_cover_action_timer = maxf(_cover_action_timer - delta, 0.0)
	_update_velocity(delta)
	_apply_enemy_separation_velocity()
	_apply_enemy_local_avoidance_velocity(delta)
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


func _update_velocity(delta: float) -> void:
	velocity = _knockback_velocity
	_is_using_cover = false
	if not _has_last_seen_target:
		return
	if _awareness_state == AwarenessState.SUSPICIOUS:
		return
	if _is_investigating_last_seen and not _should_move_while_investigating_lost_target():
		return
	if _is_morale_broken():
		_apply_fallback_velocity()
		return

	var visible_target := _is_target_visible()
	var target_position := _target.global_position if visible_target else _last_seen_target_position
	var maintaining_cover := _cover_action_state != CoverActionState.NONE and _cover_target_position != Vector2.INF
	if not visible_target and not maintaining_cover and _apply_lost_target_decision_velocity(target_position, delta):
		return

	var movement_position := _get_lost_target_squad_movement_position(target_position) if not visible_target else Vector2.INF
	if movement_position != Vector2.INF:
		_current_group_role = GroupTacticRole.NONE
	else:
		movement_position = _get_group_pursuit_position(target_position)
	var cover_position := _get_cover_movement_position(target_position, visible_target or maintaining_cover, movement_position)
	if cover_position != Vector2.INF:
		_move_toward_cover(cover_position, target_position)
		return

	var to_target := movement_position - global_position
	var target_distance := to_target.length()
	if target_distance <= 0.01:
		if _lost_target_squad_role == LostTargetSquadRole.OVERWATCH and not visible_target:
			_hold_lost_target_overwatch(target_position, delta)
		return

	var target_direction := to_target / target_distance
	if visible_target and target_distance < retreat_range:
		velocity -= target_direction * move_speed
	elif visible_target and target_distance > preferred_range:
		velocity += _get_navigation_direction_to(movement_position, target_direction) * move_speed
	elif not visible_target and target_distance > 24.0:
		var move_direction := _get_navigation_direction_to(movement_position, target_direction)
		velocity += move_direction * move_speed * _get_lost_target_search_speed_multiplier()
		if _has_line_of_sight_to_position(movement_position):
			_set_aim_direction(target_direction)
		else:
			_turn_aim_toward(_get_corner_clearing_direction(move_direction, target_direction, delta), delta)


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
	_debug_label.position = Vector2(-62.0, 26.0)
	_debug_label.size = Vector2(124.0, 18.0)
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


func _get_group_pursuit_position(base_position: Vector2) -> Vector2:
	var role := _get_group_tactic_role()
	_current_group_role = role
	if role == GroupTacticRole.NONE:
		return base_position

	var approach_direction := (base_position - global_position).normalized()
	if approach_direction.length_squared() <= 0.01:
		approach_direction = _facing_direction.normalized()
	if approach_direction.length_squared() <= 0.01:
		return base_position

	var side_direction := Vector2(-approach_direction.y, approach_direction.x)
	match role:
		GroupTacticRole.LEFT_FLANK:
			return base_position + side_direction * flank_offset_distance
		GroupTacticRole.RIGHT_FLANK:
			return base_position - side_direction * flank_offset_distance
		GroupTacticRole.REAR_PRESSURE:
			return base_position + approach_direction * rear_pressure_offset_distance
		GroupTacticRole.SUPPRESS:
			if _has_line_of_sight_to_position(base_position):
				return global_position
		GroupTacticRole.GUARD:
			var guard_position := _get_guard_position(base_position)
			if guard_position != Vector2.INF:
				return guard_position

	return base_position


func _get_cover_movement_position(threat_position: Vector2, visible_target: bool, movement_position: Vector2) -> Vector2:
	if not _should_seek_cover(threat_position, visible_target):
		_clear_cover_target()
		return Vector2.INF
	if _is_valid_cover_position(_cover_target_position, threat_position):
		_is_using_cover = true
		_update_cover_action_state(threat_position)
		return _get_active_cover_action_position()
	if _cover_repath_timer > 0.0:
		return Vector2.INF

	_cover_repath_timer = cover_repath_interval
	_cover_target_position = _find_cover_position(threat_position, movement_position)
	_configure_cover_action_positions(threat_position)
	_is_using_cover = _cover_target_position != Vector2.INF
	return _get_active_cover_action_position()


func _should_seek_cover(threat_position: Vector2, visible_target: bool) -> bool:
	if not cover_usage_enabled or not visible_target:
		return false
	if _shoot_state == ShootState.WINDUP and _cover_action_state == CoverActionState.NONE:
		return false
	if ai_archetype == EnemyArchetype.LIGHT_MELEE or ai_archetype == EnemyArchetype.BEAST:
		return false
	if ai_archetype == EnemyArchetype.HEAVY_ASSAULT and _current_group_role == GroupTacticRole.DIRECT:
		return false
	if global_position.distance_squared_to(threat_position) < cover_min_threat_distance * cover_min_threat_distance:
		return false
	if _current_group_role == GroupTacticRole.SUPPRESS:
		return true
	if ai_personality == EnemyPersonality.CAUTIOUS or ai_personality == EnemyPersonality.COWARDLY:
		return true
	if _get_health_ratio() < 0.55 and self_preservation >= 0.5:
		return true

	return _get_active_group_members().size() > 1 and ai_archetype == EnemyArchetype.LIGHT_FIREARM


func _find_cover_position(threat_position: Vector2, movement_position: Vector2) -> Vector2:
	var best_position := Vector2.INF
	var best_score := -INF
	var probes := maxi(cover_probe_count, 6)
	var desired_range := clampf(preferred_range, retreat_range + 32.0, detection_range)
	var radius_steps := [0.35, 0.62, 0.86, 1.0]

	for radius_ratio in radius_steps:
		var radius := cover_search_radius * float(radius_ratio)
		for index in range(probes):
			var angle := TAU * float(index) / float(probes)
			var candidate := global_position + Vector2.RIGHT.rotated(angle) * radius
			var score := _score_cover_position(candidate, threat_position, movement_position, desired_range)
			if score > best_score:
				best_score = score
				best_position = candidate

	if best_position == Vector2.INF:
		return Vector2.INF

	return best_position


func _score_cover_position(
	candidate: Vector2,
	threat_position: Vector2,
	movement_position: Vector2,
	desired_range: float
) -> float:
	if not _is_position_clear(candidate):
		return -INF
	if not _has_clear_line_between(candidate, threat_position):
		return -INF

	var threat_distance := candidate.distance_to(threat_position)
	if threat_distance < cover_min_threat_distance:
		return -INF
	if threat_distance > detection_range * 1.05:
		return -INF

	var cover_distance := _get_cover_adjacency_distance(candidate, threat_position)
	if cover_distance == INF:
		return -INF

	var travel_distance := global_position.distance_to(candidate)
	var role_distance := candidate.distance_to(movement_position)
	var range_penalty := absf(threat_distance - desired_range)
	var cover_bonus := cover_adjacency_distance - cover_distance
	var score := cover_bonus * 1.4
	score -= travel_distance * 0.34
	score -= role_distance * 0.12
	score -= range_penalty * 0.22
	if ai_personality == EnemyPersonality.CAUTIOUS:
		score += 18.0
	elif ai_personality == EnemyPersonality.COWARDLY:
		score += 28.0
	if _current_group_role == GroupTacticRole.SUPPRESS:
		score += 22.0

	return score


func _is_valid_cover_position(position: Vector2, threat_position: Vector2) -> bool:
	if position == Vector2.INF:
		return false
	if not _is_position_clear(position):
		return false
	if not _has_clear_line_between(position, threat_position):
		return false
	if position.distance_squared_to(threat_position) < cover_min_threat_distance * cover_min_threat_distance:
		return false

	return _get_cover_adjacency_distance(position, threat_position) != INF


func _is_position_clear(position: Vector2) -> bool:
	var shape := CircleShape2D.new()
	shape.radius = cover_shape_radius

	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, position)
	query.collision_mask = line_of_sight_blocker_mask
	query.exclude = [get_rid()]
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()


func _has_clear_line_between(from_position: Vector2, to_position: Vector2) -> bool:
	if from_position.distance_squared_to(to_position) <= 1.0:
		return true

	var query := PhysicsRayQueryParameters2D.new()
	query.from = from_position
	query.to = to_position
	query.collision_mask = line_of_sight_blocker_mask
	query.exclude = [get_rid()]
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()


func _get_cover_adjacency_distance(candidate: Vector2, threat_position: Vector2) -> float:
	var away_from_threat := candidate - threat_position
	if away_from_threat.length_squared() <= 0.01:
		away_from_threat = candidate - global_position
	if away_from_threat.length_squared() <= 0.01:
		away_from_threat = _facing_direction
	if away_from_threat.length_squared() <= 0.01:
		away_from_threat = Vector2.RIGHT

	var away := away_from_threat.normalized()
	var side := Vector2(-away.y, away.x)
	var probe_directions := [
		away,
		-away,
		side,
		-side,
		(away + side).normalized(),
		(away - side).normalized(),
	]
	var closest_distance := INF
	for direction in probe_directions:
		if direction.length_squared() <= 0.01:
			continue
		var hit_distance := _get_blocker_distance(candidate, direction.normalized(), cover_adjacency_distance)
		if hit_distance < closest_distance:
			closest_distance = hit_distance

	return closest_distance


func _get_blocker_distance(from_position: Vector2, direction: Vector2, max_distance: float) -> float:
	var query := PhysicsRayQueryParameters2D.new()
	query.from = from_position
	query.to = from_position + direction * max_distance
	query.collision_mask = line_of_sight_blocker_mask
	query.exclude = [get_rid()]
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if not hit.has("position"):
		return INF

	return from_position.distance_to(hit.get("position", query.to))


func _move_toward_cover(cover_position: Vector2, threat_position: Vector2) -> void:
	var to_cover := cover_position - global_position
	if to_cover.length_squared() > cover_arrival_distance * cover_arrival_distance:
		velocity += _get_navigation_direction_to(cover_position, to_cover.normalized()) * move_speed

	var to_threat := threat_position - global_position
	if to_threat.length_squared() > 0.01:
		_set_aim_direction(to_threat.normalized())


func _clear_cover_target() -> void:
	_cover_target_position = Vector2.INF
	_is_using_cover = false
	_cover_action_state = CoverActionState.NONE
	_cover_action_timer = 0.0
	_cover_peek_position = Vector2.INF
	_cover_hide_position = Vector2.INF


func _configure_cover_action_positions(threat_position: Vector2) -> void:
	if _cover_target_position == Vector2.INF:
		_clear_cover_target()
		return

	_cover_peek_position = _cover_target_position
	_cover_hide_position = _find_cover_hide_position(_cover_peek_position, threat_position)
	_cover_action_state = CoverActionState.MOVING
	_cover_action_timer = 0.0


func _update_cover_action_state(threat_position: Vector2) -> void:
	if _cover_target_position == Vector2.INF:
		_clear_cover_target()
		return
	if _cover_peek_position == Vector2.INF:
		_configure_cover_action_positions(threat_position)

	if _cover_hide_position == Vector2.INF or _has_clear_line_between(_cover_hide_position, threat_position):
		_cover_hide_position = _find_cover_hide_position(_cover_peek_position, threat_position)

	match _cover_action_state:
		CoverActionState.NONE:
			_cover_action_state = CoverActionState.MOVING
		CoverActionState.MOVING:
			if global_position.distance_squared_to(_cover_peek_position) <= cover_arrival_distance * cover_arrival_distance:
				_enter_cover_hide()
		CoverActionState.HIDE:
			if _cover_action_timer <= 0.0:
				_enter_cover_peek()
		CoverActionState.PEEK:
			if _cover_action_timer <= 0.0 and _shoot_state != ShootState.TRACKING and _shoot_state != ShootState.WINDUP:
				_enter_cover_hide()


func _get_active_cover_action_position() -> Vector2:
	match _cover_action_state:
		CoverActionState.HIDE:
			if _cover_hide_position != Vector2.INF:
				return _cover_hide_position
		CoverActionState.PEEK:
			if _cover_peek_position != Vector2.INF:
				return _cover_peek_position

	return _cover_target_position


func _enter_cover_hide() -> void:
	_cover_action_state = CoverActionState.HIDE
	var min_time := minf(cover_hide_hold_time_min, cover_hide_hold_time_max)
	var max_time := maxf(cover_hide_hold_time_min, cover_hide_hold_time_max)
	_cover_action_timer = randf_range(min_time, max_time)
	if _shoot_state == ShootState.TRACKING:
		_enter_search()


func _enter_cover_peek() -> void:
	_cover_action_state = CoverActionState.PEEK
	var min_time := minf(cover_peek_hold_time_min, cover_peek_hold_time_max)
	var max_time := maxf(cover_peek_hold_time_min, cover_peek_hold_time_max)
	_cover_action_timer = randf_range(min_time, max_time)


func _find_cover_hide_position(peek_position: Vector2, threat_position: Vector2) -> Vector2:
	var away_from_threat := peek_position - threat_position
	if away_from_threat.length_squared() <= 0.01:
		away_from_threat = peek_position - global_position
	if away_from_threat.length_squared() <= 0.01:
		away_from_threat = _facing_direction
	if away_from_threat.length_squared() <= 0.01:
		away_from_threat = Vector2.RIGHT

	var away := away_from_threat.normalized()
	var side := Vector2(-away.y, away.x)
	var candidate_offsets: Array[Vector2] = [
		away,
		(away + side * 0.55).normalized(),
		(away - side * 0.55).normalized(),
		side,
		-side,
	]
	for direction: Vector2 in candidate_offsets:
		if direction.length_squared() <= 0.01:
			continue

		var candidate: Vector2 = peek_position + direction.normalized() * cover_hide_offset
		if not _is_position_clear(candidate):
			continue
		if _has_clear_line_between(candidate, threat_position):
			continue
		return candidate

	return peek_position


func _enter_lost_target_search() -> void:
	_awareness_state = AwarenessState.SEARCH
	_detection_progress = 0.0
	_combat_peripheral_tracking_timer = 0.0
	_is_post_combat_search = true
	_is_search_probe_target = false
	_has_search_probe_plan = false
	_search_probe_points.clear()
	_search_probe_index = 0
	_choose_lost_target_decision()
	_choose_lost_target_squad_role()
	_clear_cover_target()

	var memory_time := post_combat_search_memory_time
	match _lost_target_decision:
		LostTargetDecision.AGGRESSIVE_SEARCH:
			memory_time *= aggressive_search_memory_multiplier
		LostTargetDecision.CAUTIOUS_SEARCH:
			memory_time *= cautious_search_memory_multiplier
		LostTargetDecision.FIGHTING_RETREAT, LostTargetDecision.PANIC_FLEE, LostTargetDecision.REGROUP:
			memory_time *= retreat_search_memory_multiplier

	_awareness_timer = maxf(_awareness_timer, memory_time)


func _choose_lost_target_decision() -> void:
	if not lost_target_tactics_enabled:
		_lost_target_decision = LostTargetDecision.AGGRESSIVE_SEARCH
		_lost_target_advantage_score = 0.0
		return

	_lost_target_advantage_score = _get_combat_advantage_score()
	if _lost_target_advantage_score >= lost_target_advantage_threshold:
		if ai_personality == EnemyPersonality.CAUTIOUS and _get_health_ratio() < 0.7:
			_lost_target_decision = LostTargetDecision.CAUTIOUS_SEARCH
		else:
			_lost_target_decision = LostTargetDecision.AGGRESSIVE_SEARCH
		return

	if _lost_target_advantage_score <= lost_target_disadvantage_threshold:
		if _should_panic_flee():
			_lost_target_decision = LostTargetDecision.PANIC_FLEE
		elif _get_regroup_position() != Vector2.INF:
			_lost_target_decision = LostTargetDecision.REGROUP
		else:
			_lost_target_decision = LostTargetDecision.FIGHTING_RETREAT
		return

	if ai_personality == EnemyPersonality.BRAVE or ai_archetype == EnemyArchetype.HEAVY_ASSAULT:
		_lost_target_decision = LostTargetDecision.AGGRESSIVE_SEARCH
	elif ai_personality == EnemyPersonality.COWARDLY and _get_regroup_position() != Vector2.INF:
		_lost_target_decision = LostTargetDecision.REGROUP
	else:
		_lost_target_decision = LostTargetDecision.CAUTIOUS_SEARCH


func _choose_lost_target_squad_role() -> void:
	if not lost_target_squad_tactics_enabled:
		_lost_target_squad_role = LostTargetSquadRole.NONE
		return
	if (
		_lost_target_decision == LostTargetDecision.FIGHTING_RETREAT
		or _lost_target_decision == LostTargetDecision.PANIC_FLEE
		or _lost_target_decision == LostTargetDecision.REGROUP
	):
		_lost_target_squad_role = LostTargetSquadRole.NONE
		return

	var members := _get_active_group_members()
	if members.size() <= 1:
		_lost_target_squad_role = LostTargetSquadRole.NONE
		return

	var rank := _get_group_rank(members)
	match rank % 4:
		0:
			_lost_target_squad_role = LostTargetSquadRole.OVERWATCH
		1:
			_lost_target_squad_role = LostTargetSquadRole.SWEEP_LEFT
		2:
			_lost_target_squad_role = LostTargetSquadRole.SWEEP_RIGHT
		_:
			_lost_target_squad_role = LostTargetSquadRole.PRESSURE


func _should_move_while_investigating_lost_target() -> bool:
	return (
		_lost_target_squad_role == LostTargetSquadRole.SWEEP_LEFT
		or _lost_target_squad_role == LostTargetSquadRole.SWEEP_RIGHT
		or _lost_target_squad_role == LostTargetSquadRole.PRESSURE
	)


func _get_lost_target_squad_movement_position(base_position: Vector2) -> Vector2:
	if _lost_target_squad_role == LostTargetSquadRole.NONE:
		return Vector2.INF

	var approach_direction := (base_position - global_position).normalized()
	if approach_direction.length_squared() <= 0.01:
		approach_direction = _facing_direction.normalized()
	if approach_direction.length_squared() <= 0.01:
		approach_direction = Vector2.RIGHT

	var side_direction := Vector2(-approach_direction.y, approach_direction.x)
	var preferred_position := Vector2.INF
	match _lost_target_squad_role:
		LostTargetSquadRole.OVERWATCH:
			var watch_distance := global_position.distance_to(base_position)
			if watch_distance <= lost_target_overwatch_hold_distance and _has_line_of_sight_to_position(base_position):
				return global_position
			preferred_position = base_position - approach_direction * minf(lost_target_overwatch_hold_distance, preferred_range)
		LostTargetSquadRole.SWEEP_LEFT:
			preferred_position = base_position + side_direction * lost_target_sweep_offset_distance + approach_direction * lost_target_sweep_forward_distance
		LostTargetSquadRole.SWEEP_RIGHT:
			preferred_position = base_position - side_direction * lost_target_sweep_offset_distance + approach_direction * lost_target_sweep_forward_distance
		LostTargetSquadRole.PRESSURE:
			preferred_position = base_position + approach_direction * lost_target_sweep_forward_distance

	return _get_clear_lost_target_squad_position(preferred_position, base_position)


func _get_clear_lost_target_squad_position(preferred_position: Vector2, base_position: Vector2) -> Vector2:
	if preferred_position == Vector2.INF:
		return Vector2.INF
	if _is_position_clear(preferred_position):
		return preferred_position

	var base_direction := (preferred_position - base_position).normalized()
	if base_direction.length_squared() <= 0.01:
		base_direction = (base_position - global_position).normalized()
	if base_direction.length_squared() <= 0.01:
		base_direction = _facing_direction.normalized()
	if base_direction.length_squared() <= 0.01:
		base_direction = Vector2.RIGHT

	var side_direction := Vector2(-base_direction.y, base_direction.x)
	var offsets: Array[Vector2] = [
		side_direction * 44.0,
		-side_direction * 44.0,
		base_direction * 44.0,
		-base_direction * 44.0,
		(side_direction + base_direction).normalized() * 66.0,
		(-side_direction + base_direction).normalized() * 66.0,
		(side_direction - base_direction).normalized() * 66.0,
		(-side_direction - base_direction).normalized() * 66.0,
	]
	for offset: Vector2 in offsets:
		if offset.length_squared() <= 0.01:
			continue

		var candidate: Vector2 = preferred_position + offset
		if _is_position_clear(candidate):
			return candidate

	if _is_position_clear(base_position):
		return base_position

	return preferred_position


func _hold_lost_target_overwatch(target_position: Vector2, delta: float) -> void:
	var to_target := target_position - global_position
	if to_target.length_squared() <= 0.01:
		return

	var base_direction := to_target.normalized()
	_corner_clearing_phase += delta * lost_target_overwatch_scan_speed
	var scan_angle := deg_to_rad(lost_target_overwatch_scan_angle_degrees) * sin(_corner_clearing_phase)
	_turn_aim_toward(base_direction.rotated(scan_angle), delta)


func _get_combat_advantage_score() -> float:
	var score := 0.0
	var health_ratio := _get_health_ratio()
	score += (health_ratio - 0.5) * 78.0
	score += (_get_target_vulnerability_score() - 0.5) * 52.0
	score += (_get_morale_score() - 50.0) * 0.35

	var allies := maxi(_get_active_group_members().size() - 1, 0)
	score += minf(float(allies), 3.0) * 13.0
	if allies <= 0:
		score -= 6.0

	score -= _get_tactical_ammo_pressure() * 24.0
	score -= self_preservation * 7.0
	match ai_personality:
		EnemyPersonality.BRAVE:
			score += 18.0
		EnemyPersonality.CAUTIOUS:
			score -= 4.0
		EnemyPersonality.COWARDLY:
			score -= 22.0
		EnemyPersonality.PROTECTIVE:
			if allies > 0:
				score += 8.0
			else:
				score -= 5.0
		EnemyPersonality.SELFISH:
			if health_ratio < 0.5:
				score -= 10.0
			else:
				score += 4.0

	match ai_archetype:
		EnemyArchetype.HEAVY_ASSAULT:
			score += 15.0
		EnemyArchetype.BEAST:
			score += 8.0
		EnemyArchetype.SUPPORT:
			score -= 12.0
		EnemyArchetype.LIGHT_FIREARM:
			if allies > 0:
				score += 4.0

	return score


func _get_target_vulnerability_score() -> float:
	if _target == null or not is_instance_valid(_target):
		return 0.5

	var target_health := _target.get_node_or_null("Health")
	if target_health == null:
		return 0.5

	var max_health_value := int(target_health.get("max_health"))
	if max_health_value <= 0:
		return 0.5

	var current_health_value := int(target_health.get("current_health"))
	var target_health_ratio := clampf(float(current_health_value) / float(max_health_value), 0.0, 1.0)
	return 1.0 - target_health_ratio


func _get_tactical_ammo_pressure() -> float:
	if tactical_ammo_capacity <= 0:
		return 0.0

	return 1.0 - clampf(float(_tactical_ammo_remaining) / float(tactical_ammo_capacity), 0.0, 1.0)


func _should_panic_flee() -> bool:
	if ai_archetype == EnemyArchetype.BEAST:
		return false
	if ai_personality == EnemyPersonality.BRAVE:
		return false
	if ai_personality == EnemyPersonality.COWARDLY:
		return true
	if _get_health_ratio() <= 0.28:
		return true
	if tactical_ammo_capacity > 0 and _tactical_ammo_remaining <= tactical_low_ammo_threshold:
		return ai_personality != EnemyPersonality.CAUTIOUS

	return _lost_target_advantage_score <= lost_target_disadvantage_threshold - 20.0


func _apply_lost_target_decision_velocity(threat_position: Vector2, delta: float) -> bool:
	if _lost_target_decision == LostTargetDecision.NONE:
		return false

	match _lost_target_decision:
		LostTargetDecision.FIGHTING_RETREAT:
			_apply_fighting_retreat_velocity(threat_position, delta)
			return true
		LostTargetDecision.PANIC_FLEE:
			_apply_panic_flee_velocity(threat_position)
			return true
		LostTargetDecision.REGROUP:
			if _apply_regroup_velocity(threat_position, delta):
				return true
			_apply_fighting_retreat_velocity(threat_position, delta)
			return true

	return false


func _apply_fighting_retreat_velocity(threat_position: Vector2, delta: float) -> void:
	var away_from_threat := global_position - threat_position
	if away_from_threat.length_squared() <= 0.01:
		away_from_threat = -_facing_direction
	if away_from_threat.length_squared() <= 0.01:
		away_from_threat = Vector2.RIGHT

	var retreat_direction := away_from_threat.normalized()
	var retreat_position := global_position + retreat_direction * lost_target_retreat_distance
	var move_direction := _get_navigation_direction_to(retreat_position, retreat_direction)
	velocity += move_direction * move_speed * fighting_retreat_speed_multiplier

	var to_threat := threat_position - global_position
	if to_threat.length_squared() > 0.01:
		_turn_aim_toward(to_threat.normalized(), delta)


func _apply_panic_flee_velocity(threat_position: Vector2) -> void:
	var away_from_threat := global_position - threat_position
	if away_from_threat.length_squared() <= 0.01:
		away_from_threat = -_facing_direction
	if away_from_threat.length_squared() <= 0.01:
		away_from_threat = Vector2.RIGHT

	var flee_direction := away_from_threat.normalized()
	var flee_position := global_position + flee_direction * lost_target_retreat_distance
	velocity += _get_navigation_direction_to(flee_position, flee_direction) * move_speed * panic_flee_speed_multiplier
	_set_aim_direction(flee_direction)


func _apply_regroup_velocity(threat_position: Vector2, delta: float) -> bool:
	var regroup_position := _get_regroup_position()
	if regroup_position == Vector2.INF:
		return false

	var to_regroup := regroup_position - global_position
	if to_regroup.length_squared() > 18.0 * 18.0:
		var fallback_direction := to_regroup.normalized()
		velocity += _get_navigation_direction_to(regroup_position, fallback_direction) * move_speed * cautious_search_speed_multiplier

	var to_threat := threat_position - global_position
	if to_threat.length_squared() > 0.01:
		_turn_aim_toward(to_threat.normalized(), delta)
	return true


func _get_regroup_position() -> Vector2:
	var best_position := Vector2.INF
	var best_score := -INF
	for enemy in get_tree().get_nodes_in_group(TOP_DOWN_ENEMY_GROUP):
		if enemy == self or enemy == null or not is_instance_valid(enemy):
			continue
		if not enemy is Node2D:
			continue

		var enemy_2d := enemy as Node2D
		var distance := global_position.distance_to(enemy_2d.global_position)
		if distance > lost_target_regroup_range:
			continue

		var score := -distance
		if enemy.has_method("has_active_player_sighting") and bool(enemy.call("has_active_player_sighting")):
			score += 80.0
		if enemy.has_method("get_unit_importance"):
			score += float(enemy.call("get_unit_importance")) * 6.0
		if score > best_score:
			best_score = score
			best_position = enemy_2d.global_position

	return best_position


func _get_lost_target_search_speed_multiplier() -> float:
	match _lost_target_decision:
		LostTargetDecision.AGGRESSIVE_SEARCH:
			return aggressive_search_speed_multiplier
		LostTargetDecision.CAUTIOUS_SEARCH:
			return cautious_search_speed_multiplier

	return 1.0


func _get_lost_target_probe_radius_multiplier() -> float:
	match _lost_target_decision:
		LostTargetDecision.AGGRESSIVE_SEARCH:
			return 1.35
		LostTargetDecision.CAUTIOUS_SEARCH:
			return 0.82

	return 1.0


func _apply_fallback_velocity() -> void:
	var threat_position := _get_threat_position()
	var away_from_threat := global_position - threat_position
	if away_from_threat.length_squared() <= 0.01:
		away_from_threat = -_facing_direction
	if away_from_threat.length_squared() <= 0.01:
		away_from_threat = Vector2.RIGHT

	var fallback_direction := away_from_threat.normalized()
	var fallback_position := global_position + fallback_direction * morale_fallback_distance
	var move_direction := _get_navigation_direction_to(fallback_position, fallback_direction)
	velocity += move_direction * move_speed * morale_fallback_speed_multiplier
	_set_aim_direction(threat_position - global_position)
	_current_group_role = GroupTacticRole.FALLBACK


func _get_threat_position() -> Vector2:
	if _target != null and is_instance_valid(_target):
		return _target.global_position
	if _has_last_seen_target:
		return _last_seen_target_position

	return global_position - _facing_direction


func _get_group_tactic_role() -> int:
	if not group_tactics_enabled or not _has_last_seen_target:
		return GroupTacticRole.NONE

	var members := _get_active_group_members()
	if members.size() <= 1:
		return GroupTacticRole.NONE

	var direct_candidate := _get_best_role_candidate(members, GroupTacticRole.DIRECT)
	if direct_candidate == self:
		return GroupTacticRole.DIRECT

	if (
		_get_self_role_score(GroupTacticRole.GUARD) >= 60.0
		and _get_guard_target(members) != null
		and _get_best_role_candidate_excluding(members, GroupTacticRole.GUARD, direct_candidate) == self
	):
		return GroupTacticRole.GUARD

	if (
		_get_self_role_score(GroupTacticRole.SUPPRESS) >= 62.0
		and _get_best_role_candidate_excluding(members, GroupTacticRole.SUPPRESS, direct_candidate) == self
	):
		return GroupTacticRole.SUPPRESS

	var flank_rank := _get_group_rank(members)
	if flank_rank % 3 == 0:
		return GroupTacticRole.LEFT_FLANK
	if flank_rank % 3 == 1:
		return GroupTacticRole.RIGHT_FLANK

	return GroupTacticRole.REAR_PRESSURE


func _get_active_group_members() -> Array:
	var members := []
	for enemy in get_tree().get_nodes_in_group(TOP_DOWN_ENEMY_GROUP):
		if enemy == null or not is_instance_valid(enemy):
			continue
		if not enemy is Node2D:
			continue

		var enemy_2d := enemy as Node2D
		if global_position.distance_squared_to(enemy_2d.global_position) > group_tactic_range * group_tactic_range:
			continue
		if not enemy.has_method("has_active_player_sighting"):
			continue
		if not bool(enemy.call("has_active_player_sighting")):
			continue

		members.append(enemy)

	return members


func _get_best_role_candidate(members: Array, role: int) -> Node:
	return _get_best_role_candidate_excluding(members, role, null)


func _get_best_role_candidate_excluding(members: Array, role: int, excluded_enemy: Node) -> Node:
	var best_enemy: Node = null
	var best_score := -INF
	for enemy in members:
		if enemy == excluded_enemy:
			continue
		var score := _get_role_score_for_enemy(enemy, role)
		if best_enemy == null or score > best_score:
			best_enemy = enemy
			best_score = score
			continue
		if is_equal_approx(score, best_score) and enemy.get_instance_id() < best_enemy.get_instance_id():
			best_enemy = enemy

	return best_enemy


func _get_role_score_for_enemy(enemy: Node, role: int) -> float:
	if enemy == self:
		return _get_self_role_score(role)
	if enemy.has_method("get_group_role_score"):
		return float(enemy.call("get_group_role_score", role))

	return 25.0


func _get_group_rank(members: Array) -> int:
	var rank := 0
	var self_id := get_instance_id()
	for enemy in members:
		if enemy != self and enemy.get_instance_id() < self_id:
			rank += 1

	return rank


func get_group_role_score(role: int) -> float:
	return _get_self_role_score(role)


func get_unit_importance() -> int:
	return unit_importance


func get_ai_archetype() -> int:
	return ai_archetype


func get_morale_score() -> float:
	return _get_morale_score()


func _is_morale_broken() -> bool:
	if not morale_enabled:
		_is_fallback_active = false
		return false

	var morale_score := _get_morale_score()
	var threshold := morale_break_threshold + morale_recover_margin if _is_fallback_active else morale_break_threshold
	_is_fallback_active = morale_score <= threshold
	return _is_fallback_active


func _get_morale_score() -> float:
	if not morale_enabled:
		return 100.0

	var morale_score := base_morale
	var health_ratio := _get_health_ratio()
	morale_score -= (1.0 - health_ratio) * morale_low_health_penalty
	morale_score -= self_preservation * 10.0

	var allies := maxi(_get_active_group_members().size() - 1, 0)
	if allies <= 0:
		morale_score -= morale_alone_penalty
	else:
		morale_score += minf(float(allies), 3.0) * morale_ally_bonus

	match ai_personality:
		EnemyPersonality.BRAVE:
			morale_score += 18.0
		EnemyPersonality.CAUTIOUS:
			morale_score -= 6.0
		EnemyPersonality.COWARDLY:
			morale_score -= 22.0
		EnemyPersonality.PROTECTIVE:
			if allies > 0:
				morale_score += 8.0
		EnemyPersonality.SELFISH:
			if allies <= 0:
				morale_score += 4.0
			else:
				morale_score -= 4.0

	return clampf(morale_score, 0.0, 100.0)


func _get_self_role_score(role: int) -> float:
	var score := 0.0
	match role:
		GroupTacticRole.DIRECT:
			score = 24.0
			match ai_archetype:
				EnemyArchetype.HEAVY_ASSAULT:
					score += 70.0
				EnemyArchetype.LIGHT_MELEE:
					score += 50.0
				EnemyArchetype.BEAST:
					score += 54.0
				EnemyArchetype.LIGHT_FIREARM:
					score += 26.0
				EnemyArchetype.SUPPORT:
					score += 8.0
			score += _get_personality_pressure_modifier()
			score += _get_health_ratio() * 10.0
			score -= self_preservation * 12.0
		GroupTacticRole.LEFT_FLANK, GroupTacticRole.RIGHT_FLANK:
			score = 26.0
			match ai_archetype:
				EnemyArchetype.LIGHT_FIREARM:
					score += 50.0
				EnemyArchetype.LIGHT_MELEE:
					score += 40.0
				EnemyArchetype.BEAST:
					score += 28.0
				EnemyArchetype.HEAVY_ASSAULT:
					score += 16.0
				EnemyArchetype.SUPPORT:
					score += 16.0
			if ai_personality == EnemyPersonality.CAUTIOUS:
				score += 12.0
			if ai_personality == EnemyPersonality.COWARDLY:
				score -= 6.0
		GroupTacticRole.REAR_PRESSURE:
			score = 22.0
			if ai_archetype == EnemyArchetype.LIGHT_FIREARM:
				score += 48.0
			elif ai_archetype == EnemyArchetype.LIGHT_MELEE:
				score += 28.0
			if ai_personality == EnemyPersonality.CAUTIOUS:
				score += 10.0
			score += self_preservation * 10.0
		GroupTacticRole.SUPPRESS:
			score = 8.0
			if ai_archetype == EnemyArchetype.LIGHT_FIREARM:
				score += 68.0
			elif ai_archetype == EnemyArchetype.HEAVY_ASSAULT:
				score += 46.0
			if ai_personality == EnemyPersonality.CAUTIOUS:
				score += 10.0
			if ai_personality == EnemyPersonality.BRAVE:
				score -= 6.0
			score += self_preservation * 8.0
		GroupTacticRole.GUARD:
			score = 12.0
			if ai_archetype == EnemyArchetype.HEAVY_ASSAULT:
				score += 58.0
			elif ai_archetype == EnemyArchetype.LIGHT_MELEE:
				score += 34.0
			elif ai_archetype == EnemyArchetype.LIGHT_FIREARM:
				score += 24.0
			if ai_personality == EnemyPersonality.PROTECTIVE:
				score += 28.0
			if ai_personality == EnemyPersonality.SELFISH:
				score -= 35.0
			score += ally_priority * 24.0

	return score


func _get_personality_pressure_modifier() -> float:
	match ai_personality:
		EnemyPersonality.BRAVE:
			return 18.0
		EnemyPersonality.CAUTIOUS:
			return -8.0
		EnemyPersonality.COWARDLY:
			return -24.0
		EnemyPersonality.PROTECTIVE:
			return 6.0
		EnemyPersonality.SELFISH:
			return 8.0

	return 0.0


func _get_health_ratio() -> float:
	if health == null:
		return 1.0
	var max_health_value := int(health.get("max_health"))
	if max_health_value <= 0:
		return 1.0

	return clampf(float(health.get("current_health")) / float(max_health_value), 0.0, 1.0)


func _get_guard_position(threat_position: Vector2) -> Vector2:
	var members := _get_active_group_members()
	var guard_target := _get_guard_target(members)
	if guard_target == null or not guard_target is Node2D:
		return Vector2.INF

	var target_position := (guard_target as Node2D).global_position
	var to_threat := (threat_position - target_position).normalized()
	if to_threat.length_squared() <= 0.01:
		to_threat = (global_position - target_position).normalized()
	if to_threat.length_squared() <= 0.01:
		return Vector2.INF

	return target_position + to_threat * 52.0


func _get_guard_target(members: Array) -> Node:
	var best_target: Node = null
	var best_importance := unit_importance
	for enemy in members:
		if enemy == self or not enemy is Node2D:
			continue

		var importance := 0
		if enemy.has_method("get_unit_importance"):
			importance = int(enemy.call("get_unit_importance"))
		var archetype := EnemyArchetype.LIGHT_MELEE
		if enemy.has_method("get_ai_archetype"):
			archetype = int(enemy.call("get_ai_archetype"))
		if archetype == EnemyArchetype.SUPPORT:
			importance += 3
		if importance <= best_importance:
			continue

		best_importance = importance
		best_target = enemy

	return best_target


func _apply_enemy_separation_velocity() -> void:
	if enemy_separation_radius <= 0.0 or enemy_separation_strength <= 0.0:
		return

	var separation := Vector2.ZERO
	var separation_radius_squared := enemy_separation_radius * enemy_separation_radius
	var self_id := get_instance_id()
	for enemy in get_tree().get_nodes_in_group(TOP_DOWN_ENEMY_GROUP):
		if enemy == self or enemy == null or not is_instance_valid(enemy):
			continue
		if not enemy is Node2D:
			continue

		var enemy_2d := enemy as Node2D
		var away_from_enemy := global_position - enemy_2d.global_position
		var distance_squared := away_from_enemy.length_squared()
		if distance_squared > separation_radius_squared:
			continue
		if distance_squared <= 0.01:
			var angle_seed := float((self_id + enemy.get_instance_id()) % 360)
			away_from_enemy = Vector2.RIGHT.rotated(deg_to_rad(angle_seed))
			if self_id < enemy.get_instance_id():
				away_from_enemy = -away_from_enemy
			distance_squared = 1.0

		var distance := sqrt(distance_squared)
		var separation_weight := 1.0 - clampf(distance / enemy_separation_radius, 0.0, 1.0)
		separation += away_from_enemy.normalized() * separation_weight

	if separation.length_squared() <= 0.0001:
		return

	if separation.length() > 1.0:
		separation = separation.normalized()
	velocity += separation * enemy_separation_strength


func _apply_enemy_local_avoidance_velocity(delta: float) -> void:
	_is_avoiding_enemy = false
	_is_blocked_by_enemy = false
	_enemy_avoidance_side_timer = maxf(_enemy_avoidance_side_timer - delta, 0.0)
	if not enemy_local_avoidance_enabled:
		return
	if not _has_last_seen_target:
		return
	if velocity.length_squared() <= 16.0:
		return

	var move_direction := velocity.normalized()
	var blocker := _get_enemy_path_blocker(move_direction)
	if blocker.is_empty():
		if _enemy_avoidance_side_timer <= 0.0:
			_enemy_avoidance_side = 0.0
		return

	var side_direction := Vector2(-move_direction.y, move_direction.x)
	var lateral := float(blocker.get("lateral", 0.0))
	var forward := float(blocker.get("forward", enemy_avoidance_lookahead))
	var corridor_width := maxf(enemy_avoidance_width, enemy_separation_radius * 0.75)
	var side_sign := _choose_enemy_avoidance_side(move_direction, side_direction, lateral)
	var forward_weight := 1.0 - clampf(forward / maxf(enemy_avoidance_lookahead, 1.0), 0.0, 1.0)
	var center_weight := 1.0 - clampf(absf(lateral) / maxf(corridor_width, 1.0), 0.0, 1.0)
	var avoid_weight := clampf(maxf(forward_weight, center_weight), 0.25, 1.0)

	velocity += side_direction * side_sign * enemy_avoidance_strength * avoid_weight
	if center_weight > 0.45 and forward < enemy_avoidance_lookahead * 0.72:
		var forward_speed := velocity.dot(move_direction)
		if forward_speed > 0.0:
			velocity -= move_direction * forward_speed * enemy_avoidance_slowdown * center_weight
		_is_blocked_by_enemy = true

	_is_avoiding_enemy = true


func _get_enemy_path_blocker(move_direction: Vector2) -> Dictionary:
	var best_blocker := {}
	var best_score := -INF
	var side_direction := Vector2(-move_direction.y, move_direction.x)
	var corridor_width := maxf(enemy_avoidance_width, enemy_separation_radius * 0.75)
	for enemy in get_tree().get_nodes_in_group(TOP_DOWN_ENEMY_GROUP):
		if enemy == self or enemy == null or not is_instance_valid(enemy):
			continue
		if not enemy is Node2D:
			continue

		var enemy_2d := enemy as Node2D
		var to_enemy := enemy_2d.global_position - global_position
		var forward := to_enemy.dot(move_direction)
		if forward <= 0.0 or forward > enemy_avoidance_lookahead:
			continue

		var lateral := to_enemy.dot(side_direction)
		if absf(lateral) > corridor_width:
			continue

		var forward_score := 1.0 - clampf(forward / maxf(enemy_avoidance_lookahead, 1.0), 0.0, 1.0)
		var center_score := 1.0 - clampf(absf(lateral) / maxf(corridor_width, 1.0), 0.0, 1.0)
		var score := forward_score * 1.15 + center_score
		if score > best_score:
			best_score = score
			best_blocker = {
				"enemy": enemy,
				"forward": forward,
				"lateral": lateral,
			}

	return best_blocker


func _choose_enemy_avoidance_side(move_direction: Vector2, side_direction: Vector2, blocker_lateral: float) -> float:
	if _enemy_avoidance_side_timer > 0.0 and _enemy_avoidance_side != 0.0:
		return _enemy_avoidance_side

	var chosen_side := 0.0
	if absf(blocker_lateral) > 4.0:
		chosen_side = -signf(blocker_lateral)
	else:
		var positive_density := _get_enemy_side_density(move_direction, side_direction, 1.0)
		var negative_density := _get_enemy_side_density(move_direction, side_direction, -1.0)
		if is_equal_approx(positive_density, negative_density):
			chosen_side = 1.0 if get_instance_id() % 2 == 0 else -1.0
		else:
			chosen_side = 1.0 if positive_density < negative_density else -1.0

	_enemy_avoidance_side = chosen_side
	_enemy_avoidance_side_timer = enemy_avoidance_side_hold_time
	return chosen_side


func _get_enemy_side_density(move_direction: Vector2, side_direction: Vector2, side_sign: float) -> float:
	var density := 0.0
	var scan_width := maxf(enemy_avoidance_width * 2.0, enemy_separation_radius)
	for enemy in get_tree().get_nodes_in_group(TOP_DOWN_ENEMY_GROUP):
		if enemy == self or enemy == null or not is_instance_valid(enemy):
			continue
		if not enemy is Node2D:
			continue

		var enemy_2d := enemy as Node2D
		var to_enemy := enemy_2d.global_position - global_position
		var forward := to_enemy.dot(move_direction)
		if forward < -enemy_separation_radius or forward > enemy_avoidance_lookahead:
			continue

		var signed_lateral := to_enemy.dot(side_direction) * side_sign
		if signed_lateral <= 0.0 or signed_lateral > scan_width:
			continue

		density += 1.0 / maxf(12.0, signed_lateral + maxf(forward, 0.0) * 0.35)

	return density


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

	if tactical_ammo_capacity > 0:
		_tactical_ammo_remaining = maxi(_tactical_ammo_remaining - 1, 0)

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
	if _cover_action_state == CoverActionState.HIDE:
		return false
	return _is_target_visible()


func _update_target_awareness(delta: float) -> void:
	if _target == null or not is_instance_valid(_target):
		_clear_target_awareness()
		return

	if _can_see_target():
		_hide_last_seen_marker()
		if _awareness_state != AwarenessState.COMBAT:
			_detection_progress = minf(1.0, _detection_progress + delta / maxf(detection_time, 0.01))
			if _detection_progress < 1.0:
				return

		var confirmed_position := _target.global_position
		_update_visual_target_motion(confirmed_position, delta)
		_receive_target_stimulus(_get_predicted_pursuit_position(confirmed_position), 1.0, &"visual", true)
		_combat_peripheral_tracking_timer = combat_peripheral_tracking_time
		_direct_sighting_share_timer += delta
		if _direct_sighting_share_timer >= alert_share_delay and not _has_shared_current_sighting:
			_share_player_sighting(_last_seen_target_position)
		return

	_direct_sighting_share_timer = 0.0
	_has_shared_current_sighting = false
	if not _has_last_seen_target:
		_detection_progress = maxf(0.0, _detection_progress - delta / maxf(detection_decay_time, 0.01))
		return

	if _awareness_state == AwarenessState.COMBAT and _can_track_target_peripherally():
		_combat_peripheral_tracking_timer -= delta
		var tracked_position := _target.global_position
		_update_visual_target_motion(tracked_position, delta)
		_last_seen_target_position = _get_predicted_pursuit_position(tracked_position)
		_awareness_timer = maxf(_awareness_timer, post_combat_search_memory_time)
		_is_investigating_last_seen = false
		_hide_last_seen_marker()
		return

	if _awareness_state == AwarenessState.COMBAT and _cover_action_state == CoverActionState.HIDE:
		if _cover_action_timer > 0.0:
			_awareness_timer = maxf(_awareness_timer, search_memory_time)
			_hide_last_seen_marker()
			return

	if _awareness_state == AwarenessState.COMBAT:
		_enter_lost_target_search()

	_show_last_seen_marker_if_all_targets_lost(_last_seen_target_position)
	if _awareness_state == AwarenessState.SUSPICIOUS:
		_suspicious_timer -= delta
		_awareness_timer -= delta
		if _awareness_timer <= 0.0:
			_clear_target_awareness()
			return
		if _suspicious_timer <= 0.0:
			_awareness_state = AwarenessState.INVESTIGATE
		return

	if global_position.distance_squared_to(_last_seen_target_position) <= 24.0 * 24.0:
		_awareness_state = AwarenessState.SEARCH
		if not _is_investigating_last_seen:
			_is_investigating_last_seen = true
			_investigation_timer = _get_current_investigation_time()
			_start_clearing_scan()
		_update_clearing_scan(delta)
		_investigation_timer -= delta
		if _investigation_timer <= 0.0:
			if not _advance_search_probe():
				_clear_target_awareness()
		return

	_is_investigating_last_seen = false
	if _awareness_state != AwarenessState.SEARCH:
		_awareness_state = AwarenessState.INVESTIGATE
	_awareness_timer -= delta
	if _awareness_timer <= 0.0:
		_clear_target_awareness()


func _update_visual_tracking(delta: float) -> void:
	if _target == null or not is_instance_valid(_target):
		return
	if _shoot_state == ShootState.WINDUP:
		return
	if _detection_progress <= 0.01 and not _has_last_seen_target:
		return
	if global_position.distance_squared_to(_target.global_position) > detection_range * detection_range:
		return
	if not _has_line_of_sight_to_target():
		return

	var to_target := _target.global_position - _get_vision_origin()
	if to_target.length_squared() <= 0.01:
		return

	_turn_aim_toward(to_target.normalized(), delta)


func _turn_aim_toward(direction: Vector2, delta: float) -> void:
	if direction.length_squared() <= 0.01:
		return

	var current_direction := _facing_direction.normalized()
	if current_direction.length_squared() <= 0.01:
		current_direction = direction.normalized()
	var desired_direction := direction.normalized()
	var angle_delta := current_direction.angle_to(desired_direction)
	var max_turn := deg_to_rad(visual_tracking_turn_speed_degrees) * delta
	if absf(angle_delta) <= max_turn:
		_set_aim_direction(desired_direction)
	else:
		_set_aim_direction(current_direction.rotated(signf(angle_delta) * max_turn))


func _can_track_target_peripherally() -> bool:
	if _target == null or not is_instance_valid(_target):
		return false
	if _combat_peripheral_tracking_timer <= 0.0:
		return false
	if global_position.distance_squared_to(_target.global_position) > detection_range * detection_range:
		return false

	return _has_line_of_sight_to_target()


func _update_visual_target_motion(target_position: Vector2, delta: float) -> void:
	if _has_visual_target_sample and delta > 0.001:
		var sample_velocity := (target_position - _last_visual_target_position) / delta
		_estimated_target_velocity = _estimated_target_velocity.lerp(sample_velocity, 0.45)
	_last_visual_target_position = target_position
	_has_visual_target_sample = true


func _get_predicted_pursuit_position(target_position: Vector2) -> Vector2:
	if _estimated_target_velocity.length_squared() <= 1.0:
		return target_position

	var lead := _estimated_target_velocity * pursuit_prediction_time
	if lead.length() > max_pursuit_prediction_distance:
		lead = lead.normalized() * max_pursuit_prediction_distance

	return target_position + lead


func _get_corner_clearing_direction(move_direction: Vector2, target_direction: Vector2, delta: float) -> Vector2:
	var base_direction := (move_direction + target_direction * 0.35).normalized()
	if base_direction.length_squared() <= 0.01:
		base_direction = move_direction.normalized()
	if base_direction.length_squared() <= 0.01:
		base_direction = _facing_direction.normalized()

	_corner_clearing_phase += corner_clearing_sweep_speed * delta
	var sweep_angle := sin(_corner_clearing_phase) * deg_to_rad(corner_clearing_angle_degrees)
	return base_direction.rotated(sweep_angle).normalized()


func _start_clearing_scan() -> void:
	var base_direction := _estimated_target_velocity.normalized()
	if base_direction.length_squared() <= 0.01:
		base_direction = (_last_seen_target_position - global_position).normalized()
	if base_direction.length_squared() <= 0.01:
		base_direction = _facing_direction.normalized()
	if base_direction.length_squared() <= 0.01:
		base_direction = Vector2.RIGHT

	var side_angle := deg_to_rad(clearing_scan_angle_degrees)
	_clearing_scan_directions = [
		base_direction,
		base_direction.rotated(-side_angle),
		base_direction.rotated(side_angle),
		base_direction.rotated(-side_angle * 0.45),
		base_direction.rotated(side_angle * 0.45),
	]
	_clearing_scan_index = 0
	_clearing_scan_step_timer = clearing_scan_step_time


func _update_clearing_scan(delta: float) -> void:
	if _clearing_scan_directions.is_empty():
		_start_clearing_scan()

	_clearing_scan_step_timer -= delta
	if _clearing_scan_step_timer <= 0.0:
		_clearing_scan_index = (_clearing_scan_index + 1) % _clearing_scan_directions.size()
		_clearing_scan_step_timer = clearing_scan_step_time

	_turn_aim_toward(_clearing_scan_directions[_clearing_scan_index], delta)


func _get_current_investigation_time() -> float:
	if _is_search_probe_target:
		return search_probe_investigation_time
	if _is_post_combat_search:
		return post_combat_investigation_time

	return investigation_time


func _advance_search_probe() -> bool:
	if not _is_post_combat_search:
		return false
	if not _has_search_probe_plan:
		_build_search_probe_plan()
	if _search_probe_index >= _search_probe_points.size():
		return false

	_last_seen_target_position = _search_probe_points[_search_probe_index]
	_search_probe_index += 1
	_is_search_probe_target = true
	_is_investigating_last_seen = false
	_investigation_timer = 0.0
	_clearing_scan_directions.clear()
	_awareness_timer = maxf(_awareness_timer, search_probe_investigation_time + 0.4)
	return true


func _build_search_probe_plan() -> void:
	var origin := _last_seen_target_position
	var probe_radius := search_probe_radius * _get_lost_target_probe_radius_multiplier()
	var base_direction := _estimated_target_velocity.normalized()
	if base_direction.length_squared() <= 0.01:
		base_direction = (_last_seen_target_position - global_position).normalized()
	if base_direction.length_squared() <= 0.01:
		base_direction = _facing_direction.normalized()
	if base_direction.length_squared() <= 0.01:
		base_direction = Vector2.RIGHT

	var side_angle := deg_to_rad(65.0)
	var back_angle := deg_to_rad(140.0)
	_search_probe_points = [
		origin + base_direction * probe_radius,
		origin + base_direction.rotated(-side_angle) * probe_radius,
		origin + base_direction.rotated(side_angle) * probe_radius,
		origin + base_direction.rotated(-back_angle) * probe_radius * 0.7,
		origin + base_direction.rotated(back_angle) * probe_radius * 0.7,
	]
	_search_probe_index = 0
	_has_search_probe_plan = true


func _get_debug_state_text() -> String:
	var state_text := ""
	match _shoot_state:
		ShootState.TRACKING:
			state_text = "TRACK"
		ShootState.WINDUP:
			state_text = "LOCK"
		ShootState.RECOVERY:
			state_text = "RECOVER"

	if _cover_action_state == CoverActionState.HIDE:
		state_text = "HIDE"
	elif _cover_action_state == CoverActionState.PEEK and state_text == "":
		state_text = "PEEK"

	if state_text == "":
		if _is_blocked_by_enemy:
			state_text = "BLOCKED"
		elif _is_avoiding_enemy:
			state_text = "AVOID"
		elif _is_using_cover:
			state_text = "COVER"
		elif _is_target_visible():
			state_text = "READY"
		elif _can_see_target() and _awareness_state != AwarenessState.COMBAT:
			state_text = "DETECT"
		elif _awareness_state == AwarenessState.SUSPICIOUS:
			state_text = "SUSPECT"
		elif _lost_target_squad_role != LostTargetSquadRole.NONE and _has_last_seen_target:
			state_text = _get_lost_target_squad_role_code()
		elif _is_investigating_last_seen:
			state_text = "INVEST"
		elif _awareness_state == AwarenessState.INVESTIGATE:
			state_text = "INVEST"
		elif _lost_target_decision != LostTargetDecision.NONE and _has_last_seen_target:
			state_text = _get_lost_target_decision_code()
		elif _has_last_seen_target:
			state_text = "SEARCH"
		else:
			state_text = "IDLE"

	if _has_last_seen_target and _current_group_role != GroupTacticRole.NONE:
		return "%s/%s/%s/%s" % [
			state_text,
			_get_group_role_code(_current_group_role),
			_get_personality_code(),
			_get_morale_code(),
		]

	return "%s/%s/%s" % [state_text, _get_personality_code(), _get_morale_code()]


func _get_group_role_code(role: int) -> String:
	match role:
		GroupTacticRole.DIRECT:
			return "DIR"
		GroupTacticRole.LEFT_FLANK:
			return "L-FLK"
		GroupTacticRole.RIGHT_FLANK:
			return "R-FLK"
		GroupTacticRole.REAR_PRESSURE:
			return "REAR"
		GroupTacticRole.SUPPRESS:
			return "SUP"
		GroupTacticRole.GUARD:
			return "GRD"
		GroupTacticRole.FALLBACK:
			return "FBK"

	return "NONE"


func _get_personality_code() -> String:
	match ai_personality:
		EnemyPersonality.BRAVE:
			return "BRV"
		EnemyPersonality.CAUTIOUS:
			return "CAU"
		EnemyPersonality.COWARDLY:
			return "COW"
		EnemyPersonality.PROTECTIVE:
			return "PRT"
		EnemyPersonality.SELFISH:
			return "SLF"

	return "BAL"


func _get_morale_code() -> String:
	return "M%02d" % int(roundf(_get_morale_score()))


func _get_lost_target_decision_code() -> String:
	match _lost_target_decision:
		LostTargetDecision.AGGRESSIVE_SEARCH:
			return "PUSH"
		LostTargetDecision.CAUTIOUS_SEARCH:
			return "CAUT"
		LostTargetDecision.FIGHTING_RETREAT:
			return "RET"
		LostTargetDecision.PANIC_FLEE:
			return "FLEE"
		LostTargetDecision.REGROUP:
			return "GROUP"

	return "SEARCH"


func _get_lost_target_squad_role_code() -> String:
	match _lost_target_squad_role:
		LostTargetSquadRole.OVERWATCH:
			return "WATCH"
		LostTargetSquadRole.SWEEP_LEFT:
			return "SW-L"
		LostTargetSquadRole.SWEEP_RIGHT:
			return "SW-R"
		LostTargetSquadRole.PRESSURE:
			return "PRESS"

	return "SEARCH"


func _update_debug_label() -> void:
	if _debug_label == null:
		return

	_debug_label.visible = debug_state_visible
	_debug_label.text = _get_debug_state_text()


func receive_shared_player_sighting(sighting_position: Vector2, source: Node) -> void:
	if _is_dead or source == self:
		return

	_receive_target_stimulus(sighting_position, shared_sighting_confidence, &"shared", false)


func receive_noise_event(noise_position: Vector2, radius: float, source: Node, _noise_type: StringName = &"generic") -> void:
	if _is_dead or source == self:
		return

	var hearing_radius := maxf(radius * hearing_sensitivity, 0.0)
	if global_position.distance_squared_to(noise_position) > hearing_radius * hearing_radius:
		return

	var to_noise := noise_position - global_position
	if to_noise.length_squared() > 0.01:
		_set_aim_direction(to_noise.normalized())
	var confidence := hearing_confidence
	if _noise_type == &"gunshot":
		confidence = maxf(confidence, gunshot_hearing_confidence)
	_receive_target_stimulus(noise_position, confidence, &"noise", false)


func has_direct_target_sighting() -> bool:
	return not _is_dead and _awareness_state == AwarenessState.COMBAT and _can_see_target()


func has_active_player_sighting() -> bool:
	return not _is_dead and _has_last_seen_target


func is_in_combat_with_target() -> bool:
	if _is_dead:
		return false
	if _shoot_state == ShootState.TRACKING or _shoot_state == ShootState.WINDUP:
		return true
	return _awareness_state == AwarenessState.COMBAT and _can_see_target()


func _is_target_visible() -> bool:
	return _awareness_state == AwarenessState.COMBAT and _has_last_seen_target and _can_see_target()


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
	var confidence := 1.0 if is_direct_sighting else shared_sighting_confidence
	var stimulus_type: StringName = &"visual" if is_direct_sighting else &"shared"
	_receive_target_stimulus(target_position, confidence, stimulus_type, is_direct_sighting)


func _receive_target_stimulus(
	stimulus_position: Vector2,
	confidence: float,
	stimulus_type: StringName,
	is_direct_sighting: bool
) -> void:
	_has_last_seen_target = true
	_last_seen_target_position = stimulus_position
	_awareness_timer = search_memory_time
	_is_investigating_last_seen = false
	_investigation_timer = 0.0
	_stimulus_confidence = clampf(maxf(_stimulus_confidence, confidence), 0.0, 1.0)
	_last_stimulus_type = stimulus_type
	if is_direct_sighting:
		_awareness_state = AwarenessState.COMBAT
		_lost_target_decision = LostTargetDecision.NONE
		_lost_target_squad_role = LostTargetSquadRole.NONE
		_is_post_combat_search = false
		_suspicious_timer = 0.0
		_detection_progress = 1.0
		if debug_last_seen_marker_visible:
			_hide_last_seen_marker()
		return

	if stimulus_type == &"noise":
		if _awareness_state == AwarenessState.COMBAT and _can_see_target():
			_suspicious_timer = 0.0
		elif _awareness_state == AwarenessState.SUSPICIOUS:
			var pause_limit := suspicious_pause_time
			if confidence >= gunshot_hearing_confidence:
				pause_limit *= 0.25
			_suspicious_timer = minf(_suspicious_timer, pause_limit)
		elif _awareness_state == AwarenessState.INVESTIGATE or _awareness_state == AwarenessState.SEARCH:
			_suspicious_timer = 0.0
		elif confidence >= gunshot_hearing_confidence:
			_awareness_state = AwarenessState.INVESTIGATE
			_suspicious_timer = 0.0
		else:
			_awareness_state = AwarenessState.SUSPICIOUS
			_suspicious_timer = suspicious_pause_time
	else:
		_awareness_state = AwarenessState.INVESTIGATE
		_suspicious_timer = 0.0


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
	_receive_target_stimulus(source_position, hit_confidence, &"hit", false)


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
	_awareness_state = AwarenessState.IDLE
	_stimulus_confidence = 0.0
	_suspicious_timer = 0.0
	_last_stimulus_type = &"none"
	_has_visual_target_sample = false
	_estimated_target_velocity = Vector2.ZERO
	_combat_peripheral_tracking_timer = 0.0
	_is_post_combat_search = false
	_search_probe_points.clear()
	_search_probe_index = 0
	_has_search_probe_plan = false
	_is_search_probe_target = false
	_current_group_role = GroupTacticRole.NONE
	_is_fallback_active = false
	_lost_target_decision = LostTargetDecision.NONE
	_lost_target_squad_role = LostTargetSquadRole.NONE
	_lost_target_advantage_score = 0.0
	_tactical_ammo_remaining = tactical_ammo_capacity
	_clear_cover_target()
	_clearing_scan_directions.clear()
	_clearing_scan_index = 0
	_clearing_scan_step_timer = 0.0
	_corner_clearing_phase = 0.0
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
	if _awareness_state == AwarenessState.SUSPICIOUS:
		return Color(1.0, 0.82, 0.32, 0.08)
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
