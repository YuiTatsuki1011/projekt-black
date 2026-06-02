extends Resource
class_name RangedWeaponData

@export var weapon_id: StringName = &"basic_pistol"
@export var display_name: String = "Basic Pistol"
@export var damage: int = 10
@export var magazine_size: int = 6
@export var starting_reserve_ammo: int = 24
@export var ammo_item_id: StringName = &"pistol_ammo"
@export var magazine_item_id: StringName = &"pistol_magazine"
@export_range(0, 4, 1) var chamber_size: int = 1
@export_range(0, 20, 1) var starting_spare_magazines: int = 3
@export var reload_time: float = 1.2
@export var fire_cooldown: float = 0.22
@export var recoil_amount: float = 0.18
@export var recoil_recovery_speed: float = 8.0
@export var projectile_scene: PackedScene
