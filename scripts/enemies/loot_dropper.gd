extends Node
class_name LootDropper

const DEFAULT_DROPPED_ITEM_SCENE := preload("res://scenes/interaction/dropped_item.tscn")

@export var dropped_item_scene: PackedScene
@export var item_ids: Array[StringName] = []
@export var drop_chances: Array[float] = []
@export var min_quantities: Array[int] = []
@export var max_quantities: Array[int] = []
@export var metadata_entries: Array[Dictionary] = []
@export var drop_offset: Vector2 = Vector2(0.0, -10.0)
@export var spread_radius: float = 18.0

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()


func drop_at(spawn_position: Vector2, drop_parent: Node = null) -> Array[Node]:
	var spawned_items: Array[Node] = []
	var scene := dropped_item_scene
	if scene == null:
		scene = DEFAULT_DROPPED_ITEM_SCENE
	if scene == null:
		return spawned_items

	var parent := drop_parent
	if parent == null:
		parent = get_tree().current_scene
	if parent == null:
		parent = get_tree().root

	for loot_entry in roll_loot():
		var item_id: StringName = loot_entry.get("item_id", &"")
		var quantity: int = int(loot_entry.get("quantity", 1))
		var metadata: Dictionary = loot_entry.get("metadata", {})
		var dropped_item := scene.instantiate()
		dropped_item.set("item_id", item_id)
		dropped_item.set("quantity", quantity)
		dropped_item.set("metadata", metadata)
		parent.add_child(dropped_item)

		if dropped_item is Node2D:
			var dropped_item_2d := dropped_item as Node2D
			dropped_item_2d.global_position = _get_drop_position(spawn_position, spawned_items.size())

		spawned_items.append(dropped_item)

	return spawned_items


func roll_loot() -> Array[Dictionary]:
	var loot_entries: Array[Dictionary] = []
	for index in item_ids.size():
		var item_id := item_ids[index]
		if item_id == &"":
			continue

		var chance := clampf(_get_float_at(drop_chances, index, 1.0), 0.0, 1.0)
		if chance < 1.0 and _rng.randf() > chance:
			continue

		var min_quantity := maxi(_get_int_at(min_quantities, index, 1), 1)
		var max_quantity := maxi(_get_int_at(max_quantities, index, min_quantity), min_quantity)
		var quantity := _rng.randi_range(min_quantity, max_quantity)
		var metadata := _get_dictionary_at(metadata_entries, index)
		if not metadata.is_empty():
			quantity = 1

		loot_entries.append({
			"item_id": item_id,
			"quantity": quantity,
			"metadata": metadata,
		})

	return loot_entries


func _get_drop_position(spawn_position: Vector2, drop_index: int) -> Vector2:
	if spread_radius <= 0.0:
		return spawn_position + drop_offset

	var angle := _rng.randf_range(-PI, PI)
	var radius := _rng.randf_range(0.0, spread_radius)
	var random_offset := Vector2(cos(angle), sin(angle) * 0.35) * radius
	if drop_index > 0:
		random_offset.x += float(drop_index) * 8.0
	return spawn_position + drop_offset + random_offset


func _get_float_at(values: Array[float], index: int, fallback: float) -> float:
	if index < 0 or index >= values.size():
		return fallback
	return values[index]


func _get_int_at(values: Array[int], index: int, fallback: int) -> int:
	if index < 0 or index >= values.size():
		return fallback
	return values[index]


func _get_dictionary_at(values: Array[Dictionary], index: int) -> Dictionary:
	if index < 0 or index >= values.size():
		return {}
	return values[index].duplicate(true)
