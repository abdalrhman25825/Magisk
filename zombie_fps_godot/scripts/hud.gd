extends CanvasLayer

@onready var points_label: Label = $MarginContainer/VBoxContainer/PointsLabel
@onready var wave_label: Label = $MarginContainer/VBoxContainer/WaveLabel
@onready var ammo_label: Label = $MarginContainer/VBoxContainer/AmmoLabel
@onready var message_label: Label = $MarginContainer/VBoxContainer/MessageLabel
@onready var game_over_label: Label = $GameOverLabel

func _ready() -> void:
	game_over_label.visible = false

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
