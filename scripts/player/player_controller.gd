extends CharacterBody2D
class_name PlayerController

signal ammo_changed(current_ammo: int, reserve_ammo: int)
signal fired(ammo_remaining: int)
signal reload_started(duration: float)
signal interact_requested
signal died

const ENEMY_COLLISION_MASK: int = 8

@export var walk_speed: float = 160.0
@export var crouch_speed_multiplier: float = 0.45
@export var jump_velocity: float = -360.0
@export var bullet_damage: int = 10
@export var magazine_size: int = 6
@export var starting_reserve_ammo: int = 24
@export var reload_time: float = 1.2
@export var fire_cooldown: float = 0.22
@export var recoil_amount: float = 0.18
@export var recoil_recovery_speed: float = 8.0
@export var aim_flip_dead_zone: float = 12.0
@export var damage_flash_time: float = 0.12
@export var projectile_scene: PackedScene

@onready var body_root: Node2D = $VisualRoot/BodyRoot
@onready var arm_rig: Node2D = $ArmRig
@onready var upper_arm_bone: Bone2D = $ArmRig/Skeleton2D/UpperArmBone
@onready var forearm_bone: Bone2D = $ArmRig/Skeleton2D/UpperArmBone/ForearmBone
@onready var hand_bone: Bone2D = $ArmRig/Skeleton2D/UpperArmBone/ForearmBone/HandBone
@onready var muzzle: Marker2D = $ArmRig/Skeleton2D/UpperArmBone/ForearmBone/HandBone/GunRoot/Muzzle
@onready var standing_collision: CollisionShape2D = $StandingCollision
@onready var crouching_collision: CollisionShape2D = $CrouchingCollision
@onready var interaction_area: Area2D = $InteractionArea
@onready var health: Node = $Health

var current_ammo: int = 0
var reserve_ammo: int = 0

var _gravity: float = 980.0
var _fire_cooldown_remaining: float = 0.0
var _reload_remaining: float = 0.0
var _is_reloading: bool = false
var _is_crouching: bool = false
var _is_dead: bool = false
var _facing: int = 1
var _recoil: float = 0.0
var _nearby_interactables: Array[Node2D] = []
var _damage_flash_tween: Tween


func _ready() -> void:
	if ProjectSettings.has_setting("physics/2d/default_gravity"):
		_gravity = float(ProjectSettings.get_setting("physics/2d/default_gravity"))
	current_ammo = magazine_size
	reserve_ammo = starting_reserve_ammo
	_configure_aim_bones()
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)
	interaction_area.area_entered.connect(_on_interaction_area_entered)
	interaction_area.area_exited.connect(_on_interaction_area_exited)
	_set_crouching(false)
	_update_arm_anchor()
	ammo_changed.emit(current_ammo, reserve_ammo)


func _physics_process(delta: float) -> void:
	if _is_dead:
		return

	_update_timers(delta)
	_handle_movement(delta)
	move_and_slide()
	_update_aim(delta)
	_handle_actions()


func _update_timers(delta: float) -> void:
	_fire_cooldown_remaining -= delta
	if _fire_cooldown_remaining < 0.0:
		_fire_cooldown_remaining = 0.0

	if _is_reloading:
		_reload_remaining -= delta
		if _reload_remaining <= 0.0:
			_finish_reload()


func _handle_movement(delta: float) -> void:
	var input_axis: float = Input.get_axis("move_left", "move_right")
	var wants_crouch: bool = Input.is_action_pressed("crouch") and is_on_floor()
	_set_crouching(wants_crouch)

	var active_speed: float = walk_speed
	if _is_crouching:
		active_speed *= crouch_speed_multiplier

	velocity.x = input_axis * active_speed

	if not is_on_floor():
		velocity.y += _gravity * delta
	elif velocity.y > 0.0:
		velocity.y = 0.0

	if Input.is_action_just_pressed("jump") and is_on_floor() and not _is_crouching:
		velocity.y = jump_velocity


func _handle_actions() -> void:
	if Input.is_action_just_pressed("interact"):
		_interact_with_nearest()
		interact_requested.emit()

	if Input.is_action_just_pressed("reload"):
		_start_reload()

	if Input.is_action_pressed("fire"):
		_try_fire()


func _update_aim(delta: float) -> void:
	var mouse_position: Vector2 = get_global_mouse_position()
	var next_facing: int = _facing
	var aim_offset_x: float = mouse_position.x - global_position.x
	if aim_offset_x > aim_flip_dead_zone:
		next_facing = 1
	elif aim_offset_x < -aim_flip_dead_zone:
		next_facing = -1

	if next_facing != _facing:
		_facing = next_facing
		body_root.scale.x = float(_facing)
		_update_arm_anchor()

	var aim_vector: Vector2 = mouse_position - arm_rig.global_position
	if aim_vector.length_squared() <= 0.01:
		return

	arm_rig.global_rotation = aim_vector.angle()
	arm_rig.scale.y = -1.0 if _facing < 0 else 1.0

	_recoil = move_toward(_recoil, 0.0, recoil_recovery_speed * delta)
	forearm_bone.rotation = -_recoil * arm_rig.scale.y


