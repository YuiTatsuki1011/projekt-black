extends CharacterBody2D
class_name TopDownRangedEnemy

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


func _ready() -> void:
	_base_body_color = body_visual.color
	_base_eye_color = eye_visual.color
	_resolve_target()
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
	_knockback_velocity = _knockback_velocity.move_toward(Vector2.ZERO, knockback_recovery * delta)
	move_and_slide()


func apply_hit_reaction(direction: Vector2, _damage: int, hit_position: Vector2) -> void:
	var knockback_direction := direction.normalized()
	if knockback_direction == Vector2.ZERO:
		knockback_direction = Vector2.RIGHT

	_knockback_velocity = knockback_direction * knockback_strength
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
		velocity += target_direction * move_speed
	elif not visible_target and target_distance > 24.0:
		velocity += target_direction * move_speed


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
		_has_last_seen_target = false
		_awareness_timer = 0.0
		return

	if _is_target_visible():
		_has_last_seen_target = true
		_last_seen_target_position = _target.global_position
		_awareness_timer = search_memory_time
		return

	if not _has_last_seen_target:
		return

	_awareness_timer -= delta
	if _awareness_timer <= 0.0 or global_position.distance_squared_to(_last_seen_target_position) <= 24.0 * 24.0:
		_has_last_seen_target = false


func _is_target_visible() -> bool:
	if _target == null or not is_instance_valid(_target):
		return false
	if global_position.distance_squared_to(_target.global_position) > detection_range * detection_range:
		return false

	return _has_line_of_sight_to_target()


func _get_aim_position() -> Vector2:
	if _target != null and is_instance_valid(_target) and _is_target_visible():
		return _target.global_position
	if _has_last_seen_target:
		return _last_seen_target_position

	return Vector2.INF


func _has_line_of_sight_to_target() -> bool:
	if _target == null or not is_instance_valid(_target):
		return false

	var space_state := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.new()
	query.from = muzzle.global_position
	query.to = _target.global_position
	query.collision_mask = line_of_sight_blocker_mask
	query.exclude = [get_rid()]
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return space_state.intersect_ray(query).is_empty()


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
