extends CharacterBody2D
class_name ApproachEnemy

@export var move_speed: float = 42.0
@export var contact_damage: int = 8
@export var contact_interval: float = 0.9
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
var _damage_cooldown: float = 0.0
var _overlapping_bodies: Array[Node] = []
var _is_dead: bool = false
var _knockback_velocity: Vector2 = Vector2.ZERO
var _base_body_color: Color
var _base_eye_color: Color
var _flash_tween: Tween


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

	_update_contact_damage(delta)

	if not is_on_floor():
		velocity.y += _gravity * delta
	elif velocity.y > 0.0:
		velocity.y = 0.0

	velocity.x = _knockback_velocity.x
	if _target != null:
		var direction_x: float = signf(_target.global_position.x - global_position.x)
		velocity.x += direction_x * move_speed
		if absf(direction_x) > 0.0:
			body_visual.scale.x = direction_x

	_knockback_velocity = _knockback_velocity.move_toward(Vector2.ZERO, knockback_recovery * delta)
	move_and_slide()


func apply_hit_reaction(direction: Vector2, _damage: int, hit_position: Vector2) -> void:
	var knockback_direction := direction.normalized()
	if knockback_direction == Vector2.ZERO:
		knockback_direction = Vector2.RIGHT
	_knockback_velocity = knockback_direction * knockback_strength
	_spawn_vfx(hit_vfx_scene, hit_position)
	_flash()


func _update_contact_damage(delta: float) -> void:
	_damage_cooldown -= delta
	if _damage_cooldown > 0.0:
		return

	for body in _overlapping_bodies:
		var health_node: Node = _find_health(body)
		if health_node != null:
			health_node.apply_damage(contact_damage)
			_damage_cooldown = contact_interval
			return


func _find_health(node: Node) -> Node:
	if node == null:
		return null

	return node.get_node_or_null("Health")


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
