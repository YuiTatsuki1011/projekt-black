extends Area2D
class_name Projectile

@export var speed: float = 720.0
@export var lifetime: float = 1.2
@export var damage: int = 10

var _velocity: Vector2 = Vector2.RIGHT


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func launch(direction: Vector2) -> void:
	if direction.length_squared() <= 0.01:
		return

	var normalized_direction := direction.normalized()
	_velocity = normalized_direction * speed
	global_rotation = normalized_direction.angle()


func _physics_process(delta: float) -> void:
	global_position += _velocity * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()


func _on_body_entered(_body: Node) -> void:
	var health: Node = _find_health(_body)
	if health != null:
		health.apply_damage(damage)

	queue_free()


func _find_health(node: Node) -> Node:
	if node == null:
		return null

	return node.get_node_or_null("Health")
