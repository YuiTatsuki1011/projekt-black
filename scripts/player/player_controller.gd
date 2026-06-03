extends CharacterBody2D
class_name PlayerController

signal ammo_changed(current_ammo: int, reserve_ammo: int)
signal fired(ammo_remaining: int)
signal reload_started(duration: float)
signal chambering_started(duration: float)
signal magazine_status_changed(magazines: Array, loading_entry_id: int, loading_progress: float, is_loading: bool)
signal interact_requested
signal died
signal stamina_changed(current_stamina: float, max_stamina: float, overheated: bool, melee_available: bool)
signal stamina_use_failed
signal damage_feedback(direction: Vector2)

const ENEMY_COLLISION_MASK: int = 8
const FIREARM_SLOT_IDS := [&"firearm_1", &"firearm_2", &"firearm_3", &"firearm_4"]
const DROPPED_ITEM_SCENE := preload("res://scenes/interaction/dropped_item.tscn")
const ACTIVE_MAGAZINE_STATUS_ENTRY_ID := -10001
const INTERACTION_HIGHLIGHT_NAME := "InteractionHighlight"

enum MeleeState {
	READY,
	LUNGE,
	STRIKE,
	RECOVERY,
}

enum MovementMode {
	SIDE_VIEW,
	TOP_DOWN,
}

@export var movement_mode: MovementMode = MovementMode.SIDE_VIEW
@export var walk_speed: float = 160.0
@export var crouch_speed_multiplier: float = 0.45
@export var sub_weapon_aim_speed_multiplier: float = 0.58
@export var jump_velocity: float = -360.0
@export var bullet_damage: int = 10
@export var magazine_size: int = 6
@export var starting_reserve_ammo: int = 24
@export var ammo_item_id: StringName = &"pistol_ammo"
@export var magazine_item_id: StringName = &"pistol_magazine"
@export var chamber_size: int = 1
@export var starting_spare_magazines: int = 3
@export var reload_time: float = 1.2
@export var chamber_feed_time: float = 0.5
@export var field_magazine_load_time_per_round: float = 0.28
@export var field_load_speed_multiplier: float = 0.72
@export var fire_cooldown: float = 0.22
@export var recoil_amount: float = 0.18
@export var recoil_recovery_speed: float = 8.0
@export var recoil_max_amount: float = 0.65
@export var aim_follow_speed: float = 16.0
@export var aim_indicator_base_radius: float = 5.0
@export var aim_indicator_recoil_radius: float = 34.0
@export var shot_spread_angle_per_recoil: float = 0.12
@export_flags_2d_physics var aim_blocker_mask: int = 1
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
@export var inventory_pose_tilt_degrees: float = -5.0
@export var top_down_collision_size: Vector2 = Vector2(24.0, 24.0)
@export var top_down_interaction_radius: float = 62.0
@export var top_down_camera_zoom: Vector2 = Vector2(1.45, 1.45)

@onready var body_root: Node2D = $VisualRoot/BodyRoot
@onready var arm_rig: Node2D = $ArmRig
@onready var upper_arm_bone: Bone2D = $ArmRig/Skeleton2D/UpperArmBone
@onready var forearm_bone: Bone2D = $ArmRig/Skeleton2D/UpperArmBone/ForearmBone
@onready var hand_bone: Bone2D = $ArmRig/Skeleton2D/UpperArmBone/ForearmBone/HandBone
@onready var gun_root: Node2D = $ArmRig/Skeleton2D/UpperArmBone/ForearmBone/HandBone/GunRoot
@onready var muzzle: Marker2D = $ArmRig/Skeleton2D/UpperArmBone/ForearmBone/HandBone/GunRoot/Muzzle
@onready var standing_collision: CollisionShape2D = $StandingCollision
@onready var crouching_collision: CollisionShape2D = $CrouchingCollision
@onready var interaction_area: Area2D = $InteractionArea
@onready var health: Node = $Health
@onready var inventory: Node = $Inventory
@onready var equipment: Node = get_node_or_null("Equipment")
@onready var melee_root: Node2D = $MeleeRoot
@onready var melee_hit_area: Area2D = $MeleeRoot/MeleeHitArea
@onready var melee_slash_visual: Polygon2D = $MeleeRoot/SlashVisual
@onready var camera: Camera2D = $Camera2D

var current_ammo: int = 0
var reserve_ammo: int = 0
var chamber_ammo: int = 0
var magazine_ammo: int = 0
var current_stamina: float = 0.0
var is_stamina_overheated: bool = false

var _gravity: float = 980.0
var _fire_cooldown_remaining: float = 0.0
var _reload_remaining: float = 0.0
var _is_reloading: bool = false
var _chambering_remaining: float = 0.0
var _is_chambering: bool = false
var _is_field_magazine_loading: bool = false
var _field_magazine_load_elapsed: float = 0.0
var _field_magazine_load_entry_id: int = -1
var _field_magazine_load_ammo_entry_id: int = -1
var _field_load_input_was_pressed: bool = false
var _is_crouching: bool = false
var _is_dead: bool = false
var _is_inventory_open: bool = false
var _facing: int = 1
var _recoil: float = 0.0
var _nearby_interactables: Array[Node2D] = []
var _highlighted_interactables: Array[Node2D] = []
var _damage_flash_tween: Tween
var _damage_knockback_velocity: Vector2 = Vector2.ZERO
var _stamina_recovery_delay_remaining: float = 0.0
var _melee_state: MeleeState = MeleeState.READY
var _melee_timer: float = 0.0
var _melee_direction: int = 1
var _melee_vector: Vector2 = Vector2.RIGHT
var _melee_combo_step: int = 0
var _current_melee_step: int = 0
var _melee_combo_reset_remaining: float = 0.0
var _queued_melee_attack: bool = false
var _melee_hit_bodies: Array[Node] = []
var _is_dodging: bool = false
var _dodge_timer: float = 0.0
var _dodge_cooldown_remaining: float = 0.0
var _dodge_direction: int = 1
var _dodge_vector: Vector2 = Vector2.RIGHT
var _afterimage_timer: float = 0.0
var _suppress_inventory_ammo_signal: bool = false
var _has_ranged_weapon: bool = true
var _has_melee_weapon: bool = true
var _active_firearm_slot: StringName = &"firearm_1"
var _firearm_weapon_id_by_slot: Dictionary = {}
var _firearm_magazine_rounds_by_slot: Dictionary = {}
var _firearm_chamber_rounds_by_slot: Dictionary = {}
var _firearm_has_magazine_by_slot: Dictionary = {}
var _firearm_magazine_item_id_by_slot: Dictionary = {}
var _firearm_slot_input_was_pressed: Array[bool] = [false, false, false, false]
var _desired_aim_position: Vector2 = Vector2.ZERO
var _actual_aim_position: Vector2 = Vector2.ZERO
var _aim_initialized: bool = false
var _is_sub_weapon_aiming: bool = false
var _sub_weapon_fire_was_pressed: bool = false
var _melee_combo_damages: PackedInt32Array = PackedInt32Array([34, 48, 68])
var _pending_damage_direction: Vector2 = Vector2.ZERO
var _body_rotation_before_inventory: float = 0.0
var _arm_rig_was_visible_before_inventory: bool = true


func _ready() -> void:
	if ProjectSettings.has_setting("physics/2d/default_gravity"):
		_gravity = float(ProjectSettings.get_setting("physics/2d/default_gravity"))
	_configure_movement_mode_nodes()
	_apply_equipment_stats()
	_sync_all_firearm_slot_caches()
	_load_active_firearm_ammo()
	if equipment != null and equipment.has_signal("equipment_changed"):
		equipment.connect("equipment_changed", Callable(self, "_on_equipment_changed"))
	inventory.item_quantity_changed.connect(_on_inventory_item_quantity_changed)
	if inventory.has_signal("grid_changed"):
		inventory.grid_changed.connect(_on_inventory_grid_changed)
	_ensure_starting_ammo_supplies()
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
	_emit_magazine_status_changed()
	_emit_stamina_changed()


