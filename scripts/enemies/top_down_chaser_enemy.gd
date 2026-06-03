extends TopDownEnemyBase
class_name TopDownChaserEnemy

enum AttackState {
	CHASE,
	WINDUP,
	ACTIVE,
	RECOVERY,
}

@export var initial_facing_direction: Vector2 = Vector2.LEFT
@export var attack_damage: int = 16
@export var attack_range: float = 44.0
@export var desired_target_separation: float = 34.0
@export var attack_windup_time: float = 0.28
@export var attack_active_time: float = 0.16
@export var attack_recovery_time: float = 0.55
@export var attack_lunge_speed: float = 180.0

@onready var damage_area: Area2D = get_node_or_null("DamageArea") as Area2D

var _attack_state: AttackState = AttackState.CHASE
var _attack_timer: float = 0.0
var _attack_direction: Vector2 = Vector2.RIGHT
var _has_hit_this_attack: bool = false


func _enemy_ready() -> void:
	_set_facing(initial_facing_direction)


func _enemy_physics_update(delta: float) -> void:
	_update_attack_state(delta)
	if _attack_state == AttackState.WINDUP:
		_pulse_windup()
		return

	if _attack_state == AttackState.RECOVERY:
		return

	if _attack_state == AttackState.ACTIVE:
		add_desired_velocity(_attack_direction * attack_lunge_speed)
		_try_apply_attack_damage()
		return

	if not has_known_target():
		return

	var target_position := get_target_or_memory_position()
	var target_distance := global_position.distance_to(target_position)
	if is_searching_at_memory():
		return
	if target_distance > desired_target_separation:
		move_toward_position(target_position, move_speed, desired_target_separation)


func _update_attack_state(delta: float) -> void:
	match _attack_state:
		AttackState.CHASE:
			_try_start_attack()
		AttackState.WINDUP:
			_attack_timer -= delta
			if _attack_timer <= 0.0:
				_enter_active_attack()
		AttackState.ACTIVE:
			_attack_timer -= delta
			if _attack_timer <= 0.0:
				_enter_recovery()
		AttackState.RECOVERY:
			_attack_timer -= delta
			if _attack_timer <= 0.0:
				_enter_chase()


func _try_start_attack() -> void:
	if not is_target_confirmed_visible():
		return

	var to_target := _target.global_position - global_position
	if to_target.length() > attack_range:
		return

	_attack_direction = to_target.normalized()
	if _attack_direction.length_squared() <= 0.01:
		_attack_direction = get_facing_direction()
	_enter_windup()


func _enter_windup() -> void:
	_attack_state = AttackState.WINDUP
	_attack_timer = attack_windup_time
	_has_hit_this_attack = false


func _enter_active_attack() -> void:
	_attack_state = AttackState.ACTIVE
	_attack_timer = attack_active_time
	_has_hit_this_attack = false


func _enter_recovery() -> void:
	_attack_state = AttackState.RECOVERY
	_attack_timer = attack_recovery_time
	if body_visual != null:
		body_visual.color = _base_body_color
	if eye_visual != null:
		eye_visual.color = _base_eye_color


func _enter_chase() -> void:
	_attack_state = AttackState.CHASE
	_attack_timer = 0.0
	_has_hit_this_attack = false


func _try_apply_attack_damage() -> void:
	if _has_hit_this_attack or damage_area == null:
		return

	for body in damage_area.get_overlapping_bodies():
		if body == self:
			continue
		var target_health := _find_health(body)
		if target_health == null:
			continue

		var attack_direction := (body.global_position - global_position).normalized() if body is Node2D else _attack_direction
		if body.has_method("apply_damage_reaction"):
			body.call("apply_damage_reaction", attack_direction, attack_damage, global_position)
		if target_health.has_method("apply_damage"):
			target_health.call("apply_damage", attack_damage)
		_has_hit_this_attack = true
		return


func _find_health(node: Node) -> Node:
	if node == null:
		return null
	return node.get_node_or_null("Health")


func _pulse_windup() -> void:
	if body_visual == null:
		return
	var pulse := 0.78 + sin(Time.get_ticks_msec() * 0.024) * 0.22
	body_visual.color = _base_body_color.lerp(Color(0.92, 0.12, 0.08, 1.0), pulse)
	if eye_visual != null:
		eye_visual.color = _base_eye_color.lerp(Color.WHITE, pulse)
