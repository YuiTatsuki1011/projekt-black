extends CharacterBody2D
class_name PlayerController

signal ammo_changed(current_ammo: int, reserve_ammo: int)
signal fired(ammo_remaining: int)
signal reload_started(duration: float)
signal interact_requested
signal died
signal stamina_changed(current_stamina: float, max_stamina: float, overheated: bool, melee_available: bool)
signal stamina_use_failed

const ENEMY_COLLISION_MASK: int = 8

enum MeleeState {
	READY,
	LUNGE,
	STRIKE,
	RECOVERY,
}

@export var walk_speed: float = 160.0
@export var crouch_speed_multiplier: float = 0.45
@export var jump_velocity: float = -360.0
@export var bullet_damage: int = 10
@export var magazine_size: int = 6
@export var starting_reserve_ammo: int = 24
@export var ammo_item_id: StringName = &"pistol_ammo"
@export var reload_time: float = 1.2
@export var fire_cooldown: float = 0.22
@export var recoil_amount: float = 0.18
@export var recoil_recovery_speed: float = 8.0
@export var aim_flip_dead_zone: float = 12.0
@export var damage_flash_time: float = 0.12
@export var damage_knockback_strength: float = 130.0
@export var damage_knockback_lift: float = -55.0
@export var damage_knockback_recovery: float = 520.0
@export var max_stamina: float = 90.0
@export var melee_stamina_cost: float = 30.0
@export var melee_min_stamina_to_use: float = 15.0
@export var stamina_recovery_rate: float = 42.0
@export var overheat_recovery_rate: float = 32.0
@export var stamina_recovery_delay: float = 0.55
@export var stamina_empty_hold_time: float = 2.0
@export var melee_lunge_speed: float = 250.0
@export var melee_lunge_time: float = 0.13
@export var melee_strike_time: float = 0.11
@export var melee_recovery_time: float = 0.2
@export var melee_combo_reset_time: float = 0.75
@export var dodge_speed: float = 330.0
@export var dodge_duration: float = 0.13
@export var dodge_cooldown: float = 0.55
@export var dodge_invulnerability_time: float = 0.1
@export var dodge_afterimage_interval: float = 0.035
@export var projectile_scene: PackedScene
@export var afterimage_scene: PackedScene
@export var player_bleed_vfx_scene: PackedScene

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
@onready var inventory: Node = $Inventory
@onready var melee_root: Node2D = $MeleeRoot
@onready var melee_hit_area: Area2D = $MeleeRoot/MeleeHitArea
@onready var melee_slash_visual: Polygon2D = $MeleeRoot/SlashVisual

var current_ammo: int = 0
var reserve_ammo: int = 0
var current_stamina: float = 0.0
var is_stamina_overheated: bool = false

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
var _damage_knockback_velocity: Vector2 = Vector2.ZERO
var _stamina_recovery_delay_remaining: float = 0.0
var _melee_state: MeleeState = MeleeState.READY
var _melee_timer: float = 0.0
var _melee_direction: int = 1
var _melee_combo_step: int = 0
var _current_melee_step: int = 0
var _melee_combo_reset_remaining: float = 0.0
var _queued_melee_attack: bool = false
var _melee_hit_bodies: Array[Node] = []
var _is_dodging: bool = false
var _dodge_timer: float = 0.0
var _dodge_cooldown_remaining: float = 0.0
var _dodge_direction: int = 1
var _afterimage_timer: float = 0.0
var _suppress_inventory_ammo_signal: bool = false


func _ready() -> void:
	if ProjectSettings.has_setting("physics/2d/default_gravity"):
		_gravity = float(ProjectSettings.get_setting("physics/2d/default_gravity"))
	current_ammo = magazine_size
	inventory.item_quantity_changed.connect(_on_inventory_item_quantity_changed)
	if inventory.get_quantity(ammo_item_id) <= 0 and starting_reserve_ammo > 0:
		inventory.add_item(ammo_item_id, starting_reserve_ammo)
	_sync_reserve_ammo(false)
	current_stamina = max_stamina
	_configure_aim_bones()
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)
	interaction_area.area_entered.connect(_on_interaction_area_entered)
	interaction_area.area_exited.connect(_on_interaction_area_exited)
	_set_crouching(false)
	_set_melee_visual(false)
	_update_arm_anchor()
	ammo_changed.emit(current_ammo, reserve_ammo)
	_emit_stamina_changed()


