extends Node
class_name WeaponManager

signal weapon_changed(weapon_name: String)
signal ammo_changed(current_ammo: int, reserve_ammo: int)

@export var raycast_path: NodePath

var weapons: Array = []
var owned_weapon_ids: Array[String] = []
var current_index := 0
var fire_cooldown := 0.0
var raycast: RayCast3D

func _ready() -> void:
	raycast = get_node(raycast_path) as RayCast3D
	_setup_default_weapons()
	_emit_current_ammo()

func _process(delta: float) -> void:
	fire_cooldown = maxf(0.0, fire_cooldown - delta)

func _setup_default_weapons() -> void:
	weapons = [
		{
			"id": "pistol",
			"name": "Pistol",
			"damage": 20,
			"fire_rate": 0.3,
			"magazine": 12,
			"current": 12,
			"reserve": 60,
			"cost": 0
		},
		{
			"id": "smg",
			"name": "SMG",
			"damage": 12,
			"fire_rate": 0.1,
			"magazine": 30,
			"current": 30,
			"reserve": 120,
			"cost": 1000
		},
		{
			"id": "rifle",
			"name": "Rifle",
			"damage": 22,
			"fire_rate": 0.12,
			"magazine": 30,
			"current": 30,
			"reserve": 90,
			"cost": 1500
		},
		{
			"id": "shotgun",
			"name": "Shotgun",
			"damage": 55,
			"fire_rate": 0.8,
			"magazine": 8,
			"current": 8,
			"reserve": 32,
			"cost": 1250
		},
		{
			"id": "sniper",
			"name": "Sniper",
			"damage": 90,
			"fire_rate": 1.0,
			"magazine": 5,
			"current": 5,
			"reserve": 20,
			"cost": 1750
		},
		{
			"id": "lmg",
			"name": "LMG",
			"damage": 18,
			"fire_rate": 0.09,
			"magazine": 60,
			"current": 60,
			"reserve": 180,
			"cost": 2000
		}
	]
	owned_weapon_ids = ["pistol"]
	current_index = 0
	emit_signal("weapon_changed", _current_weapon()["name"])

func _current_weapon() -> Dictionary:
	return weapons[current_index]

func get_weapon_list() -> Array:
	return weapons

func is_weapon_owned(weapon_id: String) -> bool:
	return weapon_id in owned_weapon_ids

func purchase_weapon(weapon_id: String) -> bool:
	if is_weapon_owned(weapon_id):
		return false
	owned_weapon_ids.append(weapon_id)
	return true

func next_weapon() -> void:
	current_index = _find_next_owned(1)
	_emit_current_ammo()
	emit_signal("weapon_changed", _current_weapon()["name"])

func prev_weapon() -> void:
	current_index = _find_next_owned(-1)
	_emit_current_ammo()
	emit_signal("weapon_changed", _current_weapon()["name"])

func _find_next_owned(direction: int) -> int:
	var index := current_index
	for _i in weapons.size():
		index = (index + direction + weapons.size()) % weapons.size()
		if weapons[index]["id"] in owned_weapon_ids:
			return index
	return current_index

func try_shoot(target_global_pos: Vector3, damage_multiplier: float) -> void:
	var weapon := _current_weapon()
	if fire_cooldown > 0.0:
		return
	if weapon["current"] <= 0:
		return
	fire_cooldown = weapon["fire_rate"]
	weapon["current"] -= 1
	if raycast:
		raycast.force_raycast_update()
		if raycast.is_colliding():
			var collider := raycast.get_collider()
			if collider and collider.has_method("apply_damage"):
				collider.apply_damage(weapon["damage"] * damage_multiplier)
	_emit_current_ammo()

func reload_weapon() -> void:
	var weapon := _current_weapon()
	if weapon["current"] == weapon["magazine"]:
		return
	if weapon["reserve"] <= 0:
		return
	var needed := weapon["magazine"] - weapon["current"]
	var taken := min(needed, weapon["reserve"])
	weapon["current"] += taken
	weapon["reserve"] -= taken
	_emit_current_ammo()

func _emit_current_ammo() -> void:
	var weapon := _current_weapon()
	emit_signal("ammo_changed", weapon["current"], weapon["reserve"])
