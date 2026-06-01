extends Node
class_name Inventory

signal item_quantity_changed(item_id: StringName, quantity: int)

@export var starting_items: Dictionary = {}

var _items: Dictionary = {}


func _ready() -> void:
	for item_id in starting_items:
		var quantity := int(starting_items[item_id])
		if quantity > 0:
			_items[StringName(str(item_id))] = quantity

	for item_id in _items:
		item_quantity_changed.emit(item_id, int(_items[item_id]))


func get_quantity(item_id: StringName) -> int:
	return int(_items.get(item_id, 0))


func add_item(item_id: StringName, quantity: int) -> void:
	if quantity <= 0:
		return

	var next_quantity: int = get_quantity(item_id) + quantity
	_items[item_id] = next_quantity
	item_quantity_changed.emit(item_id, next_quantity)


func remove_item(item_id: StringName, quantity: int) -> int:
	if quantity <= 0:
		return 0

	var current_quantity: int = get_quantity(item_id)
	var removed_quantity: int = mini(current_quantity, quantity)
	if removed_quantity <= 0:
		return 0

	var next_quantity: int = current_quantity - removed_quantity
	if next_quantity <= 0:
		_items.erase(item_id)
	else:
		_items[item_id] = next_quantity

	item_quantity_changed.emit(item_id, next_quantity)
	return removed_quantity


func has_item(item_id: StringName, quantity: int = 1) -> bool:
	return get_quantity(item_id) >= quantity
