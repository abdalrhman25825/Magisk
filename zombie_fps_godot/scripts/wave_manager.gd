extends Node

@export var spawner_path: NodePath
@export var game_state_path: NodePath

var spawner: Node
var game_state: GameState
var zombies_remaining := 0
var spawn_timer := 0.0

func _ready() -> void:
	spawner = get_node(spawner_path)
	game_state = get_node(game_state_path) as GameState
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
