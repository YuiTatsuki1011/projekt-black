extends StaticBody2D
class_name TrainingTarget

@export var hit_vfx_scene: PackedScene
@export var death_vfx_scene: PackedScene
@export var hit_flash_time: float = 0.08

@onready var health: Node = $Health
@onready var body_visual: Polygon2D = $BodyVisual
@onready var mark_visual: Polygon2D = $Mark

var _base_body_color: Color
var _base_mark_color: Color
var _flash_tween: Tween


func _ready() -> void:
	_base_body_color = body_visual.color
	_base_mark_color = mark_visual.color
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)


func apply_hit_reaction(_direction: Vector2, _damage: int, hit_position: Vector2) -> void:
	_spawn_vfx(hit_vfx_scene, hit_position)
	_flash()


func _on_damaged(_amount: int, _current_health: int, _max_health: int) -> void:
	_flash()


func _on_died() -> void:
	_spawn_vfx(death_vfx_scene, global_position + Vector2(0, -24))
	queue_free()


func _flash() -> void:
	if _flash_tween != null:
		_flash_tween.kill()

	body_visual.color = Color(1.0, 0.78, 0.72, 1.0)
	mark_visual.color = Color.WHITE
	_flash_tween = create_tween()
	_flash_tween.tween_property(body_visual, "color", _base_body_color, hit_flash_time)
	_flash_tween.parallel().tween_property(mark_visual, "color", _base_mark_color, hit_flash_time)


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
