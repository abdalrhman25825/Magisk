extends Node
class_name GameState

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
