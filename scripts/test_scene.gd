extends Node2D

const APPEARANCE_COUNT := 24


var _char
var _hud_label: Label


func _ready() -> void:
	_char = $CharacterBody2D
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	_hud_label = Label.new()
	_hud_label.position = Vector2(8, 8)
	_hud_label.size = Vector2(760, 240)
	layer.add_child(_hud_label)


func _process(_delta: float) -> void:
	if not is_instance_valid(_char):
		return
	var info: Dictionary = _char.get_frame_info()
	_hud_label.text = "\n".join([
		"MirRPG Hum Character Test",
		"%s  appearance_id=%d  base=%d" % [str(info["preset_name"]), int(info["appearance_id"]), int(info["appearance_base"])],
		"action=%s  dir=%s  locked=%s  dead=%s  dig_held=%s" % [str(_char.current_action), str(_char.last_direction), str(bool(info["action_locked"])), str(_char.dead), str(bool(info["dig_held"]))],
		"anim=%s  frame=%d  abs_idx=%d" % [str(info["animation_name"]), int(info["godot_frame"]), int(info["absolute_index"])],
		"",
		"WASD/arrows=move  Shift/Space=run",
		"P=pose J=attack_onehand K=attack_twohand L=attack_power U=cast I=dig(hold) H=hit Y=death R=recover",
		"F7/F8=cycle appearance  F1=debug label  F2-F4=force idle/walk/run",
	])


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_F7:
			_cycle_appearance(-1)
		KEY_F8:
			_cycle_appearance(1)


func _cycle_appearance(step: int) -> void:
	if not is_instance_valid(_char):
		return
	var next := (int(_char.appearance_id) + step) % APPEARANCE_COUNT
	if next < 0:
		next += APPEARANCE_COUNT
	_char.set_appearance(next, "Hum Appearance %02d" % (next + 1))