func _configure_movement_mode_nodes() -> void:
	if movement_mode != MovementMode.TOP_DOWN:
		return

	standing_collision.position = Vector2.ZERO
	if standing_collision.shape is RectangleShape2D:
		var standing_shape := standing_collision.shape.duplicate() as RectangleShape2D
		standing_shape.size = top_down_collision_size
		standing_collision.shape = standing_shape

	crouching_collision.position = Vector2.ZERO
	if crouching_collision.shape is RectangleShape2D:
		var crouching_shape := crouching_collision.shape.duplicate() as RectangleShape2D
		crouching_shape.size = top_down_collision_size * Vector2(0.85, 0.85)
		crouching_collision.shape = crouching_shape

	interaction_area.position = Vector2.ZERO
	var interaction_shape_node := interaction_area.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if interaction_shape_node != null and interaction_shape_node.shape is CircleShape2D:
		var interaction_shape := interaction_shape_node.shape.duplicate() as CircleShape2D
		interaction_shape.radius = top_down_interaction_radius
		interaction_shape_node.shape = interaction_shape

	if camera != null:
		camera.position = Vector2.ZERO
		camera.zoom = top_down_camera_zoom


func _apply_equipment_stats() -> void:
	if equipment == null:
		return

	_active_firearm_slot = _get_active_firearm_slot_from_equipment()
	if equipment.has_method("get_ranged_weapon"):
		var ranged_weapon: Resource = equipment.call("get_ranged_weapon") as Resource
		if ranged_weapon != null:
			_has_ranged_weapon = true
			_apply_ranged_weapon_stats(ranged_weapon)
		else:
			_clear_ranged_weapon_stats()

	if equipment.has_method("get_melee_weapon"):
		var melee_weapon: Resource = equipment.call("get_melee_weapon") as Resource
		if melee_weapon != null:
			_has_melee_weapon = true
			_apply_melee_weapon_stats(melee_weapon)
		else:
			_clear_melee_weapon_stats()


func _apply_ranged_weapon_stats(ranged_weapon: Resource) -> void:
	_set_ranged_visual(true)
	bullet_damage = int(_get_resource_value(ranged_weapon, &"damage", bullet_damage))
	magazine_size = int(_get_resource_value(ranged_weapon, &"magazine_size", magazine_size))
	starting_reserve_ammo = int(_get_resource_value(ranged_weapon, &"starting_reserve_ammo", starting_reserve_ammo))
	ammo_item_id = StringName(_get_resource_value(ranged_weapon, &"ammo_item_id", ammo_item_id))
	magazine_item_id = StringName(_get_resource_value(ranged_weapon, &"magazine_item_id", magazine_item_id))
	chamber_size = int(_get_resource_value(ranged_weapon, &"chamber_size", chamber_size))
	starting_spare_magazines = int(_get_resource_value(ranged_weapon, &"starting_spare_magazines", starting_spare_magazines))
	reload_time = float(_get_resource_value(ranged_weapon, &"reload_time", reload_time))
	chamber_feed_time = float(_get_resource_value(ranged_weapon, &"chamber_feed_time", chamber_feed_time))
	field_magazine_load_time_per_round = float(_get_resource_value(
		ranged_weapon,
		&"field_magazine_load_time_per_round",
		field_magazine_load_time_per_round
	))
	fire_cooldown = float(_get_resource_value(ranged_weapon, &"fire_cooldown", fire_cooldown))
	recoil_amount = float(_get_resource_value(ranged_weapon, &"recoil_amount", recoil_amount))
	recoil_recovery_speed = float(_get_resource_value(ranged_weapon, &"recoil_recovery_speed", recoil_recovery_speed))
	aim_follow_speed = float(_get_resource_value(ranged_weapon, &"aim_follow_speed", aim_follow_speed))
	var next_projectile_scene: PackedScene = _get_resource_value(ranged_weapon, &"projectile_scene", projectile_scene) as PackedScene
	if next_projectile_scene != null:
		projectile_scene = next_projectile_scene


func _apply_melee_weapon_stats(melee_weapon: Resource) -> void:
	var next_combo_damages: Variant = _get_resource_value(melee_weapon, &"combo_damages", _melee_combo_damages)
	if next_combo_damages is PackedInt32Array:
		_melee_combo_damages = next_combo_damages
	melee_stamina_cost = float(_get_resource_value(melee_weapon, &"stamina_cost", melee_stamina_cost))
	melee_min_stamina_to_use = float(_get_resource_value(melee_weapon, &"min_stamina_to_use", melee_min_stamina_to_use))
	melee_lunge_speed = float(_get_resource_value(melee_weapon, &"lunge_speed", melee_lunge_speed))
	melee_lunge_time = float(_get_resource_value(melee_weapon, &"lunge_time", melee_lunge_time))
	melee_strike_time = float(_get_resource_value(melee_weapon, &"strike_time", melee_strike_time))
	melee_recovery_time = float(_get_resource_value(melee_weapon, &"recovery_time", melee_recovery_time))
	melee_combo_reset_time = float(_get_resource_value(melee_weapon, &"combo_reset_time", melee_combo_reset_time))


func _clear_ranged_weapon_stats() -> void:
	_has_ranged_weapon = false
	_set_ranged_visual(false)
	bullet_damage = 0
	magazine_size = 0
	starting_reserve_ammo = 0
	chamber_size = 0
	starting_spare_magazines = 0
	reload_time = 0.0
	chamber_feed_time = 0.0
	field_magazine_load_time_per_round = 0.0
	fire_cooldown = 0.0
	recoil_amount = 0.0
	_recoil = 0.0
	_aim_initialized = false
	forearm_bone.rotation = 0.0
	projectile_scene = null


func _clear_melee_weapon_stats() -> void:
	_has_melee_weapon = false
	_is_sub_weapon_aiming = false
	_sub_weapon_fire_was_pressed = false
	_melee_combo_damages = PackedInt32Array()
	melee_stamina_cost = 0.0
	melee_min_stamina_to_use = INF
	_melee_state = MeleeState.READY
	_melee_timer = 0.0
	_queued_melee_attack = false
	_melee_combo_step = 0
	_current_melee_step = 0
	_melee_hit_bodies.clear()
	_set_sub_weapon_aim_visual(false)
	_set_melee_visual(false)


func _get_resource_value(resource: Resource, property_name: StringName, fallback: Variant) -> Variant:
	var value: Variant = resource.get(property_name)
	if value == null:
		return fallback

	return value


func _get_active_firearm_slot_from_equipment() -> StringName:
	if equipment != null and equipment.has_method("get_active_firearm_slot"):
		return StringName(equipment.call("get_active_firearm_slot"))

	return &"firearm_1"


func _is_firearm_slot(slot: StringName) -> bool:
	return slot in FIREARM_SLOT_IDS


func _is_firearm_equipment_event(slot: StringName) -> bool:
	return slot == &"ranged" or _is_firearm_slot(slot)


func _get_equipped_firearm_for_slot(slot: StringName) -> Resource:
	if equipment == null:
		return null

	if equipment.has_method("get_weapon"):
		return equipment.call("get_weapon", slot) as Resource

	if slot == &"firearm_1" and equipment.has_method("get_ranged_weapon"):
		return equipment.call("get_ranged_weapon") as Resource

	return null


func _get_weapon_id(weapon: Resource) -> StringName:
	if weapon == null:
		return &""

	return StringName(str(weapon.get("weapon_id")))


func _get_weapon_display_name(weapon: Resource) -> String:
	if weapon == null:
		return ""

	var display_name: Variant = weapon.get("display_name")
	if display_name != null and not str(display_name).is_empty():
		return str(display_name)

	return str(_get_weapon_id(weapon))


