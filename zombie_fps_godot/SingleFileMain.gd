extends Node3D

class GameState:
	extends Node
	signal points_changed(points: int)
	signal wave_changed(wave: int)
	var points := 500
	var wave := 1
	var perks: Dictionary = {}
	func add_points(amount: int) -> void:
		points += amount
		emit_signal("points_changed", points)
	func spend_points(cost: int) -> bool:
		if points < cost:
			return false
		points -= cost
		emit_signal("points_changed", points)
		return true
	func set_wave(new_wave: int) -> void:
		wave = new_wave
		emit_signal("wave_changed", wave)
	func has_perk(perk_id: String) -> bool:
		return perks.get(perk_id, false)
	func buy_perk(perk_id: String) -> void:
		perks[perk_id] = true

class WeaponManager:
	extends Node
	signal weapon_changed(weapon_name: String)
	signal ammo_changed(current_ammo: int, reserve_ammo: int)
	var weapons: Array = []
	var owned_weapon_ids: Array[String] = []
	var current_index := 0
	var fire_cooldown := 0.0
	var raycast: RayCast3D
	func _ready() -> void:
		_setup_default_weapons()
		_emit_current_ammo()
	func _process(delta: float) -> void:
		fire_cooldown = maxf(0.0, fire_cooldown - delta)
	func _setup_default_weapons() -> void:
		weapons = [
			{"id": "pistol", "name": "Pistol", "damage": 20, "fire_rate": 0.3, "magazine": 12, "current": 12, "reserve": 60, "cost": 0},
			{"id": "smg", "name": "SMG", "damage": 12, "fire_rate": 0.1, "magazine": 30, "current": 30, "reserve": 120, "cost": 1000},
			{"id": "rifle", "name": "Rifle", "damage": 22, "fire_rate": 0.12, "magazine": 30, "current": 30, "reserve": 90, "cost": 1500},
			{"id": "shotgun", "name": "Shotgun", "damage": 55, "fire_rate": 0.8, "magazine": 8, "current": 8, "reserve": 32, "cost": 1250},
			{"id": "sniper", "name": "Sniper", "damage": 90, "fire_rate": 1.0, "magazine": 5, "current": 5, "reserve": 20, "cost": 1750},
			{"id": "lmg", "name": "LMG", "damage": 18, "fire_rate": 0.09, "magazine": 60, "current": 60, "reserve": 180, "cost": 2000}
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
	func try_shoot(damage_multiplier: float) -> void:
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

class Zombie:
	extends CharacterBody3D
	var speed := 2.5
	var health := 60
	var damage := 10
	var attack_range := 1.5
	var attack_cooldown := 1.2
	var target: Node3D
	var cooldown := 0.0
	func _ready() -> void:
		add_to_group("zombie")
	func _physics_process(delta: float) -> void:
		if not target:
			return
		cooldown = maxf(0.0, cooldown - delta)
		var direction := (target.global_transform.origin - global_transform.origin)
		direction.y = 0
		if direction.length() > attack_range:
			velocity = direction.normalized() * speed
			move_and_slide()
		else:
			velocity = Vector3.ZERO
			if cooldown == 0.0 and target.has_method("apply_damage"):
				target.apply_damage(damage)
				cooldown = attack_cooldown
	func apply_damage(amount: float) -> void:
		health -= int(amount)
		if health <= 0:
			queue_free()
			var game_state := get_tree().get_first_node_in_group("game_state") as GameState
			if game_state:
				game_state.add_points(75)
	func set_target(new_target: Node3D) -> void:
		target = new_target

class ZombieSpawner:
	extends Node3D
	var player: Node3D
	func spawn_zombie() -> void:
		var markers := get_children().filter(func(child): return child is Marker3D)
		if markers.is_empty():
			return
		var marker := markers[randi() % markers.size()] as Marker3D
		var zombie := Zombie.new()
		var mesh := MeshInstance3D.new()
		mesh.mesh = CapsuleMesh.new()
		zombie.add_child(mesh)
		var collider := CollisionShape3D.new()
		collider.shape = CapsuleShape3D.new()
		zombie.add_child(collider)
		zombie.global_transform.origin = marker.global_transform.origin
		get_parent().add_child(zombie)
		zombie.set_target(player)

class WaveManager:
	extends Node
	var spawner: ZombieSpawner
	var game_state: GameState
	var zombies_remaining := 0
	var spawn_timer := 0.0
	func _ready() -> void:
		game_state.add_to_group("game_state")
		_start_wave(1)
	func _process(delta: float) -> void:
		if zombies_remaining <= 0 and _alive_zombies() == 0:
			_start_wave(game_state.wave + 1)
			return
		if zombies_remaining > 0:
			spawn_timer -= delta
			if spawn_timer <= 0.0:
				spawner.spawn_zombie()
				zombies_remaining -= 1
				spawn_timer = maxf(0.4, 1.2 - (game_state.wave * 0.05))
	func _start_wave(wave: int) -> void:
		game_state.set_wave(wave)
		zombies_remaining = 6 + (wave * 3)
		spawn_timer = 1.0
	func _alive_zombies() -> int:
		return get_tree().get_nodes_in_group("zombie").size()

class HUD:
	extends CanvasLayer
	var points_label: Label
	var wave_label: Label
	var ammo_label: Label
	var message_label: Label
	var game_over_label: Label
	func _ready() -> void:
		points_label = _make_label("Points: 500")
		wave_label = _make_label("Wave: 1")
		ammo_label = _make_label("Ammo: 12 / 60")
		message_label = _make_label("")
		var margin := MarginContainer.new()
		margin.offset_left = 16
		margin.offset_top = 16
		margin.offset_right = 320
		margin.offset_bottom = 200
		var vbox := VBoxContainer.new()
		margin.add_child(vbox)
		vbox.add_child(points_label)
		vbox.add_child(wave_label)
		vbox.add_child(ammo_label)
		vbox.add_child(message_label)
		add_child(margin)
		game_over_label = Label.new()
		game_over_label.text = "GAME OVER"
		game_over_label.visible = false
		game_over_label.anchor_left = 0.5
		game_over_label.anchor_top = 0.5
		game_over_label.anchor_right = 0.5
		game_over_label.anchor_bottom = 0.5
		game_over_label.offset_left = -120
		game_over_label.offset_top = -20
		game_over_label.offset_right = 120
		game_over_label.offset_bottom = 20
		add_child(game_over_label)
	func _make_label(text: String) -> Label:
		var label := Label.new()
		label.text = text
		return label
	func update_points(points: int) -> void:
		points_label.text = "Points: %d" % points
	func update_wave(wave: int) -> void:
		wave_label.text = "Wave: %d" % wave
	func update_ammo(current_ammo: int, reserve_ammo: int) -> void:
		ammo_label.text = "Ammo: %d / %d" % [current_ammo, reserve_ammo]
	func show_message(text: String) -> void:
		message_label.text = text
	func show_game_over() -> void:
		game_over_label.visible = true

class Shop:
	extends Area3D
	var game_state: GameState
	var player: Node3D
	var hud: HUD
	var can_interact := false
	func _ready() -> void:
		body_entered.connect(_on_body_entered)
		body_exited.connect(_on_body_exited)
	func _process(_delta: float) -> void:
		if can_interact and Input.is_action_just_pressed("interact"):
			_purchase_next_weapon()
	func _on_body_entered(body: Node3D) -> void:
		if body == player:
			can_interact = true
			hud.show_message("Press E to buy a new weapon")
	func _on_body_exited(body: Node3D) -> void:
		if body == player:
			can_interact = false
			hud.show_message("")
	func _purchase_next_weapon() -> void:
		var weapon_manager: WeaponManager = player.get_node("WeaponManager")
		for weapon in weapon_manager.get_weapon_list():
			if not weapon_manager.is_weapon_owned(weapon["id"]):
				if game_state.spend_points(weapon["cost"]):
					weapon_manager.purchase_weapon(weapon["id"])
					weapon_manager.emit_signal("weapon_changed", weapon["name"])
					hud.show_message("Purchased %s" % weapon["name"])
				else:
					hud.show_message("Not enough points")
				return
		hud.show_message("All weapons purchased")

class PerkStation:
	extends Area3D
	var game_state: GameState
	var player: Node3D
	var hud: HUD
	var can_interact := false
	var perks := [
		{"id": "double_damage", "name": "Double Damage", "cost": 1200},
		{"id": "extra_health", "name": "Extra Health", "cost": 1000},
		{"id": "faster_reload", "name": "Faster Reload", "cost": 900}
	]
	func _ready() -> void:
		body_entered.connect(_on_body_entered)
		body_exited.connect(_on_body_exited)
	func _process(_delta: float) -> void:
		if can_interact and Input.is_action_just_pressed("interact"):
			_purchase_perk()
	func _on_body_entered(body: Node3D) -> void:
		if body == player:
			can_interact = true
			hud.show_message("Press E to buy a perk")
	func _on_body_exited(body: Node3D) -> void:
		if body == player:
			can_interact = false
			hud.show_message("")
	func _purchase_perk() -> void:
		for perk in perks:
			if not game_state.has_perk(perk["id"]):
				if game_state.spend_points(perk["cost"]):
					game_state.buy_perk(perk["id"])
					player.apply_perk(perk["id"])
					hud.show_message("Perk acquired: %s" % perk["name"])
				else:
					hud.show_message("Not enough points")
				return
		hud.show_message("All perks purchased")

class Player:
	extends CharacterBody3D
	var speed := 6.0
	var jump_velocity := 4.5
	var mouse_sensitivity := 0.002
	var max_health := 100
	var gravity := ProjectSettings.get_setting("physics/3d/default_gravity")
	var health := 100
	var damage_multiplier := 1.0
	var is_dead := false
	var camera: Camera3D
	var weapon_manager: WeaponManager
	var hud: HUD
	func _ready() -> void:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		health = max_health
	func _unhandled_input(event: InputEvent) -> void:
		if event is InputEventMouseMotion:
			rotate_y(-event.relative.x * mouse_sensitivity)
			get_node("Head").rotate_x(-event.relative.y * mouse_sensitivity)
			get_node("Head").rotation.x = clamp(get_node("Head").rotation.x, deg_to_rad(-75), deg_to_rad(75))
		if event.is_action_pressed("shoot"):
			weapon_manager.try_shoot(damage_multiplier)
		if event.is_action_pressed("reload"):
			weapon_manager.reload_weapon()
		if event.is_action_pressed("next_weapon"):
			weapon_manager.next_weapon()
		if event.is_action_pressed("prev_weapon"):
			weapon_manager.prev_weapon()
	func _physics_process(delta: float) -> void:
		if is_dead:
			return
		if not is_on_floor():
			velocity.y -= gravity * delta
		var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
		var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
		if direction:
			velocity.x = direction.x * speed
			velocity.z = direction.z * speed
		else:
			velocity.x = move_toward(velocity.x, 0, speed)
			velocity.z = move_toward(velocity.z, 0, speed)
		if Input.is_action_just_pressed("ui_accept") and is_on_floor():
			velocity.y = jump_velocity
		move_and_slide()
	func apply_damage(amount: float) -> void:
		if is_dead:
			return
		health -= int(amount)
		if health <= 0:
			is_dead = true
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			hud.show_game_over()
	func apply_perk(perk_id: String) -> void:
		match perk_id:
			"double_damage":
				damage_multiplier = 1.5
			"extra_health":
				max_health = 150
				health = max_health
			"faster_reload":
				weapon_manager.fire_cooldown = maxf(weapon_manager.fire_cooldown - 0.05, 0.05)

var game_state: GameState
var player: Player
var hud: HUD

func _ready() -> void:
	_randomize()
	_setup_inputs()
	_build_world()

func _randomize() -> void:
	if Engine.get_frames_drawn() == 0:
		randomize()

func _setup_inputs() -> void:
	if not InputMap.has_action("move_forward"):
		InputMap.add_action("move_forward")
		InputMap.action_add_event("move_forward", _key_event(KEY_W))
		InputMap.add_action("move_backward")
		InputMap.action_add_event("move_backward", _key_event(KEY_S))
		InputMap.add_action("move_left")
		InputMap.action_add_event("move_left", _key_event(KEY_A))
		InputMap.add_action("move_right")
		InputMap.action_add_event("move_right", _key_event(KEY_D))
		InputMap.add_action("shoot")
		InputMap.action_add_event("shoot", _mouse_event(MOUSE_BUTTON_LEFT))
		InputMap.add_action("reload")
		InputMap.action_add_event("reload", _key_event(KEY_R))
		InputMap.add_action("interact")
		InputMap.action_add_event("interact", _key_event(KEY_E))
		InputMap.add_action("next_weapon")
		InputMap.action_add_event("next_weapon", _mouse_event(MOUSE_BUTTON_WHEEL_UP))
		InputMap.add_action("prev_weapon")
		InputMap.action_add_event("prev_weapon", _mouse_event(MOUSE_BUTTON_WHEEL_DOWN))

func _key_event(keycode: Key) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = keycode
	return ev

func _mouse_event(button: MouseButton) -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	return ev

func _build_world() -> void:
	game_state = GameState.new()
	game_state.name = "GameState"
	add_child(game_state)

	hud = HUD.new()
	add_child(hud)
	game_state.points_changed.connect(hud.update_points)
	game_state.wave_changed.connect(hud.update_wave)

	var floor := MeshInstance3D.new()
	floor.mesh = BoxMesh.new()
	floor.mesh.size = Vector3(40, 1, 40)
	floor.translation = Vector3(0, -0.5, 0)
	add_child(floor)
	var floor_collision := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	floor_shape.shape = BoxShape3D.new()
	floor_shape.shape.size = Vector3(40, 1, 40)
	floor_collision.add_child(floor_shape)
	add_child(floor_collision)

	var light := DirectionalLight3D.new()
	light.rotation = Vector3(-0.9, 0.5, 0)
	add_child(light)

	player = Player.new()
	player.name = "Player"
	add_child(player)
	var head := Node3D.new()
	head.name = "Head"
	player.add_child(head)
	var camera := Camera3D.new()
	camera.name = "Camera3D"
	camera.transform.origin = Vector3(0, 1.6, 0)
	head.add_child(camera)
	var raycast := RayCast3D.new()
	raycast.cast_to = Vector3(0, 0, -100)
	camera.add_child(raycast)
	var weapon_manager := WeaponManager.new()
	weapon_manager.name = "WeaponManager"
	weapon_manager.raycast = raycast
	player.add_child(weapon_manager)
	weapon_manager.ammo_changed.connect(hud.update_ammo)
	player.weapon_manager = weapon_manager
	player.hud = hud

	var spawner := ZombieSpawner.new()
	spawner.name = "ZombieSpawner"
	spawner.player = player
	add_child(spawner)
	for pos in [Vector3(-10, 0, -10), Vector3(12, 0, -8), Vector3(8, 0, 14)]:
		var marker := Marker3D.new()
		marker.transform.origin = pos
		spawner.add_child(marker)

	var wave_manager := WaveManager.new()
	wave_manager.spawner = spawner
	wave_manager.game_state = game_state
	add_child(wave_manager)

	var shop := Shop.new()
	shop.name = "Shop"
	shop.game_state = game_state
	shop.player = player
	shop.hud = hud
	add_child(shop)
	shop.add_child(_box_mesh(Vector3(2, 2, 2)))
	shop.add_child(_area_collision(Vector3(2, 2, 2)))

	var perk_station := PerkStation.new()
	perk_station.name = "PerkStation"
	perk_station.game_state = game_state
	perk_station.player = player
	perk_station.hud = hud
	perk_station.transform.origin = Vector3(5, 0, 5)
	add_child(perk_station)
	perk_station.add_child(_box_mesh(Vector3(2, 2, 2)))
	perk_station.add_child(_area_collision(Vector3(2, 2, 2)))

func _box_mesh(size: Vector3) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	mesh.mesh.size = size
	return mesh

func _area_collision(size: Vector3) -> CollisionShape3D:
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	shape.shape.size = size
	return shape