func _physics_process(delta: float) -> void:
	if _is_dead:
		return

	_update_timers(delta)
	_update_stamina(delta)
	_handle_actions()
	_update_melee(delta)
	_update_dodge(delta)
	_handle_movement(delta)
	move_and_slide()
	_update_aim(delta)


func _update_timers(delta: float) -> void:
	_fire_cooldown_remaining -= delta
	if _fire_cooldown_remaining < 0.0:
		_fire_cooldown_remaining = 0.0

	_dodge_cooldown_remaining -= delta
	if _dodge_cooldown_remaining < 0.0:
		_dodge_cooldown_remaining = 0.0

	if _stamina_recovery_delay_remaining > 0.0:
		_stamina_recovery_delay_remaining -= delta

	if _melee_state == MeleeState.READY and _melee_combo_reset_remaining > 0.0:
		_melee_combo_reset_remaining -= delta
		if _melee_combo_reset_remaining <= 0.0:
			_melee_combo_step = 0
			_queued_melee_attack = false

	if _is_reloading:
		_reload_remaining -= delta
		if _reload_remaining <= 0.0:
			_finish_reload()


func _update_stamina(delta: float) -> void:
	if is_stamina_overheated:
		if _stamina_recovery_delay_remaining > 0.0 or _melee_state != MeleeState.READY:
			return

		_set_stamina(current_stamina + overheat_recovery_rate * delta)
		if current_stamina >= max_stamina:
			is_stamina_overheated = false
			_set_stamina(max_stamina)
		return

	if _stamina_recovery_delay_remaining > 0.0 or _melee_state != MeleeState.READY:
		return

	if current_stamina < max_stamina:
		_set_stamina(current_stamina + stamina_recovery_rate * delta)


func _handle_movement(delta: float) -> void:
	var input_axis: float = Input.get_axis("move_left", "move_right")
	var action_locked := _is_dodging or _melee_state != MeleeState.READY
	var wants_crouch: bool = Input.is_action_pressed("crouch") and is_on_floor() and not action_locked
	_set_crouching(wants_crouch)

	var active_speed: float = walk_speed
	if _is_crouching:
		active_speed *= crouch_speed_multiplier

	if _is_dodging:
		velocity.x = float(_dodge_direction) * dodge_speed
	elif _melee_state == MeleeState.LUNGE:
		velocity.x = float(_melee_direction) * melee_lunge_speed + _damage_knockback_velocity.x
	elif _melee_state == MeleeState.STRIKE or _melee_state == MeleeState.RECOVERY:
		velocity.x = _damage_knockback_velocity.x
	else:
		velocity.x = input_axis * active_speed + _damage_knockback_velocity.x

	if not is_on_floor():
		velocity.y += _gravity * delta
	elif velocity.y > 0.0:
		velocity.y = 0.0

	if Input.is_action_just_pressed("jump") and is_on_floor() and not _is_crouching and not action_locked:
		velocity.y = jump_velocity

	_damage_knockback_velocity = _damage_knockback_velocity.move_toward(Vector2.ZERO, damage_knockback_recovery * delta)


func _handle_actions() -> void:
	if Input.is_action_just_pressed("dodge"):
		_try_start_dodge()

	if Input.is_action_just_pressed("melee_attack"):
		_handle_melee_input()

	if _is_dodging or _melee_state != MeleeState.READY:
		return

	if Input.is_action_just_pressed("interact"):
		_interact_with_nearest()
		interact_requested.emit()

	if Input.is_action_just_pressed("reload"):
		_start_reload()

	if Input.is_action_pressed("fire"):
		_try_fire()


func _update_aim(delta: float) -> void:
	if _is_dodging or _melee_state != MeleeState.READY:
		return

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
	var ammo_to_load: int = mini(inventory.get_quantity(ammo_item_id), ammo_needed)
	current_ammo += ammo_to_load
	_suppress_inventory_ammo_signal = true
	inventory.remove_item(ammo_item_id, ammo_to_load)
	_suppress_inventory_ammo_signal = false
	_is_reloading = false
	_reload_remaining = 0.0
	_sync_reserve_ammo()


func _update_dodge(delta: float) -> void:
	if not _is_dodging:
		return

	_dodge_timer -= delta
	_afterimage_timer -= delta
	if _afterimage_timer <= 0.0:
		_spawn_afterimage()
		_afterimage_timer = dodge_afterimage_interval

	if _dodge_timer <= 0.0:
		_is_dodging = false
		body_root.modulate = Color.WHITE
		arm_rig.modulate = Color.WHITE