func _get_active_firearm_display_name() -> String:
	return _get_weapon_display_name(_get_equipped_firearm_for_slot(_active_firearm_slot))


func _get_weapon_magazine_size(weapon: Resource) -> int:
	if weapon == null:
		return 0

	return int(_get_resource_value(weapon, &"magazine_size", 0))


func _get_weapon_magazine_item_id(weapon: Resource) -> StringName:
	if weapon == null:
		return &""

	return StringName(_get_resource_value(weapon, &"magazine_item_id", &""))


func _get_weapon_chamber_size(weapon: Resource) -> int:
	if weapon == null:
		return 0

	return int(_get_resource_value(weapon, &"chamber_size", 0))


func _sync_all_firearm_slot_caches() -> void:
	for slot in FIREARM_SLOT_IDS:
		_sync_firearm_slot_cache(slot)


func _sync_firearm_slot_cache(slot: StringName) -> void:
	var weapon := _get_equipped_firearm_for_slot(slot)
	if weapon == null:
		_firearm_weapon_id_by_slot.erase(slot)
		_firearm_magazine_rounds_by_slot.erase(slot)
		_firearm_chamber_rounds_by_slot.erase(slot)
		_firearm_has_magazine_by_slot.erase(slot)
		_firearm_magazine_item_id_by_slot.erase(slot)
		return

	var weapon_id := _get_weapon_id(weapon)
	if _firearm_weapon_id_by_slot.get(slot, &"") == weapon_id:
		return

	_firearm_weapon_id_by_slot[slot] = weapon_id
	_firearm_magazine_rounds_by_slot[slot] = _get_weapon_magazine_size(weapon)
	_firearm_chamber_rounds_by_slot[slot] = 1 if _get_weapon_chamber_size(weapon) > 0 else 0
	_firearm_has_magazine_by_slot[slot] = _get_weapon_magazine_size(weapon) > 0
	_firearm_magazine_item_id_by_slot[slot] = _get_weapon_magazine_item_id(weapon)


func _save_active_firearm_ammo() -> void:
	if _active_firearm_slot == &"" or not _has_ranged_weapon:
		return

	_firearm_magazine_rounds_by_slot[_active_firearm_slot] = magazine_ammo
	_firearm_chamber_rounds_by_slot[_active_firearm_slot] = chamber_ammo
	_firearm_has_magazine_by_slot[_active_firearm_slot] = _has_active_magazine_inserted()
	_firearm_magazine_item_id_by_slot[_active_firearm_slot] = magazine_item_id


func _load_active_firearm_ammo() -> void:
	if not _has_ranged_weapon:
		current_ammo = 0
		magazine_ammo = 0
		chamber_ammo = 0
		_cancel_chambering()
		_cancel_field_magazine_loading()
		return

	if not _firearm_magazine_rounds_by_slot.has(_active_firearm_slot):
		_firearm_magazine_rounds_by_slot[_active_firearm_slot] = magazine_size
	if not _firearm_chamber_rounds_by_slot.has(_active_firearm_slot):
		_firearm_chamber_rounds_by_slot[_active_firearm_slot] = 1 if chamber_size > 0 else 0
	if not _firearm_has_magazine_by_slot.has(_active_firearm_slot):
		_firearm_has_magazine_by_slot[_active_firearm_slot] = magazine_size > 0
	if not _firearm_magazine_item_id_by_slot.has(_active_firearm_slot):
		_firearm_magazine_item_id_by_slot[_active_firearm_slot] = magazine_item_id

	magazine_ammo = clampi(int(_firearm_magazine_rounds_by_slot.get(_active_firearm_slot, magazine_size)), 0, magazine_size)
	chamber_ammo = clampi(int(_firearm_chamber_rounds_by_slot.get(_active_firearm_slot, 0)), 0, chamber_size)
	_update_current_ammo_from_loaded_parts()


func _on_equipment_changed(slot: StringName) -> void:
	var is_firearm_event := _is_firearm_equipment_event(slot)
	if is_firearm_event:
		_save_active_firearm_ammo()
		_sync_all_firearm_slot_caches()

	_apply_equipment_stats()

	if is_firearm_event:
		_load_active_firearm_ammo()
		_is_reloading = false
		_reload_remaining = 0.0
		_cancel_chambering()
		_cancel_field_magazine_loading()
		_sync_reserve_ammo()
		_emit_magazine_status_changed()

	if slot == &"melee":
		_melee_combo_step = 0
		_current_melee_step = 0
		_queued_melee_attack = false
		_emit_stamina_changed()


func _physics_process(delta: float) -> void:
	if _is_dead:
		return

	_update_timers(delta)
	_update_stamina(delta)
	_update_interaction_highlights()
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

	if _is_chambering:
		_chambering_remaining -= delta
		if _chambering_remaining <= 0.0:
			_finish_chambering()

	_update_field_magazine_loading(delta)


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
	if movement_mode == MovementMode.TOP_DOWN:
		_handle_top_down_movement(delta)
		return

	_handle_side_view_movement(delta)


func _handle_side_view_movement(delta: float) -> void:
	var action_locked := _is_inventory_open or _is_dodging or _melee_state != MeleeState.READY
	var input_axis: float = 0.0 if _is_inventory_open else Input.get_axis("move_left", "move_right")
	var wants_crouch: bool = Input.is_action_pressed("crouch") and is_on_floor() and not action_locked
	_set_crouching(wants_crouch)

	var active_speed: float = walk_speed
	if _is_crouching:
		active_speed *= crouch_speed_multiplier
	if _is_sub_weapon_aiming:
		active_speed *= sub_weapon_aim_speed_multiplier
	if _is_field_magazine_loading:
		active_speed *= field_load_speed_multiplier

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


func _handle_top_down_movement(delta: float) -> void:
	var action_locked := _is_inventory_open or _is_dodging or _melee_state != MeleeState.READY
	var input_vector := Vector2.ZERO if _is_inventory_open else _get_top_down_input_vector()
	var wants_crouch := Input.is_action_pressed("crouch") and not action_locked
	_set_crouching(wants_crouch)

	var active_speed: float = walk_speed
	if _is_crouching:
		active_speed *= crouch_speed_multiplier
	if _is_sub_weapon_aiming:
		active_speed *= sub_weapon_aim_speed_multiplier
	if _is_field_magazine_loading:
		active_speed *= field_load_speed_multiplier

	if _is_dodging:
		velocity = _dodge_vector * dodge_speed + _damage_knockback_velocity
	elif _melee_state == MeleeState.LUNGE:
		velocity = _melee_vector * melee_lunge_speed + _damage_knockback_velocity
	elif _melee_state == MeleeState.STRIKE or _melee_state == MeleeState.RECOVERY:
		velocity = _damage_knockback_velocity
	else:
		velocity = input_vector * active_speed + _damage_knockback_velocity

	_damage_knockback_velocity = _damage_knockback_velocity.move_toward(Vector2.ZERO, damage_knockback_recovery * delta)


func _handle_actions() -> void:
	if _is_inventory_open:
		return

	_handle_field_magazine_load_input()

	if Input.is_action_just_pressed("dodge"):
		_cancel_field_magazine_loading()
		_try_start_dodge()

	_handle_firearm_slot_inputs()
	_update_sub_weapon_aiming()
	if _is_chambering:
		return

	var sub_weapon_modifier_pressed := (
		Input.is_action_pressed("sub_weapon_aim")
		and _has_melee_weapon
		and not _is_dodging
	)
	var fire_pressed := Input.is_action_pressed("fire")
	var sub_weapon_fire_just_pressed := fire_pressed and not _sub_weapon_fire_was_pressed
	_sub_weapon_fire_was_pressed = fire_pressed

	if sub_weapon_modifier_pressed and sub_weapon_fire_just_pressed:
		_cancel_field_magazine_loading()
		_handle_melee_input()

	if _is_dodging or _melee_state != MeleeState.READY:
		return

	if Input.is_action_just_pressed("interact"):
		_interact_with_nearest()
		interact_requested.emit()

	_handle_reload_input()

	if not sub_weapon_modifier_pressed and fire_pressed:
		_cancel_field_magazine_loading()
		_try_fire()


