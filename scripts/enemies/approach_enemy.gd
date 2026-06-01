extends CharacterBody2D
class_name ApproachEnemy

@export var move_speed: float = 42.0
@export var contact_damage: int = 8
@export var contact_interval: float = 0.9

@onready var health: Node = $Health
@onready var body_visual: Polygon2D = $BodyVisual
@onready var damage_area: Area2D = $DamageArea

var _gravity: float = 980.0
var _target: Node2D
var _damage_cooldown: float = 0.0
var _overlapping_bodies: Array[Node] = []
var _is_dead: bool = false


func _ready() -> void:
	if ProjectSettings.has_setting("physics/2d/default_gravity"):
		_gravity = float(ProjectSettings.get_setting("physics/2d/default_gravity"))

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

	velocity.x = 0.0
	if _target != null:
		var direction_x: float = signf(_target.global_position.x - global_position.x)
		velocity.x = direction_x * move_speed
		if absf(direction_x) > 0.0:
			body_visual.scale.x = direction_x

	move_and_slide()


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


func _on_died() -> void:
	_is_dead = true
	collision_layer = 0
	collision_mask = 0
	damage_area.monitoring = false
	queue_free()
