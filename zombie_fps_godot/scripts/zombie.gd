extends CharacterBody3D

@export var speed := 2.5
@export var health := 60
@export var damage := 10
@export var attack_range := 1.5
@export var attack_cooldown := 1.2

var target: Node3D
var cooldown := 0.0

func _ready() -> void:
\tadd_to_group("zombie")

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

func set_target(new_target: Node3D) -> void:
	target = new_target

func apply_damage(amount: float) -> void:
	health -= int(amount)
	if health <= 0:
		queue_free()
		var game_state := get_tree().get_first_node_in_group("game_state") as GameState
		if game_state:
			game_state.add_points(75)