func _try_start_dodge() -> void:
	if _is_dodging or _dodge_cooldown_remaining > 0.0 or not is_on_floor():
		return

	if _melee_state == MeleeState.STRIKE:
		return

	if _melee_state != MeleeState.READY:
		_cancel_melee_attack()

	_dodge_direction = _get_action_direction()
	_is_dodging = true
	_dodge_timer = dodge_duration
	_dodge_cooldown_remaining = dodge_cooldown
	_afterimage_timer = 0.0
	_set_crouching(false)
	health.set_invulnerable_for(dodge_invulnerability_time)
	body_root.modulate = Color(0.72, 0.78, 0.86, 1.0)
	arm_rig.modulate = Color(0.72, 0.78, 0.86, 1.0)
	_spawn_afterimage()


func _get_action_direction() -> int:
	var input_axis: float = Input.get_axis("move_left", "move_right")
	if absf(input_axis) > 0.01:
		return int(signf(input_axis))

	var mouse_offset_x := get_global_mouse_position().x - global_position.x
	if mouse_offset_x > aim_flip_dead_zone:
		return 1
	if mouse_offset_x < -aim_flip_dead_zone:
		return -1

	return _facing


func _spawn_afterimage() -> void:
	if afterimage_scene == null:
		return

	var afterimage := afterimage_scene.instantiate()
	var afterimage_parent := get_tree().current_scene
	if afterimage_parent == null:
		afterimage_parent = get_parent()
	afterimage_parent.add_child(afterimage)
	if afterimage is Node2D:
		var afterimage_2d := afterimage as Node2D
		afterimage_2d.global_position = global_position
		afterimage_2d.scale.x = float(_facing)


func _handle_melee_input() -> void:
	if _is_dodging:
		return

	if _melee_state == MeleeState.READY:
		if _melee_combo_reset_remaining <= 0.0:
			_melee_combo_step = 0
		_try_start_melee_attack()
	elif (_melee_state == MeleeState.STRIKE or _melee_state == MeleeState.RECOVERY) and _melee_combo_step <= 2:
		_queued_melee_attack = true


func _try_start_melee_attack() -> void:
	if not is_on_floor():
		return

	if not _can_use_melee_stamina():
		stamina_use_failed.emit()
		return

	_current_melee_step = clampi(_melee_combo_step, 0, 2)
	_melee_combo_step = _current_melee_step + 1
	_melee_combo_reset_remaining = melee_combo_reset_time
	_queued_melee_attack = false
	_melee_hit_bodies.clear()
	_melee_direction = _get_action_direction()
	_set_crouching(false)
	_set_facing(_melee_direction)
	_consume_stamina(melee_stamina_cost)
	_melee_state = MeleeState.LUNGE
	_melee_timer = melee_lunge_time
	_set_melee_visual(true)


func _update_melee(delta: float) -> void:
	match _melee_state:
		MeleeState.READY:
			return
		MeleeState.LUNGE:
			_melee_timer -= delta
			if _melee_timer <= 0.0 or _melee_has_enemy_contact():
				_enter_melee_strike()
		MeleeState.STRIKE:
			_melee_timer -= delta
			_apply_melee_damage()
			if _melee_timer <= 0.0:
				_enter_melee_recovery()
		MeleeState.RECOVERY:
			_melee_timer -= delta
			if _melee_timer <= 0.0:
				_finish_melee_recovery()


func _enter_melee_strike() -> void:
	_melee_state = MeleeState.STRIKE
	_melee_timer = melee_strike_time
	_apply_melee_damage()
	melee_slash_visual.color = Color(0.92, 0.82, 0.55, 0.82)


func _enter_melee_recovery() -> void:
	_melee_state = MeleeState.RECOVERY
	_melee_timer = melee_recovery_time
	melee_slash_visual.color = Color(0.72, 0.62, 0.42, 0.45)


func _finish_melee_recovery() -> void:
	_set_melee_visual(false)

	if _queued_melee_attack and _melee_combo_step <= 2 and not is_stamina_overheated:
		_try_start_melee_attack()
		return

	_melee_state = MeleeState.READY
	_queued_melee_attack = false
	if _melee_combo_step > 2:
		_melee_combo_step = 0
		_melee_combo_reset_remaining = 0.0