func _handle_reload_input() -> void:
	if Input.is_action_just_pressed("reload"):
		_cancel_field_magazine_loading()
		_start_reload()


func _handle_firearm_slot_inputs() -> void:
	if equipment == null or not equipment.has_method("select_firearm_slot"):
		return

	for slot_index in range(1, FIREARM_SLOT_IDS.size() + 1):
		var action_name := "weapon_slot_%d" % slot_index
		var is_pressed := Input.is_action_pressed(action_name)
		var was_pressed := _firearm_slot_input_was_pressed[slot_index - 1]
		_firearm_slot_input_was_pressed[slot_index - 1] = is_pressed
		if is_pressed and not was_pressed:
			equipment.call("select_firearm_slot", slot_index)
			return


func _handle_field_magazine_load_input() -> void:
	var is_pressed := Input.is_action_pressed("field_load")
	var just_pressed := is_pressed and not _field_load_input_was_pressed
	_field_load_input_was_pressed = is_pressed
	if not just_pressed:
		return

	if _is_field_magazine_loading:
		_cancel_field_magazine_loading()
	else:
		_start_field_magazine_loading()


func _start_field_magazine_loading() -> bool:
	if _is_inventory_open or _is_reloading or _is_chambering or _is_dodging:
		return false
	if not _has_ranged_weapon:
		return false
	if not _refresh_field_magazine_load_entries():
		_emit_magazine_status_changed()
		return false

	_is_field_magazine_loading = true
	_field_magazine_load_elapsed = 0.0
	_emit_magazine_status_changed()
	return true


func _update_field_magazine_loading(delta: float) -> void:
	if not _is_field_magazine_loading:
		return
	if _is_inventory_open or _is_reloading or _is_chambering or _is_dodging:
		_cancel_field_magazine_loading()
		return

	var per_round_time := maxf(field_magazine_load_time_per_round, 0.01)
	_field_magazine_load_elapsed += delta
	while _field_magazine_load_elapsed >= per_round_time:
		if not _refresh_field_magazine_load_entries():
			_cancel_field_magazine_loading()
			return

		if not bool(inventory.call(
			"load_round_into_magazine",
			_field_magazine_load_entry_id,
			inventory,
			_field_magazine_load_ammo_entry_id
		)):
			_cancel_field_magazine_loading()
			return

		_field_magazine_load_elapsed -= per_round_time
		if not _refresh_field_magazine_load_entries():
			_cancel_field_magazine_loading()
			return

	_emit_magazine_status_changed()


func _refresh_field_magazine_load_entries() -> bool:
	if inventory == null or magazine_item_id == &"" or ammo_item_id == &"":
		return false
	if not inventory.has_method("get_first_ammo_entry_id") or not inventory.has_method("get_first_loadable_magazine_entry_id"):
		return false

	var ammo_entry_id := int(inventory.call("get_first_ammo_entry_id", ammo_item_id))
	if ammo_entry_id < 0:
		return false

	var magazine_entry_id := int(inventory.call("get_first_loadable_magazine_entry_id", magazine_item_id, ammo_item_id))
	if magazine_entry_id < 0:
		return false

	if not inventory.has_method("can_load_round_into_magazine"):
		return false
	if not bool(inventory.call("can_load_round_into_magazine", magazine_entry_id, inventory, ammo_entry_id)):
		return false

	_field_magazine_load_entry_id = magazine_entry_id
	_field_magazine_load_ammo_entry_id = ammo_entry_id
	return true


func _cancel_field_magazine_loading() -> void:
	if not _is_field_magazine_loading and _field_magazine_load_entry_id < 0:
		return

	_is_field_magazine_loading = false
	_field_magazine_load_elapsed = 0.0
	_field_magazine_load_entry_id = -1
	_field_magazine_load_ammo_entry_id = -1
	_emit_magazine_status_changed()


func _get_field_magazine_load_progress() -> float:
	if not _is_field_magazine_loading:
		return 0.0

	var per_round_time := maxf(field_magazine_load_time_per_round, 0.01)
	return clampf(_field_magazine_load_elapsed / per_round_time, 0.0, 1.0)


func _emit_magazine_status_changed() -> void:
	magazine_status_changed.emit(
		get_active_magazine_statuses(),
		_field_magazine_load_entry_id if _is_field_magazine_loading else -1,
		_get_field_magazine_load_progress(),
		_is_field_magazine_loading
	)


func get_active_magazine_statuses() -> Array:
	if not _has_ranged_weapon:
		return []

	var statuses: Array = []
	if _has_active_magazine_inserted():
		statuses.append({
			"entry_id": ACTIVE_MAGAZINE_STATUS_ENTRY_ID,
			"item_id": magazine_item_id,
			"ammo_item_id": ammo_item_id,
			"ammo_name": _get_item_display_name(ammo_item_id),
			"ammo_count": magazine_ammo,
			"capacity": magazine_size,
			"is_checked": true,
			"is_active_magazine": true,
			"chamber_ammo": chamber_ammo,
			"total_loaded_ammo": current_ammo,
			"position": Vector2i(-1, -1),
		})

	if inventory != null and inventory.has_method("get_magazine_entries"):
		var inventory_magazines: Array = inventory.call("get_magazine_entries", magazine_item_id, ammo_item_id)
		for magazine in inventory_magazines:
			var normalized: Dictionary = magazine.duplicate(true)
			normalized["is_checked"] = true
			statuses.append(normalized)

	return statuses


func get_loaded_ammo_detail() -> Dictionary:
	if not _has_ranged_weapon:
		return {}

	return {
		"is_checked": true,
		"has_magazine": _has_active_magazine_inserted(),
		"magazine_ammo": magazine_ammo if _has_active_magazine_inserted() else 0,
		"magazine_capacity": magazine_size if _has_active_magazine_inserted() else 0,
		"chamber_ammo": chamber_ammo,
		"chamber_capacity": chamber_size,
		"total_loaded_ammo": current_ammo,
		"ammo_item_id": ammo_item_id,
		"ammo_name": _get_item_display_name(ammo_item_id),
	}


func get_firearm_hud_info() -> Dictionary:
	if not _has_ranged_weapon:
		return {
			"weapon_name": "No Firearm",
			"current_loaded_ammo": 0,
			"magazine_count": 0,
			"loose_ammo_count": 0,
		}

	return {
		"weapon_name": _get_active_firearm_display_name(),
		"current_loaded_ammo": current_ammo,
		"magazine_count": get_active_magazine_statuses().size(),
		"loose_ammo_count": _get_loose_ammo_count(),
	}


func get_firearm_aim_info() -> Dictionary:
	return {
		"visible": _has_ranged_weapon and not _is_inventory_open and not _is_dead,
		"target_position": get_global_mouse_position(),
		"actual_aim_position": _actual_aim_position,
		"spread_radius": _get_aim_indicator_radius(),
	}


func get_field_magazine_loading_entry_id() -> int:
	return _field_magazine_load_entry_id if _is_field_magazine_loading else -1


func get_field_magazine_loading_progress() -> float:
	return _get_field_magazine_load_progress()


func is_field_magazine_loading() -> bool:
	return _is_field_magazine_loading


func _update_aim(delta: float) -> void:
	if _is_dodging or _melee_state != MeleeState.READY:
		return

	var mouse_position: Vector2 = get_global_mouse_position()
	_desired_aim_position = _get_blocked_aim_position(mouse_position)
	if not _aim_initialized:
		_actual_aim_position = _desired_aim_position
		_aim_initialized = true
	else:
		var follow_weight := 1.0 - exp(-maxf(aim_follow_speed, 0.01) * delta)
		_actual_aim_position = _actual_aim_position.lerp(_desired_aim_position, clampf(follow_weight, 0.0, 1.0))

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

	var aim_vector: Vector2 = _actual_aim_position - arm_rig.global_position
	if aim_vector.length_squared() <= 0.01:
		return

	arm_rig.global_rotation = aim_vector.angle()
	arm_rig.scale.y = -1.0 if _facing < 0 else 1.0

	_recoil = move_toward(_recoil, 0.0, recoil_recovery_speed * delta)
	forearm_bone.rotation = -_recoil * arm_rig.scale.y


