extends Area2D
class_name DroppedItem

@export var item_id: StringName = &"pistol_ammo"
@export var quantity: int = 1

@onready var label: Label = $Label
@onready var body: Polygon2D = $Body


func _ready() -> void:
	_refresh_visual()


func interact(interactor: Node) -> void:
	if interactor == null:
		return

	var inventory := interactor.get_node_or_null("Inventory")
	if inventory == null or not inventory.has_method("add_item"):
		return

	var added_quantity: int = inventory.add_item(item_id, quantity)
	if added_quantity <= 0:
		return

	quantity -= added_quantity
	if quantity <= 0:
		queue_free()
	else:
		_refresh_visual()


func _refresh_visual() -> void:
	label.text = "%s x%d" % [_get_display_name(), quantity]
	body.color = _get_display_color()


func _get_display_name() -> String:
	var definition: Dictionary = Inventory.ITEM_DEFINITIONS.get(item_id, {})
	if not definition.is_empty():
		return str(definition.get("short_name", definition.get("name", item_id)))

	return str(item_id)


func _get_display_color() -> Color:
	var definition: Dictionary = Inventory.ITEM_DEFINITIONS.get(item_id, {})
	if definition.has("color"):
		return definition.get("color")

	return Color(0.44, 0.44, 0.46, 1.0)
