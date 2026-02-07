extends Node3D

@export var zombie_scene: PackedScene
@export var player_path: NodePath

var player: Node3D

func _ready() -> void:
	player = get_node(player_path) as Node3D

func spawn_zombie() -> void:
	if not zombie_scene:
		return
	var markers := get_children().filter(func(child): return child is Marker3D)
	if markers.is_empty():
		return
	var marker := markers[randi() % markers.size()] as Marker3D
	var zombie := zombie_scene.instantiate() as CharacterBody3D
	zombie.global_transform.origin = marker.global_transform.origin
	get_parent().add_child(zombie)
	if zombie.has_method("set_target"):
		zombie.set_target(player)