func _get_blocked_aim_position(target_position: Vector2) -> Vector2:
	if arm_rig == null:
		return target_position
	if arm_rig.global_position.distance_squared_to(target_position) <= 0.01:
		return target_position

	var query := PhysicsRayQueryParameters2D.new()
	query.from = arm_rig.global_position
	query.to = target_position
	query.collision_mask = aim_blocker_mask
	query.exclude = [get_rid()]
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if hit.has("position"):
		return hit.get("position", target_position)

	return target_position


func _get_aim_indicator_radius() -> float:
	return aim_indicator_base_radius + _recoil * aim_indicator_recoil_radius


func _get_shot_direction() -> Vector2:
	var direction := (_actual_aim_position - muzzle.global_position).normalized()
	if direction.length_squared() <= 0.01:
		direction = muzzle.global_transform.x.normalized()
	if direction.length_squared() <= 0.01:
		direction = Vector2.RIGHT.rotated(arm_rig.global_rotation)

	var spread_angle := _recoil * shot_spread_angle_per_recoil
	if spread_angle > 0.001:
		direction = direction.rotated(randf_range(-spread_angle, spread_angle)).normalized()

	return direction


func _try_fire() -> void:
	if not _has_ranged_weapon:
		return

	if _is_reloading or _is_chambering or _fire_cooldown_remaining > 0.0:
		return

	if current_ammo <= 0:
		_start_reload()
		return
	if chamber_size > 0 and chamber_ammo <= 0:
		_start_chambering()
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
		var shot_direction := _get_shot_direction()

		projectile_2d.global_position = muzzle.global_position
		projectile_2d.global_rotation = shot_direction.angle()
		if projectile_2d.has_method("launch"):
			projectile_2d.call("launch", shot_direction)

	_consume_round()


func _start_reload() -> void:
	if not _has_ranged_weapon:
		return

	if _is_reloading or _is_chambering:
		return

	if _can_chamber_from_magazine():
		_start_chambering()
		return

	if _find_best_reload_magazine_entry_id() < 0:
		return

	_is_reloading = true
	_reload_remaining = reload_time
	reload_started.emit(reload_time)


func _finish_reload() -> void:
	_suppress_inventory_ammo_signal = true
	var next_magazine_entry_id := _find_best_reload_magazine_entry_id()
	if next_magazine_entry_id < 0:
		_suppress_inventory_ammo_signal = false
		_is_reloading = false
		_reload_remaining = 0.0
		_sync_reserve_ammo()
		return

	var next_magazine_entry: Dictionary = inventory.remove_entry(next_magazine_entry_id)
	if next_magazine_entry.is_empty():
		_suppress_inventory_ammo_signal = false
		_is_reloading = false
		_reload_remaining = 0.0
		_sync_reserve_ammo()
		return

	_store_or_drop_active_magazine()

	var next_metadata: Dictionary = next_magazine_entry.get("metadata", {})
	magazine_ammo = _get_magazine_rounds_from_metadata(next_metadata, next_magazine_entry.get("item_id", magazine_item_id))
	magazine_item_id = next_magazine_entry.get("item_id", magazine_item_id)
	_firearm_has_magazine_by_slot[_active_firearm_slot] = true
	_update_current_ammo_from_loaded_parts()
	_save_active_firearm_ammo()
	_suppress_inventory_ammo_signal = false
	_is_reloading = false
	_reload_remaining = 0.0
	_sync_reserve_ammo()
	_emit_magazine_status_changed()
	_start_chambering()


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
	if _is_dodging or _dodge_cooldown_remaining > 0.0:
		return

	if movement_mode != MovementMode.TOP_DOWN and not is_on_floor():
		return

	if _melee_state == MeleeState.STRIKE:
		return

	if _melee_state != MeleeState.READY:
		_cancel_melee_attack()

	_dodge_direction = _get_action_direction()
	_dodge_vector = _get_action_vector()
	_is_dodging = true
	_is_sub_weapon_aiming = false
	_sub_weapon_fire_was_pressed = false
	_dodge_timer = dodge_duration
	_dodge_cooldown_remaining = dodge_cooldown
	_afterimage_timer = 0.0
	_set_crouching(false)
	_set_sub_weapon_aim_visual(false)
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


func _get_action_vector() -> Vector2:
	if movement_mode != MovementMode.TOP_DOWN:
		return Vector2(float(_get_action_direction()), 0.0)

	var input_vector := _get_top_down_input_vector()
	if input_vector != Vector2.ZERO:
		return input_vector

	var mouse_vector := get_global_mouse_position() - global_position
	if mouse_vector.length_squared() > 0.01:
		return mouse_vector.normalized()

	return Vector2(float(_facing), 0.0)


func _get_top_down_input_vector() -> Vector2:
	var input_vector := Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up", "move_down")
	)
	if input_vector.length_squared() <= 0.01:
		return Vector2.ZERO

	return input_vector.normalized()


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
	if _is_dodging or not _has_melee_weapon:
		return

	if _melee_state == MeleeState.READY:
		if _melee_combo_reset_remaining <= 0.0:
			_melee_combo_step = 0
		_try_start_melee_attack()
	elif (_melee_state == MeleeState.STRIKE or _melee_state == MeleeState.RECOVERY) and _melee_combo_step < _get_melee_combo_count():
		_queued_melee_attack = true


func _update_sub_weapon_aiming() -> void:
	var should_aim := (
		Input.is_action_pressed("sub_weapon_aim")
		and _has_melee_weapon
		and not _is_dodging
		and _melee_state == MeleeState.READY
	)

	if should_aim:
		_set_melee_action_direction()

	if _is_sub_weapon_aiming == should_aim:
		if _is_sub_weapon_aiming:
			_set_sub_weapon_aim_visual(true)
		return

	_is_sub_weapon_aiming = should_aim
	_set_sub_weapon_aim_visual(_is_sub_weapon_aiming)


func _try_start_melee_attack() -> void:
	if movement_mode != MovementMode.TOP_DOWN and not is_on_floor():
		return

	if not _can_use_melee_stamina():
		stamina_use_failed.emit()
		return

	_current_melee_step = clampi(_melee_combo_step, 0, _get_melee_combo_count() - 1)
	_melee_combo_step = _current_melee_step + 1
	_melee_combo_reset_remaining = melee_combo_reset_time
	_queued_melee_attack = false
	_melee_hit_bodies.clear()
	_set_melee_action_direction()
	_set_crouching(false)
	_consume_stamina(melee_stamina_cost)
	_is_sub_weapon_aiming = false
	_set_sub_weapon_aim_visual(false)
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

	if _queued_melee_attack and _melee_combo_step < _get_melee_combo_count() and not is_stamina_overheated:
		_try_start_melee_attack()
		return

	_melee_state = MeleeState.READY
	_queued_melee_attack = false
	if _melee_combo_step >= _get_melee_combo_count():
		_melee_combo_step = 0
		_melee_combo_reset_remaining = 0.0


func _cancel_melee_attack() -> void:
	_melee_state = MeleeState.READY
	_melee_timer = 0.0
	_queued_melee_attack = false
	_melee_hit_bodies.clear()
	_set_melee_visual(false)


func _melee_has_enemy_contact() -> bool:
	if not melee_hit_area.monitoring:
		return false

	for body in melee_hit_area.get_overlapping_bodies():
		if body.get_node_or_null("Health") != null:
			return true
	return false


