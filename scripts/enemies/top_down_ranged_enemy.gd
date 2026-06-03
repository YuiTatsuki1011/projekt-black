extends TopDownEnemyBase
class_name TopDownRangedEnemy

enum ShootState {
	IDLE,
	TRACKING,
	WINDUP,
	RECOVERY,
}

@export var projectile_scene: PackedScene
@export var preferred_range: float = 300.0
@export var retreat_range: float = 150.0
@export var aim_tracking_time: float = 0.45
@export var shot_windup_time: float = 0.5
@export var shot_recovery_time: float = 1.1
@export var initial_shot_delay: float = 0.35
@export var projectile_damage: int = 14
@export var projectile_speed: float = 540.0
@export var telegraph_length: float = 760.0

@onready var gun_root: Node2D = get_node_or_null("GunRoot") as Node2D
@onready var muzzle: Marker2D = get_node_or_null("GunRoot/Muzzle") as Marker2D
@onready var telegraph_line: Line2D = get_node_or_null("TelegraphLine") as Line2D

var _shoot_state: ShootState = ShootState.RECOVERY
var _shot_timer: float = 0.0
var _locked_direction: Vector2 = Vector2.LEFT


func _enemy_ready() -> void:
	_shoot_state = ShootState.RECOVERY
	_shot_timer = initial_shot_delay
	_set_telegraph_visible(false)


func _enemy_physics_update(delta: float) -> void:
	_update_gun_visual()
	_update_shoot_state(delta)
	if not has_known_target():
		return

	var target_position := get_target_or_memory_position()
	var target_distance := global_position.distance_to(target_position)
	if is_target_confirmed_visible():
		var to_target := (_target.global_position - global_position).normalized()
		_turn_aim_toward(to_target, delta)
		if target_distance < retreat_range:
			add_desired_velocity(-to_target * move_speed * 0.72)
		elif target_distance > preferred_range:
			move_toward_position(_target.global_position, move_speed, preferred_range)
	elif not is_searching_at_memory():
		move_toward_position(target_position, move_speed * 0.86, search_arrival_distance)


func _update_shoot_state(delta: float) -> void:
	match _shoot_state:
		ShootState.IDLE:
			if _can_start_shot():
				_enter_tracking()
		ShootState.TRACKING:
			_shot_timer -= delta
			if not _can_shoot_target():
				_enter_idle()
				return
			_update_locked_direction_to_target()
			if _shot_timer <= 0.0:
				_enter_windup()
		ShootState.WINDUP:
			_shot_timer -= delta
			_update_telegraph()
			if _shot_timer <= 0.0:
				_fire_projectile()
				_enter_recovery()
		ShootState.RECOVERY:
			_shot_timer -= delta
			if _shot_timer <= 0.0:
				_enter_idle()


func _can_start_shot() -> bool:
	return is_target_confirmed_visible() and global_position.distance_to(_target.global_position) <= detection_range


func _can_shoot_target() -> bool:
	if not is_target_confirmed_visible():
		return false
	return _has_clear_muzzle_line(_target.global_position)


func _enter_idle() -> void:
	_shoot_state = ShootState.IDLE
	_shot_timer = 0.0
	_set_telegraph_visible(false)


func _enter_tracking() -> void:
	_shoot_state = ShootState.TRACKING
	_shot_timer = aim_tracking_time
	_update_locked_direction_to_target()
	_set_telegraph_visible(false)


func _enter_windup() -> void:
	_shoot_state = ShootState.WINDUP
	_shot_timer = shot_windup_time
	_update_locked_direction_to_target()
	_set_telegraph_visible(true)
	_update_telegraph()


func _enter_recovery() -> void:
	_shoot_state = ShootState.RECOVERY
	_shot_timer = shot_recovery_time
	_set_telegraph_visible(false)


func _update_locked_direction_to_target() -> void:
	if _target == null or not is_instance_valid(_target):
		return
	var origin := muzzle.global_position if muzzle != null else global_position
	var to_target := _target.global_position - origin
	if to_target.length_squared() <= 0.01:
		return
	_locked_direction = to_target.normalized()
	_turn_aim_toward(_locked_direction, get_physics_process_delta_time())


func _turn_aim_toward(direction: Vector2, delta: float) -> void:
	turn_toward_position(global_position + direction, delta)
	_update_gun_visual()


func _update_gun_visual() -> void:
	if gun_root == null:
		return
	gun_root.rotation = get_facing_direction().angle()


func _set_telegraph_visible(is_visible: bool) -> void:
	if telegraph_line != null:
		telegraph_line.visible = is_visible


func _update_telegraph() -> void:
	if telegraph_line == null or muzzle == null:
		return
	var end_position := _get_telegraph_end_position()
	telegraph_line.points = PackedVector2Array([
		telegraph_line.to_local(muzzle.global_position),
		telegraph_line.to_local(end_position),
	])
	var blink := 0.48 + sin(Time.get_ticks_msec() * 0.034) * 0.22
	telegraph_line.default_color = Color(1.0, 0.08, 0.04, blink)


func _get_telegraph_end_position() -> Vector2:
	var start_position := muzzle.global_position if muzzle != null else global_position
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


func _has_clear_muzzle_line(target_position: Vector2) -> bool:
	var origin := muzzle.global_position if muzzle != null else global_position
	var space_state := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.new()
	query.from = origin
	query.to = target_position
	query.collision_mask = line_of_sight_blocker_mask
	query.exclude = [get_rid()]
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return space_state.intersect_ray(query).is_empty()


func _fire_projectile() -> void:
	if projectile_scene == null:
		return

	var projectile := projectile_scene.instantiate()
	var projectile_parent := get_tree().current_scene
	if projectile_parent == null:
		projectile_parent = get_parent()
	projectile_parent.add_child(projectile)

	if projectile is Node2D:
		var projectile_2d := projectile as Node2D
		projectile_2d.global_position = muzzle.global_position if muzzle != null else global_position
		projectile_2d.global_rotation = _locked_direction.angle()

	projectile.set("damage", projectile_damage)
	projectile.set("speed", projectile_speed)
	if projectile.has_method("launch"):
		projectile.call("launch", _locked_direction)
	else:
		projectile.set("global_rotation", _locked_direction.angle())


func _enemy_died() -> void:
	_set_telegraph_visible(false)
