extends CharacterBody2D
class_name ApproachEnemy

enum AttackState {
	CHASE,
	WINDUP,
	ACTIVE,
	RECOVERY,
}

@export var move_speed: float = 42.0
@export var attack_damage: int = 18
@export var attack_range: float = 30.0
@export var attack_windup_time: float = 0.35
@export var attack_active_time: float = 0.12
@export var attack_recovery_time: float = 0.62
@export var attack_lunge_speed: float = 92.0
@export var hit_vfx_scene: PackedScene
@export var death_vfx_scene: PackedScene
@export var knockback_strength: float = 115.0
@export var knockback_recovery: float = 420.0
@export var hit_flash_time: float = 0.08

@onready var health: Node = $Health
@onready var body_visual: Polygon2D = $BodyVisual
@onready var eye_visual: Polygon2D = $BodyVisual/Eye
@onready var damage_area: Area2D = $DamageArea

var _gravity: float = 980.0
var _target: Node2D
var _overlapping_bodies: Array[Node] = []
var _is_dead: bool = false
var _knockback_velocity: Vector2 = Vector2.ZERO
var _base_body_color: Color
var _base_eye_color: Color
var _flash_tween: Tween
var _attack_state: AttackState = AttackState.CHASE
var _attack_timer: float = 0.0
var _attack_direction: float = 1.0
var _has_hit_this_attack: bool = false


func _ready() -> void:
	if ProjectSettings.has_setting("physics/2d/default_gravity"):
		_gravity = float(ProjectSettings.get_setting("physics/2d/default_gravity"))

	_base_body_color = body_visual.color
	_base_eye_color = eye_visual.color
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)
	damage_area.body_entered.connect(_on_damage_area_body_entered)
	damage_area.body_exited.connect(_on_damage_area_body_exited)


func set_target(target: Node2D) -> void:
	_target = target


func _physics_process(delta: float) -> void:
	if _is_dead:
		return

	_update_attack_state(delta)

	if not is_on_floor():
		velocity.y += _gravity * delta
	elif velocity.y > 0.0:
		velocity.y = 0.0

	velocity.x = _knockback_velocity.x
	if _target != null and _attack_state == AttackState.CHASE:
		var direction_x: float = signf(_target.global_position.x - global_position.x)
		velocity.x += direction_x * move_speed
		if absf(direction_x) > 0.0:
			_set_facing(direction_x)
	elif _attack_state == AttackState.WINDUP:
		velocity.x = _knockback_velocity.x
	elif _attack_state == AttackState.ACTIVE:
		velocity.x += _attack_direction * attack_lunge_speed
	else:
		velocity.x = _knockback_velocity.x

	_knockback_velocity = _knockback_velocity.move_toward(Vector2.ZERO, knockback_recovery * delta)
	move_and_slide()


func apply_hit_reaction(direction: Vector2, _damage: int, hit_position: Vector2) -> void:
	var knockback_direction := direction.normalized()
	if knockback_direction == Vector2.ZERO:
		knockback_direction = Vector2.RIGHT
	_knockback_velocity = knockback_direction * knockback_strength
	_spawn_vfx(hit_vfx_scene, hit_position)
	_flash()


func _find_health(node: Node) -> Node:
	if node == null:
		return null

	return node.get_node_or_null("Health")


func _update_attack_state(delta: float) -> void:
	match _attack_state:
		AttackState.CHASE:
			_try_start_attack()
		AttackState.WINDUP:
			_attack_timer -= delta
			_pulse_windup()
			if _attack_timer <= 0.0:
				_enter_active_attack()
		AttackState.ACTIVE:
			_attack_timer -= delta
			_try_apply_attack_damage()
			if _attack_timer <= 0.0:
				_enter_recovery()
		AttackState.RECOVERY:
			_attack_timer -= delta
			if _attack_timer <= 0.0:
				_enter_chase()


func _try_start_attack() -> void:
	if _target == null:
		return

	var distance_x: float = _target.global_position.x - global_position.x
	var distance_y: float = absf(_target.global_position.y - global_position.y)
	if absf(distance_x) > attack_range or distance_y > 36.0:
		return

	_attack_direction = signf(distance_x)
	if _attack_direction == 0.0:
		_attack_direction = body_visual.scale.x
	_set_facing(_attack_direction)
	_attack_state = AttackState.WINDUP
	_attack_timer = attack_windup_time
	_has_hit_this_attack = false
	body_visual.scale = Vector2(_attack_direction * 1.08, 0.92)
	body_visual.color = Color(0.35, 0.32, 0.19, 1.0)


func _enter_active_attack() -> void:
	_attack_state = AttackState.ACTIVE
	_attack_timer = attack_active_time
	_has_hit_this_attack = false
	body_visual.scale = Vector2(_attack_direction * 1.16, 1.04)
	body_visual.color = Color(0.55, 0.12, 0.1, 1.0)
	_try_apply_attack_damage()


func _enter_recovery() -> void:
	_attack_state = AttackState.RECOVERY
	_attack_timer = attack_recovery_time
	body_visual.scale = Vector2(_attack_direction * 0.96, 1.0)
	body_visual.color = _base_body_color


func _enter_chase() -> void:
	_attack_state = AttackState.CHASE
	_attack_timer = 0.0
	_has_hit_this_attack = false
	_set_facing(_attack_direction)
	body_visual.color = _base_body_color
	eye_visual.color = _base_eye_color


func _try_apply_attack_damage() -> void:
	if _has_hit_this_attack:
		return

	for body in _overlapping_bodies:
		var health_node: Node = _find_health(body)
		if health_node == null:
			continue

		if body.has_method("apply_damage_reaction"):
			body.call("apply_damage_reaction", Vector2(_attack_direction, 0.0), attack_damage, global_position)
		health_node.apply_damage(attack_damage)
		_has_hit_this_attack = true
		return


func _pulse_windup() -> void:
	var pulse_strength := 0.08 + sin(Time.get_ticks_msec() * 0.03) * 0.03
	eye_visual.color = Color(1.0, 0.14 + pulse_strength, 0.12, 1.0)


func _set_facing(direction_x: float) -> void:
	if direction_x == 0.0:
		return
	body_visual.scale.x = signf(direction_x)


func _on_damage_area_body_entered(body: Node) -> void:
	if body not in _overlapping_bodies:
		_overlapping_bodies.append(body)


func _on_damage_area_body_exited(body: Node) -> void:
	_overlapping_bodies.erase(body)


func _on_damaged(_amount: int, _current_health: int, _max_health: int) -> void:
	_flash()


func _on_died() -> void:
	_is_dead = true
	collision_layer = 0
	collision_mask = 0
	damage_area.monitoring = false
	_spawn_vfx(death_vfx_scene, global_position + Vector2(0, -20))
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
