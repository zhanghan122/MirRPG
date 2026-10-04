extends Node2D
## Generic Weapon Base switch tester (experiment only).
##
## Cycles through all 16 complete weapon_base groups listed in
## WEAPON_GROUP_INVENTORY.md section 2. F6 = previous group, F7 = next group
## (wrap around). The body stays the same; only active_weapon_base changes.
##
## Unified index rule for every action and direction:
##     local_index           = layout_offset + dir_index * slot_stride + frame
##     weapon_absolute_index = active_weapon_base + local_index
##
## ACTION_LAYOUT below reproduces the frozen 31200 candidate arrays in
## scripts/experiments/weapon_idle_test.gd exactly (verified against
## WEAPON_GROUP_INVENTORY.md section 1: 416 valid locals per complete group).
## dir_index order matches HumFrames.DIRECTIONS: n=0 ne=1 e=2 se=3 s=4 sw=5 w=6 nw=7.
##
## Body frame N always maps to weapon frame N % frames_count for the current
## body action/direction, so idle/walk/run stay in sync with the Hum body and
## death holds on its last frame (same rule as the frozen 31200 experiment).
##
## Do not use this script outside experiments/. It does not modify the formal
## Hum pipeline, the frozen 31200 weapon experiment, hair experiments, or any
## original asset.

const WEAPON_BASES := [
	8400, 9600, 22800, 23400, 31200, 31800, 32400, 33000,
	37800, 38400, 39000, 40800, 41400, 43800, 44400, 45000,
]

const DIR_INDEX := {
	"n": 0, "ne": 1, "e": 2, "se": 3, "s": 4, "sw": 5, "w": 6, "nw": 7,
}

# Per-action local layout inside one 600-slot weapon group:
#   offset = first local index of the action block
#   stride = slot distance between consecutive directions
#   frames = valid frames per direction
const ACTION_LAYOUT := {
	"idle":             {"offset": 0,   "stride": 8, "frames": 4},
	"walk":             {"offset": 64,  "stride": 8, "frames": 6},
	"run":              {"offset": 128, "stride": 8, "frames": 6},
	"pose":             {"offset": 192, "stride": 1, "frames": 1},
	"attack_onehand":   {"offset": 200, "stride": 8, "frames": 6},
	"attack_twohand":   {"offset": 264, "stride": 8, "frames": 6},
	"attack_power":     {"offset": 328, "stride": 8, "frames": 8},
	"cast":             {"offset": 392, "stride": 8, "frames": 6},
	"dig":              {"offset": 456, "stride": 2, "frames": 2},
	"hit":              {"offset": 472, "stride": 8, "frames": 3},
	"death":            {"offset": 536, "stride": 8, "frames": 4},
}

const WEAPON_DIR := "res://Weapon/"
const PLACEMENT_DIR := "res://Weapon/Placements/"

var active_weapon_base: int = 31200
var _base_index: int = 4
var fine_tune_offset := Vector2.ZERO

var _player: CharacterBody2D
var _anchor: Node2D
var _sprite: Sprite2D
var _hud: Label

# Persistent cache across base switches; weapon frames are small and Godot's
# resource cache keeps loaded textures anyway.
var _textures: Dictionary = {}
var _placements: Dictionary = {}
var _missing_warned: Dictionary = {}


func _ready() -> void:
	_player = $Player
	_anchor = $Player/WeaponAnchor
	_sprite = $Player/WeaponAnchor/WeaponSprite
	_hud = $HudCanvasLayer/HudLabel
	active_weapon_base = int(WEAPON_BASES[_base_index])
	_update_hud(_current_state())


func _process(_delta: float) -> void:
	var state := _current_state()
	if state.is_empty():
		return
	_sync_weapon_frame(state)
	_update_hud(state)


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_F6:
			_switch_base(-1)
		KEY_F7:
			_switch_base(1)
		KEY_LEFT:
			fine_tune_offset.x -= 1.0
		KEY_RIGHT:
			fine_tune_offset.x += 1.0
		KEY_UP:
			fine_tune_offset.y -= 1.0
		KEY_DOWN:
			fine_tune_offset.y += 1.0
		KEY_0:
			fine_tune_offset = Vector2.ZERO


func _switch_base(step: int) -> void:
	_base_index = (_base_index + step) % WEAPON_BASES.size()
	active_weapon_base = int(WEAPON_BASES[_base_index])
	fine_tune_offset = Vector2.ZERO
	_sprite.texture = null
	_sprite.visible = false


func _local_index_for(action: String, dir: String, frame: int) -> int:
	var layout: Dictionary = ACTION_LAYOUT.get(action, {})
	if layout.is_empty() or not DIR_INDEX.has(dir):
		return -1
	return int(layout["offset"]) + int(DIR_INDEX[dir]) * int(layout["stride"]) + frame