func _cancel_melee_attack() -> void:
	_melee_state = MeleeState.READY
	_melee_timer = 0.0
	_queued_melee_attack = false
	_melee_hit_bodies.clear()
	_set_melee_visual(false)


func _melee_has_enemy_contact() -> bool:
	for body in melee_hit_area.get_overlapping_bodies():
		if body.get_node_or_null("Health") != null:
			return true
	return false


func _apply_melee_damage() -> void:
	var damage := _get_melee_damage()
	var hit_position := melee_hit_area.global_position

	for body in melee_hit_area.get_overlapping_bodies():
		if body in _melee_hit_bodies:
			continue

		var health_node := body.get_node_or_null("Health")
		if health_node == null:
			continue

		_melee_hit_bodies.append(body)
		if body.has_method("apply_hit_reaction"):
			body.call("apply_hit_reaction", Vector2(_melee_direction, 0.0), damage, hit_position)
		health_node.apply_damage(damage)


func _get_melee_damage() -> int:
	match _current_melee_step:
		0:
			return 34
		1:
			return 48
		_:
			return 68


func _consume_stamina(amount: float) -> void:
	var next_stamina: float = current_stamina - amount
	if next_stamina <= 0.0:
		is_stamina_overheated = true
		_stamina_recovery_delay_remaining = stamina_empty_hold_time
		_set_stamina(0.0)
	else:
		_stamina_recovery_delay_remaining = stamina_recovery_delay
		_set_stamina(next_stamina)


func _set_stamina(value: float) -> void:
	current_stamina = clampf(value, 0.0, max_stamina)
	_emit_stamina_changed()


func _emit_stamina_changed() -> void:
	stamina_changed.emit(current_stamina, max_stamina, is_stamina_overheated, _can_use_melee_stamina())


func _can_use_melee_stamina() -> bool:
	return not is_stamina_overheated and current_stamina >= melee_min_stamina_to_use


func _set_melee_visual(visible: bool) -> void:
	melee_root.visible = visible
	melee_hit_area.monitoring = visible
	melee_root.scale.x = float(_melee_direction)
	melee_slash_visual.visible = visible


func _set_facing(direction: int) -> void:
	if direction == 0:
		return
	_facing = direction
	body_root.scale.x = float(_facing)
	_update_arm_anchor()


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


func _sync_reserve_ammo(should_emit: bool = true) -> void:
	reserve_ammo = inventory.get_quantity(ammo_item_id)
	if should_emit:
		ammo_changed.emit(current_ammo, reserve_ammo)


func _on_inventory_item_quantity_changed(item_id: StringName, _quantity: int) -> void:
	if item_id != ammo_item_id:
		return

	_sync_reserve_ammo(not _suppress_inventory_ammo_signal)


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


func apply_damage_reaction(direction: Vector2, _damage: int, _source_position: Vector2) -> void:
	if health.has_method("is_damage_blocked") and health.call("is_damage_blocked"):
		return

	var knockback_direction := direction.normalized()
	if knockback_direction == Vector2.ZERO:
		knockback_direction = Vector2.RIGHT

	_damage_knockback_velocity.x = knockback_direction.x * damage_knockback_strength
	if is_on_floor():
		velocity.y = damage_knockback_lift


func _on_damaged(_amount: int, _current_health: int, _max_health: int) -> void:
	if _is_dead:
		return

	_spawn_player_bleed()

	if _damage_flash_tween != null:
		_damage_flash_tween.kill()

	body_root.modulate = Color(1.0, 0.45, 0.42, 1.0)
	arm_rig.modulate = Color(1.0, 0.45, 0.42, 1.0)
	_damage_flash_tween = create_tween()
	_damage_flash_tween.tween_property(body_root, "modulate", Color.WHITE, damage_flash_time)
	_damage_flash_tween.parallel().tween_property(arm_rig, "modulate", Color.WHITE, damage_flash_time)


func _spawn_player_bleed() -> void:
	if player_bleed_vfx_scene == null:
		return

	var vfx := player_bleed_vfx_scene.instantiate()
	var vfx_parent := get_tree().current_scene
	if vfx_parent == null:
		vfx_parent = get_parent()
	vfx_parent.add_child(vfx)

	if vfx is Node2D:
		var vfx_2d := vfx as Node2D
		vfx_2d.global_position = global_position + Vector2(0, -28)
