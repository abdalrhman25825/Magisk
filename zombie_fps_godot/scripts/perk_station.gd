extends Area3D

@export var game_state_path: NodePath
@export var player_path: NodePath

var game_state: GameState
var player: Node3D
var can_interact := false
var perks := [
	{"id": "double_damage", "name": "Double Damage", "cost": 1200},
	{"id": "extra_health", "name": "Extra Health", "cost": 1000},
	{"id": "faster_reload", "name": "Faster Reload", "cost": 900},
]

func _ready() -> void:
	game_state = get_node(game_state_path) as GameState
	player = get_node(player_path)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _process(_delta: float) -> void:
	if can_interact and Input.is_action_just_pressed("interact"):
		_purchase_perk()

func _on_body_entered(body: Node3D) -> void:
	if body == player:
		can_interact = true
		$"../HUD".show_message("Press E to buy a perk")

func _on_body_exited(body: Node3D) -> void:
	if body == player:
		can_interact = false
		$"../HUD".show_message("")

func _purchase_perk() -> void:
	for perk in perks:
		if not game_state.has_perk(perk["id"]):
			if game_state.spend_points(perk["cost"]):
				game_state.buy_perk(perk["id"])
				player.apply_perk(perk["id"])
				$"../HUD".show_message("Perk acquired: %s" % perk["name"])
			else:
				$"../HUD".show_message("Not enough points")
			return
	$"../HUD".show_message("All perks purchased")
