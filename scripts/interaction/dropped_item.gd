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

	if item_id == &"pistol_ammo":
		body.color = Color(0.28, 0.56, 0.76, 1.0)
	else:
		body.color = Color(0.44, 0.44, 0.46, 1.0)


func _get_display_name() -> String:
	if item_id == &"pistol_ammo":
		return "Ammo"

	return str(item_id)
