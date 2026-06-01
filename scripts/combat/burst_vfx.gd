extends Node2D
class_name BurstVfx

@export var particle_count: int = 10
@export var min_speed: float = 40.0
@export var max_speed: float = 120.0
@export var lifetime: float = 0.35
@export var particle_size: Vector2 = Vector2(3, 3)
@export var burst_color: Color = Color(0.72, 0.02, 0.02, 1.0)
@export var gravity: float = 90.0

var _particles: Array[ColorRect] = []
var _velocities: Array[Vector2] = []
var _age: float = 0.0


func _ready() -> void:
	for index in particle_count:
		var particle := ColorRect.new()
		particle.color = burst_color
		particle.size = particle_size
		particle.position = -particle_size * 0.5
		particle.rotation = randf_range(-PI, PI)
		add_child(particle)

		var angle := randf_range(-PI, PI)
		var speed := randf_range(min_speed, max_speed)
		_particles.append(particle)
		_velocities.append(Vector2.RIGHT.rotated(angle) * speed)


func _process(delta: float) -> void:
	_age += delta
	var life_ratio := clampf(_age / lifetime, 0.0, 1.0)
	var alpha := 1.0 - life_ratio

	for index in _particles.size():
		var particle := _particles[index]
		var velocity := _velocities[index]
		velocity.y += gravity * delta
		_velocities[index] = velocity
		particle.position += velocity * delta
		particle.rotation += delta * 9.0
		particle.modulate.a = alpha

	if _age >= lifetime:
		queue_free()