func _current_state() -> Dictionary:
	if _player == null or not is_instance_valid(_player):
		return {}
	var info: Dictionary = _player.get_frame_info()
	var anim_name := String(info["animation_name"])
	var body_frame := int(info["godot_frame"])
	var sep := anim_name.rfind("_")
	var action := anim_name.left(sep) if sep > 0 else ""
	var dir := anim_name.substr(sep + 1) if sep > 0 else ""
	if not ACTION_LAYOUT.has(action):
		action = "idle"
	if not DIR_INDEX.has(dir):
		dir = "s"
	var frames_count := int(ACTION_LAYOUT[action]["frames"])
	var weapon_frame := -1
	if body_frame >= 0:
		weapon_frame = body_frame % frames_count
	var local_index := -1
	var weapon_absolute_index := -1
	if weapon_frame >= 0:
		local_index = _local_index_for(action, dir, weapon_frame)
		weapon_absolute_index = active_weapon_base + local_index
	return {
		"info": info,
		"action": action,
		"dir": dir,
		"body_frame": body_frame,
		"frames_count": frames_count,
		"weapon_frame": weapon_frame,
		"local_index": local_index,
		"weapon_absolute_index": weapon_absolute_index,
	}


func _sync_weapon_frame(state: Dictionary) -> void:
	var weapon_absolute_index := int(state["weapon_absolute_index"])
	if weapon_absolute_index < 0:
		_sprite.visible = false
		return
	var tex := _get_texture(weapon_absolute_index)
	if tex == null:
		_sprite.visible = false
		return
	_sprite.texture = tex
	_sprite.visible = true
	_anchor.position = _get_placement(weapon_absolute_index) + fine_tune_offset
	# West-facing weapon frames are drawn behind the body (same rule as the
	# frozen 31200 experiment).
	if state["dir"] == "w":
		_sprite.z_index = -1
	else:
		_sprite.z_index = 0


func _get_texture(abs_idx: int) -> Texture2D:
	if _textures.has(abs_idx):
		return _textures[abs_idx]
	var path := WEAPON_DIR + str(abs_idx).pad_zeros(5) + ".png"
	if not ResourceLoader.exists(path):
		if not _missing_warned.has(path):
			_missing_warned[path] = true
			push_warning("Weapon texture missing: %s" % path)
		return null
	var tex := load(path) as Texture2D
	_textures[abs_idx] = tex
	return tex


func _get_placement(abs_idx: int) -> Vector2:
	if _placements.has(abs_idx):
		return _placements[abs_idx]
	var pos := Vector2.ZERO
	var path := PLACEMENT_DIR + str(abs_idx).pad_zeros(5) + ".txt"
	if FileAccess.file_exists(path):
		var f := FileAccess.open(path, FileAccess.READ)
		if f != null:
			var line_x := f.get_line().strip_edges()
			var line_y := f.get_line().strip_edges()
			f.close()
			if not line_x.is_empty() and not line_y.is_empty():
				pos = Vector2(float(line_x.split(",")[0]), float(line_y.split(",")[0]))
	_placements[abs_idx] = pos
	return pos


func _update_hud(state: Dictionary) -> void:
	if _hud == null or state.is_empty():
		return
	var info: Dictionary = state["info"]
	var action := String(state["action"])
	var dir := String(state["dir"])
	var body_frame := int(state["body_frame"])
	var frames_count := int(state["frames_count"])
	var local_index := int(state["local_index"])
	var weapon_absolute_index := int(state["weapon_absolute_index"])

	var first_local := _local_index_for(action, dir, 0)
	var last_local := _local_index_for(action, dir, frames_count - 1)

	var base_list: Array = []
	for i in WEAPON_BASES.size():
		if i == _base_index:
			base_list.append("*%d" % int(WEAPON_BASES[i]))
		else:
			base_list.append(str(int(WEAPON_BASES[i])))

	var png_state := "-"
	if weapon_absolute_index >= 0:
		png_state = "ok" if _textures.has(weapon_absolute_index) else "missing"

	_hud.text = "\n".join([
		"Weapon Base Switch Test (experiment only)",
		"group=%d/16  active_weapon_base=%d" % [_base_index + 1, active_weapon_base],
		"bases: " + " ".join(base_list),
		"",
		"body: action=%s dir=%s frame=%d/%d hum_abs_idx=%d" % [action, dir, body_frame, frames_count, int(info["absolute_index"])],
		"weapon: local_index=%d  weapon_absolute_index=%d" % [local_index, weapon_absolute_index],
		"layout: %s %s -> local %d..%d  abs %d..%d" % [action, dir, first_local, last_local, active_weapon_base + first_local, active_weapon_base + last_local],
		"png: Weapon/%s.png (%s)" % [str(weapon_absolute_index).pad_zeros(5), png_state],
		"placement=(%.1f, %.1f)  fine_tune=(%.0f, %.0f)" % [_anchor.position.x, _anchor.position.y, fine_tune_offset.x, fine_tune_offset.y],
		"",
		"F6=prev base  F7=next base (wrap)",
		"arrows=fine-tune weapon offset (also moves character; move with WASD, tap arrows briefly)  0=reset",
		"P/J/K/L/U/I/H/Y = body actions   R=recover after death",
		"rule: weapon_absolute_index = active_weapon_base + local_index",
	])