func _apply_melee_damage() -> void:
	if not melee_hit_area.monitoring:
		return

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
			body.call("apply_hit_reaction", _melee_vector, damage, hit_position)
		health_node.apply_damage(damage)


func _get_melee_damage() -> int:
	if _melee_combo_damages.is_empty():
		return 0

	var index: int = clampi(_current_melee_step, 0, _melee_combo_damages.size() - 1)
	return _melee_combo_damages[index]


func _get_melee_combo_count() -> int:
	return maxi(_melee_combo_damages.size(), 1)


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
	return _has_melee_weapon and not is_stamina_overheated and current_stamina >= melee_min_stamina_to_use


func _set_melee_action_direction() -> void:
	_melee_vector = _get_action_vector()
	if absf(_melee_vector.x) > 0.01:
		_melee_direction = int(signf(_melee_vector.x))
		_set_facing(_melee_direction)
	elif movement_mode != MovementMode.TOP_DOWN:
		_set_facing(_melee_direction)

	_apply_melee_visual_transform()


func _apply_melee_visual_transform() -> void:
	if movement_mode == MovementMode.TOP_DOWN:
		melee_root.rotation = _melee_vector.angle()
		melee_root.scale = Vector2.ONE
		return

	melee_root.rotation = 0.0
	melee_root.scale = Vector2(float(_melee_direction), 1.0)


func _set_melee_visual(visible: bool) -> void:
	melee_root.visible = visible
	melee_hit_area.monitoring = visible
	_apply_melee_visual_transform()
	melee_slash_visual.visible = visible
	if visible:
		melee_slash_visual.color = Color(0.72, 0.62, 0.42, 0.45)


func _set_sub_weapon_aim_visual(visible: bool) -> void:
	if visible and _melee_state != MeleeState.READY:
		return

	melee_root.visible = visible
	melee_hit_area.monitoring = false
	_apply_melee_visual_transform()
	melee_slash_visual.visible = visible
	melee_slash_visual.color = Color(0.72, 0.72, 0.62, 0.28)


func _set_ranged_visual(visible: bool) -> void:
	gun_root.visible = visible


func set_inventory_open(is_open: bool) -> void:
	if _is_inventory_open == is_open:
		return

	_is_inventory_open = is_open
	if _is_inventory_open:
		_is_sub_weapon_aiming = false
		_sub_weapon_fire_was_pressed = false
		_is_reloading = false
		_reload_remaining = 0.0
		_cancel_chambering()
		_cancel_field_magazine_loading()
		_set_sub_weapon_aim_visual(false)
		if _melee_state != MeleeState.READY:
			_cancel_melee_attack()
		_set_inventory_pose(true)
	else:
		_set_inventory_pose(false)


func is_inventory_open() -> bool:
	return _is_inventory_open


func _set_inventory_pose(is_enabled: bool) -> void:
	if is_enabled:
		_body_rotation_before_inventory = body_root.rotation
		_arm_rig_was_visible_before_inventory = arm_rig.visible
		body_root.rotation_degrees = inventory_pose_tilt_degrees * float(_facing)
		arm_rig.visible = false
		melee_root.visible = false
		return

	body_root.rotation = _body_rotation_before_inventory
	if not _is_dead:
		arm_rig.visible = _arm_rig_was_visible_before_inventory


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
	if chamber_size > 0 and chamber_ammo > 0:
		chamber_ammo -= 1
	elif chamber_size <= 0 and magazine_ammo > 0:
		magazine_ammo -= 1
	else:
		_update_current_ammo_from_loaded_parts()
		return

	_feed_chamber_if_empty()
	_update_current_ammo_from_loaded_parts()
	_save_active_firearm_ammo()
	_fire_cooldown_remaining = fire_cooldown
	_recoil = minf(_recoil + recoil_amount, recoil_max_amount)
	fired.emit(current_ammo)
	ammo_changed.emit(current_ammo, reserve_ammo)
	_emit_magazine_status_changed()


func _update_current_ammo_from_loaded_parts() -> void:
	chamber_ammo = clampi(chamber_ammo, 0, chamber_size)
	magazine_ammo = clampi(magazine_ammo, 0, magazine_size)
	current_ammo = chamber_ammo + magazine_ammo


func _feed_chamber_if_empty() -> void:
	if chamber_size <= 0 or chamber_ammo > 0 or magazine_ammo <= 0:
		return

	chamber_ammo = 1
	magazine_ammo -= 1


func _can_chamber_from_magazine() -> bool:
	return (
		_has_ranged_weapon
		and chamber_size > 0
		and chamber_ammo <= 0
		and magazine_ammo > 0
		and _has_active_magazine_inserted()
	)


func _start_chambering() -> bool:
	if not _can_chamber_from_magazine():
		return false

	if chamber_feed_time <= 0.0:
		_finish_chambering()
		return true

	_is_chambering = true
	_chambering_remaining = chamber_feed_time
	chambering_started.emit(chamber_feed_time)
	return true


func _finish_chambering() -> void:
	_is_chambering = false
	_chambering_remaining = 0.0
	if _can_chamber_from_magazine():
		_feed_chamber_if_empty()
	_commit_loaded_ammo_change()


func _cancel_chambering() -> void:
	_is_chambering = false
	_chambering_remaining = 0.0


func _has_active_magazine_inserted() -> bool:
	return bool(_firearm_has_magazine_by_slot.get(_active_firearm_slot, magazine_size > 0))


func has_active_magazine_inserted() -> bool:
	return _has_active_magazine_inserted()


func is_loaded_ammo_checked() -> bool:
	return _has_ranged_weapon


func get_current_ammo_display() -> String:
	if not _has_ranged_weapon:
		return "--"
	return str(current_ammo)


func get_reserve_ammo_display() -> String:
	if not _has_ranged_weapon or inventory == null or magazine_item_id == &"":
		return "--"

	if not inventory.has_method("get_magazine_entries"):
		return str(reserve_ammo)

	var magazines: Array = inventory.call("get_magazine_entries", magazine_item_id, ammo_item_id)
	if magazines.is_empty():
		return "0"

	return str(reserve_ammo)


func get_ammo_display_pair() -> Dictionary:
	return {
		"current": get_current_ammo_display(),
		"reserve": get_reserve_ammo_display(),
	}


func get_active_magazine_item_id() -> StringName:
	return magazine_item_id


func get_active_magazine_metadata() -> Dictionary:
	if not _has_active_magazine_inserted():
		return {}

	return _make_magazine_metadata(magazine_ammo, is_loaded_ammo_checked())


func can_insert_active_magazine(item_id: StringName, _metadata: Dictionary = {}) -> bool:
	return _has_ranged_weapon and item_id != &"" and item_id == magazine_item_id


func insert_active_magazine(item_id: StringName, metadata: Dictionary = {}) -> bool:
	if not can_insert_active_magazine(item_id, metadata):
		return false

	_cancel_chambering()
	magazine_ammo = _get_magazine_rounds_from_metadata(metadata, item_id)
	magazine_item_id = item_id
	_firearm_has_magazine_by_slot[_active_firearm_slot] = true
	_commit_loaded_ammo_change()
	return true


func eject_active_magazine() -> Dictionary:
	if not _has_active_magazine_inserted():
		return {}

	_cancel_chambering()
	var ejected := {
		"item_id": magazine_item_id,
		"metadata": _make_magazine_metadata(magazine_ammo, is_loaded_ammo_checked()),
	}
	magazine_ammo = 0
	_firearm_has_magazine_by_slot[_active_firearm_slot] = false
	_commit_loaded_ammo_change()
	return ejected


func can_insert_chamber_round(item_id: StringName) -> bool:
	return _has_ranged_weapon and chamber_size > 0 and chamber_ammo < chamber_size and item_id == ammo_item_id


func insert_chamber_round(item_id: StringName) -> bool:
	if not can_insert_chamber_round(item_id):
		return false

	_cancel_chambering()
	chamber_ammo += 1
	_commit_loaded_ammo_change()
	return true


