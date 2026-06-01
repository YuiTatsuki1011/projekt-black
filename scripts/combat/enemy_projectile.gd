extends Area2D
class_name EnemyProjectile

@export var speed: float = 560.0
@export var lifetime: float = 2.0
@export var damage: int = 16

var _velocity: Vector2 = Vector2.LEFT


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


func _on_body_entered(body: Node) -> void:
	var health: Node = _find_health(body)
	if health != null:
		if body.has_method("apply_damage_reaction"):
			body.call("apply_damage_reaction", _velocity.normalized(), damage, global_position)
		health.apply_damage(damage)

	queue_free()


func _find_health(node: Node) -> Node:
	if node == null:
		return null

	return node.get_node_or_null("Health")
