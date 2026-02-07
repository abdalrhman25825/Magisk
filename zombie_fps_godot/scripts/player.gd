extends CharacterBody3D

@export var speed := 6.0
@export var jump_velocity := 4.5
@export var mouse_sensitivity := 0.002
@export var max_health := 100

@onready var camera: Camera3D = $Head/Camera3D
@onready var weapon_manager: WeaponManager = $WeaponManager
@onready var game_state: GameState = %GameState

var gravity := ProjectSettings.get_setting("physics/3d/default_gravity")
var health := 100
var damage_multiplier := 1.0
var is_dead := false

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	health = max_health

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * mouse_sensitivity)
		$Head.rotate_x(-event.relative.y * mouse_sensitivity)
		$Head.rotation.x = clamp($Head.rotation.x, deg_to_rad(-75), deg_to_rad(75))
	if event.is_action_pressed("shoot"):
		weapon_manager.try_shoot(global_transform.origin, damage_multiplier)
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
		$"../HUD".show_game_over()

func apply_perk(perk_id: String) -> void:
	match perk_id:
		"double_damage":
			damage_multiplier = 1.5
		"extra_health":
			max_health = 150
			health = max_health
		"faster_reload":
			weapon_manager.fire_cooldown = maxf(weapon_manager.fire_cooldown - 0.05, 0.05)