func eject_chamber_round() -> Dictionary:
	if not _has_ranged_weapon or chamber_ammo <= 0 or ammo_item_id == &"":
		return {}

	_cancel_chambering()
	chamber_ammo -= 1
	var ejected := {
		"item_id": ammo_item_id,
		"quantity": 1,
	}
	_commit_loaded_ammo_change()
	return ejected


func _commit_loaded_ammo_change() -> void:
	_update_current_ammo_from_loaded_parts()
	_save_active_firearm_ammo()
	_sync_reserve_ammo(false)
	ammo_changed.emit(current_ammo, reserve_ammo)
	_emit_magazine_status_changed()


func _find_best_reload_magazine_entry_id() -> int:
	if inventory == null or magazine_item_id == &"":
		return -1

	var best_entry_id := -1
	var best_rounds := -1
	for entry in inventory.get_entries():
		if entry.get("item_id", &"") != magazine_item_id:
			continue

		var rounds := _get_magazine_rounds_from_entry(entry)
		if rounds <= 0:
			continue
		if rounds > best_rounds:
			best_rounds = rounds
			best_entry_id = int(entry.get("entry_id", -1))

	return best_entry_id


func _get_magazine_rounds_from_entry(entry: Dictionary) -> int:
	return _get_magazine_rounds_from_metadata(entry.get("metadata", {}), entry.get("item_id", magazine_item_id))


func _get_magazine_rounds_from_metadata(metadata: Dictionary, item_id: StringName) -> int:
	var definition: Dictionary = inventory.get_item_definition(item_id) if inventory != null else {}
	var capacity := int(definition.get("magazine_capacity", magazine_size))
	if metadata.has("capacity"):
		capacity = int(metadata.get("capacity", capacity))

	var rounds := capacity
	if metadata.has("ammo_count"):
		rounds = int(metadata.get("ammo_count", 0))

	return clampi(rounds, 0, capacity)


func _make_magazine_metadata(rounds: int, is_checked: bool = true) -> Dictionary:
	return {
		"ammo_count": clampi(rounds, 0, magazine_size),
		"capacity": magazine_size,
		"ammo_item_id": ammo_item_id,
		"is_checked": is_checked,
	}


func _get_item_display_name(item_id: StringName) -> String:
	if item_id == &"":
		return ""
	if inventory != null and inventory.has_method("get_item_definition"):
		var definition: Dictionary = inventory.call("get_item_definition", item_id)
		return str(definition.get("name", item_id))
	return str(item_id)


func _store_or_drop_active_magazine() -> void:
	if not _has_active_magazine_inserted() or magazine_item_id == &"":
		return

	var metadata := _make_magazine_metadata(magazine_ammo, is_loaded_ammo_checked())
	if inventory != null and inventory.has_method("add_item_with_metadata"):
		if bool(inventory.call("add_item_with_metadata", magazine_item_id, metadata)):
			return

	_drop_item_to_world(magazine_item_id, 1, metadata)


func _drop_item_to_world(item_id: StringName, quantity: int = 1, metadata: Dictionary = {}) -> bool:
	if item_id == &"":
		return false

	var dropped_item := DROPPED_ITEM_SCENE.instantiate()
	dropped_item.set("item_id", item_id)
	dropped_item.set("quantity", quantity)
	dropped_item.set("metadata", metadata)

	var drop_parent: Node = get_tree().current_scene
	if drop_parent == null:
		drop_parent = get_parent()
	drop_parent.add_child(dropped_item)

	if dropped_item is Node2D:
		var dropped_item_2d := dropped_item as Node2D
		dropped_item_2d.global_position = global_position + Vector2(28, -10)

	return true


func _ensure_starting_ammo_supplies() -> void:
	if inventory == null or not _has_ranged_weapon:
		return

	if ammo_item_id != &"" and inventory.get_quantity(ammo_item_id) <= 0 and starting_reserve_ammo > 0:
		inventory.add_item(ammo_item_id, starting_reserve_ammo)

	if magazine_item_id == &"" or starting_spare_magazines <= 0:
		return
	if inventory.get_quantity(magazine_item_id) > 0:
		return

	for _index in range(starting_spare_magazines):
		if not _add_magazine_to_inventory(magazine_size):
			break


func _add_magazine_to_inventory(rounds: int) -> bool:
	if inventory == null or magazine_item_id == &"":
		return false
	if not inventory.has_method("add_item_with_metadata"):
		return false

	return bool(inventory.call("add_item_with_metadata", magazine_item_id, _make_magazine_metadata(rounds)))


func _sync_reserve_ammo(should_emit: bool = true) -> void:
	reserve_ammo = _get_inventory_magazine_rounds() if _has_ranged_weapon else 0
	if should_emit:
		ammo_changed.emit(current_ammo, reserve_ammo)


func _get_inventory_magazine_rounds() -> int:
	if inventory == null or magazine_item_id == &"":
		return 0

	var total_rounds := 0
	for entry in inventory.get_entries():
		if entry.get("item_id", &"") == magazine_item_id:
			total_rounds += _get_magazine_rounds_from_entry(entry)

	return total_rounds


func _get_loose_ammo_count() -> int:
	if inventory == null or ammo_item_id == &"":
		return 0
	if not inventory.has_method("get_quantity"):
		return 0

	return int(inventory.call("get_quantity", ammo_item_id))


func _on_inventory_item_quantity_changed(item_id: StringName, _quantity: int) -> void:
	if item_id != ammo_item_id and item_id != magazine_item_id:
		return

	_sync_reserve_ammo(not _suppress_inventory_ammo_signal)
	_emit_magazine_status_changed()


func _on_inventory_grid_changed() -> void:
	_sync_reserve_ammo(not _suppress_inventory_ammo_signal)
	_emit_magazine_status_changed()


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
	_refresh_nearby_interactables()

	var nearest: Node2D = _get_preferred_interactable()

	if nearest != null and nearest.has_method("interact"):
		nearest.call("interact", self)


func _refresh_nearby_interactables() -> void:
	_nearby_interactables = _nearby_interactables.filter(func(interactable: Node2D) -> bool:
		return is_instance_valid(interactable)
	)
	for area in interaction_area.get_overlapping_areas():
		if area.has_method("interact") and area not in _nearby_interactables:
			_nearby_interactables.append(area)


func _on_interaction_area_entered(area: Area2D) -> void:
	if area.has_method("interact") and area not in _nearby_interactables:
		_nearby_interactables.append(area)


func _on_interaction_area_exited(area: Area2D) -> void:
	_nearby_interactables.erase(area)
	_set_interactable_highlight(area, false)
	_highlighted_interactables.erase(area)


func _get_preferred_interactable() -> Node2D:
	return _get_preferred_interactable_at(get_global_mouse_position())


func _get_preferred_interactable_at(mouse_position: Vector2) -> Node2D:
	var hovered: Node2D = _get_hovered_interactable_at(mouse_position)
	if hovered != null:
		return hovered

	var nearest: Node2D = null
	var nearest_distance_squared: float = INF
	for interactable in _nearby_interactables:
		if not is_instance_valid(interactable):
			continue

		var distance_squared: float = global_position.distance_squared_to(interactable.global_position)
		if distance_squared < nearest_distance_squared:
			nearest = interactable
			nearest_distance_squared = distance_squared

	return nearest


func _get_hovered_interactable() -> Node2D:
	return _get_hovered_interactable_at(get_global_mouse_position())


func _get_hovered_interactable_at(mouse_position: Vector2) -> Node2D:
	var hovered: Node2D = null
	var hovered_distance_squared: float = INF
	for interactable in _nearby_interactables:
		if not is_instance_valid(interactable):
			continue
		if not _is_mouse_over_interactable(interactable, mouse_position):
			continue

		var distance_squared := mouse_position.distance_squared_to(interactable.global_position)
		if distance_squared < hovered_distance_squared:
			hovered = interactable
			hovered_distance_squared = distance_squared

	return hovered


