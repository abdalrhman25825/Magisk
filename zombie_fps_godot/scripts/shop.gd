extends Area3D

@export var game_state_path: NodePath
@export var player_path: NodePath

var game_state: GameState
var player: Node3D
var can_interact := false

func _ready() -> void:
	game_state = get_node(game_state_path) as GameState
	player = get_node(player_path)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _process(_delta: float) -> void:
	if can_interact and Input.is_action_just_pressed("interact"):
		_purchase_next_weapon()

func _on_body_entered(body: Node3D) -> void:
	if body == player:
		can_interact = true
		$"../HUD".show_message("Press E to buy a new weapon")

func _on_body_exited(body: Node3D) -> void:
	if body == player:
		can_interact = false
		$"../HUD".show_message("")

func _purchase_next_weapon() -> void:
	var weapon_manager: WeaponManager = player.get_node("WeaponManager")
	for weapon in weapon_manager.get_weapon_list():
		if not weapon_manager.is_weapon_owned(weapon["id"]):
			if game_state.spend_points(weapon["cost"]):
				weapon_manager.purchase_weapon(weapon["id"])
				weapon_manager.emit_signal("weapon_changed", weapon["name"])
				$"../HUD".show_message("Purchased %s" % weapon["name"])
			else:
				$"../HUD".show_message("Not enough points")
			return
	$"../HUD".show_message("All weapons purchased")