func _try_fire() -> void:
	if _is_reloading or _fire_cooldown_remaining > 0.0:
		return

	if current_ammo <= 0:
		_start_reload()
		return

	if projectile_scene == null:
		return

	if _try_apply_close_barrel_hit():
		_consume_round()
		return

	var projectile: Node = projectile_scene.instantiate()
	projectile.set("damage", bullet_damage)
	var projectile_parent: Node = get_tree().current_scene
	if projectile_parent == null:
		projectile_parent = get_parent()
	projectile_parent.add_child(projectile)

	if projectile is Node2D:
		var projectile_2d := projectile as Node2D
		var shot_direction: Vector2 = muzzle.global_transform.x.normalized()
		if shot_direction == Vector2.ZERO:
			shot_direction = Vector2.RIGHT.rotated(arm_rig.global_rotation)

		projectile_2d.global_position = muzzle.global_position
		projectile_2d.global_rotation = shot_direction.angle()
		if projectile_2d.has_method("launch"):
			projectile_2d.call("launch", shot_direction)

	_consume_round()


func _start_reload() -> void:
	if _is_reloading or current_ammo >= magazine_size or reserve_ammo <= 0:
		return

	_is_reloading = true
	_reload_remaining = reload_time
	reload_started.emit(reload_time)


func _finish_reload() -> void:
	var ammo_needed: int = magazine_size - current_ammo
	var ammo_to_load: int = ammo_needed
	if reserve_ammo < ammo_to_load:
		ammo_to_load = reserve_ammo
	current_ammo += ammo_to_load
	reserve_ammo -= ammo_to_load
	_is_reloading = false
	_reload_remaining = 0.0
	ammo_changed.emit(current_ammo, reserve_ammo)


func _set_crouching(enabled: bool) -> void:
	if _is_crouching == enabled:
		return

	_is_crouching = enabled
	standing_collision.disabled = enabled
	crouching_collision.disabled = not enabled
	body_root.scale.y = 0.65 if enabled else 1.0
	body_root.position.y = 8.0 if enabled else 0.0
	_update_arm_anchor()


func _update_arm_anchor() -> void:
	var shoulder_height: float = -24.0
	if _is_crouching:
		shoulder_height = -16.0
	arm_rig.position = Vector2(1.0 * float(_facing), shoulder_height)


func _configure_aim_bones() -> void:
	upper_arm_bone.set_autocalculate_length_and_angle(false)
	upper_arm_bone.set_length(8.0)
	upper_arm_bone.set_bone_angle(0.0)

	forearm_bone.set_autocalculate_length_and_angle(false)
	forearm_bone.set_length(6.0)
	forearm_bone.set_bone_angle(0.0)

	hand_bone.set_autocalculate_length_and_angle(false)
	hand_bone.set_length(18.0)
	hand_bone.set_bone_angle(0.0)


func _consume_round() -> void:
	current_ammo -= 1
	_fire_cooldown_remaining = fire_cooldown
	_recoil = recoil_amount
	fired.emit(current_ammo)
	ammo_changed.emit(current_ammo, reserve_ammo)


func _try_apply_close_barrel_hit() -> bool:
	var space_state: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(
		arm_rig.global_position,
		muzzle.global_position,
		ENEMY_COLLISION_MASK
	)
	query.exclude = [get_rid()]
	query.collide_with_bodies = true
	query.collide_with_areas = false

	var result: Dictionary = space_state.intersect_ray(query)
	if result.is_empty():
		return false

	var collider := result.get("collider") as Node
	if collider == null:
		return false

	var health_node := collider.get_node_or_null("Health")
	if health_node == null:
		return false

	if collider.has_method("apply_hit_reaction"):
		var shot_direction := muzzle.global_transform.x.normalized()
		collider.call("apply_hit_reaction", shot_direction, bullet_damage, result.get("position", muzzle.global_position))
	health_node.apply_damage(bullet_damage)
	return true


func _interact_with_nearest() -> void:
	var nearest: Node2D = null
	var nearest_distance_squared: float = INF

	for interactable in _nearby_interactables:
		if not is_instance_valid(interactable):
			continue

		var distance_squared: float = global_position.distance_squared_to(interactable.global_position)
		if distance_squared < nearest_distance_squared:
			nearest = interactable
			nearest_distance_squared = distance_squared

	if nearest != null and nearest.has_method("interact"):
		nearest.call("interact", self)


func _on_interaction_area_entered(area: Area2D) -> void:
	if area.has_method("interact") and area not in _nearby_interactables:
		_nearby_interactables.append(area)


func _on_interaction_area_exited(area: Area2D) -> void:
	_nearby_interactables.erase(area)


func _on_died() -> void:
	_is_dead = true
	velocity = Vector2.ZERO
	body_root.modulate = Color(0.35, 0.35, 0.35, 1.0)
	arm_rig.visible = false
	died.emit()


func _on_damaged(_amount: int, _current_health: int, _max_health: int) -> void:
	if _is_dead:
		return

	if _damage_flash_tween != null:
		_damage_flash_tween.kill()

	body_root.modulate = Color(1.0, 0.45, 0.42, 1.0)
	arm_rig.modulate = Color(1.0, 0.45, 0.42, 1.0)
	_damage_flash_tween = create_tween()
	_damage_flash_tween.tween_property(body_root, "modulate", Color.WHITE, damage_flash_time)
	_damage_flash_tween.parallel().tween_property(arm_rig, "modulate", Color.WHITE, damage_flash_time)