func _update_interaction_highlights() -> void:
	_refresh_nearby_interactables()

	var hovered := _get_hovered_interactable_at(get_global_mouse_position())
	var active_interactables: Array[Node2D] = []
	if not _is_inventory_open:
		for interactable in _nearby_interactables:
			if is_instance_valid(interactable):
				active_interactables.append(interactable)

	for interactable in _highlighted_interactables.duplicate():
		if not is_instance_valid(interactable) or interactable not in active_interactables:
			if is_instance_valid(interactable):
				_set_interactable_highlight(interactable, false)
			_highlighted_interactables.erase(interactable)

	for interactable in active_interactables:
		_set_interactable_highlight(interactable, true, interactable == hovered)
		if interactable not in _highlighted_interactables:
			_highlighted_interactables.append(interactable)


func _is_mouse_over_interactable(interactable: Node2D, mouse_position: Vector2) -> bool:
	if interactable == null or not is_instance_valid(interactable):
		return false

	for child in interactable.get_children():
		var collision_shape := child as CollisionShape2D
		if collision_shape == null or collision_shape.disabled or collision_shape.shape == null:
			continue
		if _is_point_inside_collision_shape(collision_shape, mouse_position):
			return true

	return false


func _is_point_inside_collision_shape(collision_shape: CollisionShape2D, global_point: Vector2) -> bool:
	var local_point: Vector2 = collision_shape.global_transform.affine_inverse() * global_point
	var shape := collision_shape.shape
	if shape is RectangleShape2D:
		var rectangle := shape as RectangleShape2D
		var half_size := rectangle.size * 0.5
		return absf(local_point.x) <= half_size.x and absf(local_point.y) <= half_size.y
	if shape is CircleShape2D:
		var circle := shape as CircleShape2D
		return local_point.length_squared() <= circle.radius * circle.radius

	return false


func _set_interactable_highlight(interactable: Node2D, is_visible: bool, _is_hovered: bool = false) -> void:
	if interactable == null or not is_instance_valid(interactable):
		return

	var highlight := interactable.get_node_or_null(INTERACTION_HIGHLIGHT_NAME) as Line2D
	if highlight == null and is_visible:
		highlight = _create_interaction_highlight(interactable)
		if highlight != null:
			interactable.add_child(highlight)
	if highlight == null:
		return

	highlight.visible = is_visible
	highlight.width = 2.0
	highlight.default_color = Color(1.0, 1.0, 1.0, 0.78)


func _create_interaction_highlight(interactable: Node2D) -> Line2D:
	var points := _get_interactable_outline_points(interactable)
	if points.is_empty():
		return null

	var highlight := Line2D.new()
	highlight.name = INTERACTION_HIGHLIGHT_NAME
	highlight.z_index = 50
	highlight.closed = true
	highlight.joint_mode = Line2D.LINE_JOINT_SHARP
	highlight.begin_cap_mode = Line2D.LINE_CAP_NONE
	highlight.end_cap_mode = Line2D.LINE_CAP_NONE
	highlight.points = points
	highlight.visible = false
	return highlight


func _get_interactable_outline_points(interactable: Node2D) -> PackedVector2Array:
	var visual_points := _get_interactable_visual_outline_points(interactable)
	if not visual_points.is_empty():
		return visual_points

	for child in interactable.get_children():
		var collision_shape := child as CollisionShape2D
		if collision_shape == null or collision_shape.shape == null:
			continue
		if collision_shape.shape is RectangleShape2D:
			var rectangle := collision_shape.shape as RectangleShape2D
			var half_size := rectangle.size * 0.5 + Vector2(4.0, 4.0)
			return PackedVector2Array([
				collision_shape.transform * Vector2(-half_size.x, -half_size.y),
				collision_shape.transform * Vector2(half_size.x, -half_size.y),
				collision_shape.transform * Vector2(half_size.x, half_size.y),
				collision_shape.transform * Vector2(-half_size.x, half_size.y),
			])
		if collision_shape.shape is CircleShape2D:
			var circle := collision_shape.shape as CircleShape2D
			var radius := circle.radius + 4.0
			var points := PackedVector2Array()
			for index in 24:
				var angle := TAU * float(index) / 24.0
				points.append(collision_shape.transform * (Vector2(cos(angle), sin(angle)) * radius))
			return points

	return PackedVector2Array()


func _get_interactable_visual_outline_points(interactable: Node2D) -> PackedVector2Array:
	var points: Array[Vector2] = []
	_collect_interactable_polygon_points(interactable, interactable, points)
	if points.size() < 3:
		return PackedVector2Array()

	return PackedVector2Array(_get_convex_hull(points))


func _collect_interactable_polygon_points(root_node: Node2D, current: Node, points: Array[Vector2]) -> void:
	for child in current.get_children():
		if child.name == INTERACTION_HIGHLIGHT_NAME:
			continue

		var polygon_node := child as Polygon2D
		if polygon_node != null and polygon_node.visible:
			for point in polygon_node.polygon:
				var global_point: Vector2 = polygon_node.global_transform * point
				points.append(root_node.global_transform.affine_inverse() * global_point)

		if child is Node2D:
			_collect_interactable_polygon_points(root_node, child, points)


func _get_convex_hull(points: Array[Vector2]) -> Array[Vector2]:
	var sorted_points := points.duplicate()
	sorted_points.sort_custom(func(a: Vector2, b: Vector2) -> bool:
		if is_equal_approx(a.x, b.x):
			return a.y < b.y
		return a.x < b.x
	)

	var unique_points: Array[Vector2] = []
	for point in sorted_points:
		if unique_points.is_empty() or point.distance_squared_to(unique_points.back()) > 0.01:
			unique_points.append(point)
	if unique_points.size() < 3:
		return unique_points

	var lower: Array[Vector2] = []
	for point in unique_points:
		while lower.size() >= 2 and _cross(lower[lower.size() - 2], lower[lower.size() - 1], point) <= 0.0:
			lower.pop_back()
		lower.append(point)

	var upper: Array[Vector2] = []
	for index in range(unique_points.size() - 1, -1, -1):
		var point := unique_points[index]
		while upper.size() >= 2 and _cross(upper[upper.size() - 2], upper[upper.size() - 1], point) <= 0.0:
			upper.pop_back()
		upper.append(point)

	lower.pop_back()
	upper.pop_back()
	lower.append_array(upper)
	return lower


func _cross(origin: Vector2, a: Vector2, b: Vector2) -> float:
	return (a - origin).cross(b - origin)


func _on_died() -> void:
	_is_dead = true
	_is_inventory_open = false
	_is_sub_weapon_aiming = false
	_sub_weapon_fire_was_pressed = false
	velocity = Vector2.ZERO
	_set_inventory_pose(false)
	body_root.modulate = Color(0.35, 0.35, 0.35, 1.0)
	_set_sub_weapon_aim_visual(false)
	arm_rig.visible = false
	died.emit()


func apply_damage_reaction(direction: Vector2, _damage: int, _source_position: Vector2) -> void:
	if health.has_method("is_damage_blocked") and health.call("is_damage_blocked"):
		return

	var knockback_direction := direction.normalized()
	if knockback_direction == Vector2.ZERO:
		knockback_direction = Vector2.RIGHT
	_pending_damage_direction = knockback_direction

	if movement_mode == MovementMode.TOP_DOWN:
		_damage_knockback_velocity = knockback_direction * damage_knockback_strength
		return

	_damage_knockback_velocity.x = knockback_direction.x * damage_knockback_strength
	if is_on_floor():
		velocity.y = damage_knockback_lift


func _on_damaged(_amount: int, _current_health: int, _max_health: int) -> void:
	if _is_dead:
		return

	damage_feedback.emit(_pending_damage_direction)
	_pending_damage_direction = Vector2.ZERO
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
