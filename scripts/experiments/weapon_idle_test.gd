extends Node2D

# ============================================================
# Weapon experiment: Idle + Walk (verified, frozen) + Run (user-verified, frozen).
# No attack/cast/death.
# The stable Hum character is NOT modified by this script; it is
# instantiated and read via get_frame_info() only.
#
# Required structure (verified in weapon_idle_test.tscn):
#   Player (CharacterBody2D, stable hum_character)
#   ├── SpriteAnchor            <- body placement applied here (hum_character.gd)
#   │    └── AnimatedSprite2D
#   └── WeaponAnchor            <- weapon placement applied HERE, exactly once
#        └── WeaponSprite       <- position/offset = ZERO, centered=false, flip_h=false
#
# Frame sync rule: body Godot frame N -> weapon direction frame N.
# Never compute a weapon index as 31200 + body local_index.
# ============================================================

const IDLE_CANDIDATE_A := {
	"n": [31200, 31201, 31202, 31203],
	"ne": [31208, 31209, 31210, 31211],
	"e": [31216, 31217, 31218, 31219],
	"se": [31224, 31225, 31226, 31227],
	"s": [31232, 31233, 31234, 31235],
	"sw": [31240, 31241, 31242, 31243],
	"w": [31248, 31249, 31250, 31251],
	"nw": [31256, 31257, 31258, 31259],
}

const IDLE_CANDIDATE_B := {
	"n": [31200, 31201, 31202, 31203],
	"ne": [31204, 31205, 31206, 31207],
	"e": [31208, 31209, 31210, 31211],
	"se": [31212, 31213, 31214, 31215],
	"s": [31216, 31217, 31218, 31219],
	"sw": [31220, 31221, 31222, 31223],
	"w": [31224, 31225, 31226, 31227],
	"nw": [31228, 31229, 31230, 31231],
}

# Walk candidate A: Hum-style 8-index slots, first 6 frames valid per direction.
const WALK_CANDIDATE_A := {
	"n": [31264, 31265, 31266, 31267, 31268, 31269],
	"ne": [31272, 31273, 31274, 31275, 31276, 31277],
	"e": [31280, 31281, 31282, 31283, 31284, 31285],
	"se": [31288, 31289, 31290, 31291, 31292, 31293],
	"s": [31296, 31297, 31298, 31299, 31300, 31301],
	"sw": [31304, 31305, 31306, 31307, 31308, 31309],
	"w": [31312, 31313, 31314, 31315, 31316, 31317],
	"nw": [31320, 31321, 31322, 31323, 31324, 31325],
}

# Walk candidate B: consecutive 6 frames per direction.
const WALK_CANDIDATE_B := {
	"n": [31264, 31265, 31266, 31267, 31268, 31269],
	"ne": [31270, 31271, 31272, 31273, 31274, 31275],
	"e": [31276, 31277, 31278, 31279, 31280, 31281],
	"se": [31282, 31283, 31284, 31285, 31286, 31287],
	"s": [31288, 31289, 31290, 31291, 31292, 31293],
	"sw": [31294, 31295, 31296, 31297, 31298, 31299],
	"w": [31300, 31301, 31302, 31303, 31304, 31305],
	"nw": [31306, 31307, 31308, 31309, 31310, 31311],
}

# Run (31328-31389): same 8-index slot layout as idle/walk, first 6 frames
# valid per direction. User-verified live; this is the frozen weapon run rule.
const RUN_FRAMES := {
	"n": [31328, 31329, 31330, 31331, 31332, 31333],
	"ne": [31336, 31337, 31338, 31339, 31340, 31341],
	"e": [31344, 31345, 31346, 31347, 31348, 31349],
	"se": [31352, 31353, 31354, 31355, 31356, 31357],
	"s": [31360, 31361, 31362, 31363, 31364, 31365],
	"sw": [31368, 31369, 31370, 31371, 31372, 31373],
	"w": [31376, 31377, 31378, 31379, 31380, 31381],
	"nw": [31384, 31385, 31386, 31387, 31388, 31389],
}

var weapon_enabled := true
var idle_candidate_name := "A"
var walk_candidate_name := "A"
# Experiment-only manual fine-tune. Default ZERO. Never written to the Hum
# character or to any Placement TXT file.
var weapon_test_adjustment := Vector2.ZERO

var _player
var _body_anchor: Node2D
# CanvasItem (not Sprite2D): in Godot 4.7 AnimatedSprite2D no longer inherits
# from Sprite2D, but z_index lives on CanvasItem.
var _body_sprite: CanvasItem
var _anchor: Node2D
var _sprite: Sprite2D
var _hud: Label

var _weapon_dir := ""
var _current_abs_idx := -1
# HUD-only mirrors of the current run frame indices (-1 when not running).
var _hud_run_body_frame := -1
var _hud_weapon_run_frame := -1
var _last_diag_anim := ""
var _last_diag_key := ""

var _png_exists: Dictionary = {}
var _textures: Dictionary = {}
var _placements: Dictionary = {}


func _ready() -> void:
	_player = $Player
	_body_anchor = $Player/SpriteAnchor
	_body_sprite = $Player/SpriteAnchor/AnimatedSprite2D
	_anchor = $Player/WeaponAnchor
	_sprite = $Player/WeaponAnchor/WeaponSprite
	_hud = $HudCanvasLayer/HudLabel
	_preload_weapon_data()


func _process(_delta: float) -> void:
	var info: Dictionary = _player.get_frame_info()
	var anim := String(info["animation_name"])
	var dir := "s"
	if "_" in anim:
		dir = anim.get_slice("_", 1)
	var action := ""
	if "_" in anim:
		action = anim.get_slice("_", 0)
	var body_frame := int(info["godot_frame"])
	if body_frame < 0:
		body_frame = 0
	if dir != _weapon_dir:
		_weapon_dir = dir
		_update_weapon_layer(dir)

	var frames: Array
	if action == "walk":
		frames = _walk_candidate().get(dir, [])
	elif action == "run":
		frames = RUN_FRAMES.get(dir, [])
	else:
		# idle and all other actions (pose/attack/death...): keep showing
		# the current direction's idle weapon frames (existing behavior).
		frames = _idle_candidate().get(dir, [])

	var frame_idx := 0
	if not frames.is_empty():
		# Same-index sync for all actions: body frame N -> weapon frame N.
		frame_idx = body_frame % frames.size()
	if action == "run":
		_hud_run_body_frame = body_frame
		_hud_weapon_run_frame = frame_idx if not frames.is_empty() else -1
	else:
		_hud_run_body_frame = -1
		_hud_weapon_run_frame = -1
	_apply_frame(frames, frame_idx)
	_walk_e_diagnostic(anim, body_frame, info)
	_update_hud(anim, dir, body_frame, info)


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_F5:
			weapon_enabled = not weapon_enabled
		KEY_1:
			idle_candidate_name = "A"
		KEY_2:
			idle_candidate_name = "B"
		KEY_F7:
			walk_candidate_name = "A"
		KEY_F8:
			walk_candidate_name = "B"
		KEY_LEFT:
			weapon_test_adjustment.x -= 1.0
		KEY_RIGHT:
			weapon_test_adjustment.x += 1.0
		KEY_UP:
			weapon_test_adjustment.y -= 1.0
		KEY_DOWN:
			weapon_test_adjustment.y += 1.0
		KEY_0, KEY_KP_0:
			weapon_test_adjustment = Vector2.ZERO


func _idle_candidate() -> Dictionary:
	return IDLE_CANDIDATE_A if idle_candidate_name == "A" else IDLE_CANDIDATE_B


func _walk_candidate() -> Dictionary:
	return WALK_CANDIDATE_A if walk_candidate_name == "A" else WALK_CANDIDATE_B


# Front/back occlusion between body and weapon. Called only when the direction
# changes (never per animation frame). Positions/placements are untouched.
func _update_weapon_layer(direction: String) -> void:
	if direction in ["w", "nw", "sw"]:
		# Body in front of the weapon: the body occludes part of it.
		_sprite.z_index = _body_sprite.z_index - 1
	else:
		# Weapon in front of the body.
		_sprite.z_index = _body_sprite.z_index + 1


func _apply_frame(frames: Array, frame_idx: int) -> void:
	if frames.is_empty() or frame_idx >= frames.size():
		_current_abs_idx = -1
		_sprite.texture = null
		_sprite.visible = false
		return
	var abs_idx := int(frames[frame_idx])
	_current_abs_idx = abs_idx
	if not _png_exists.get(abs_idx, false):
		# Missing PNG: hide this frame. Do NOT keep the previous frame's texture.
		_sprite.texture = null
		_sprite.visible = false
		return
	var placement: Vector2 = _placements.get(abs_idx, Vector2.ZERO)
	# Placement is applied exactly once, relative to the character logical origin.
	_anchor.position = placement + weapon_test_adjustment
	_sprite.texture = _textures.get(abs_idx)
	_sprite.visible = weapon_enabled


func _walk_e_diagnostic(anim: String, body_frame: int, info: Dictionary) -> void:
	if anim != "walk_e":
		_last_diag_anim = anim
		return
	if _last_diag_anim != anim:
		_last_diag_key = ""
	_last_diag_anim = anim
	var key := "%d" % body_frame
	if _last_diag_key == key:
		return
	_last_diag_key = key
	var plc: Vector2 = _placements.get(_current_abs_idx, Vector2.ZERO)
	print("[walk_e] body_frame=%d  body_abs_idx=%d  body_placement=(%.1f, %.1f)" % [
		body_frame, int(info["absolute_index"]), _body_anchor.position.x, _body_anchor.position.y])
	print("[walk_e]   weapon_idx=%d  weapon_placement=(%.1f, %.1f)  WeaponAnchor.pos=(%.1f, %.1f)" % [
		_current_abs_idx, plc.x, plc.y, _anchor.position.x, _anchor.position.y])
	print("[walk_e]   WeaponAnchor.global=(%.1f, %.1f)  WeaponSprite.global=(%.1f, %.1f)" % [
		_anchor.global_position.x, _anchor.global_position.y,
		_sprite.global_position.x, _sprite.global_position.y])


func _preload_weapon_data() -> void:
	for cand in [IDLE_CANDIDATE_A, IDLE_CANDIDATE_B, WALK_CANDIDATE_A, WALK_CANDIDATE_B, RUN_FRAMES]:
		for dir in cand:
			for abs_idx in cand[dir]:
				var idx := int(abs_idx)
				if not _png_exists.has(idx):
					var path := "res://Weapon/%05d.png" % idx
					_png_exists[idx] = ResourceLoader.exists(path)
					if _png_exists[idx]:
						_textures[idx] = load(path) as Texture2D
				if not _placements.has(idx):
					_placements[idx] = _read_placement(idx)


func _read_placement(abs_idx: int) -> Vector2:
	var path := "res://Weapon/Placements/%05d.txt" % abs_idx
	if not FileAccess.file_exists(path):
		return Vector2.ZERO
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return Vector2.ZERO
	var line_x := f.get_line().strip_edges()
	var line_y := f.get_line().strip_edges()
	f.close()
	if line_x.is_empty() or line_y.is_empty():
		return Vector2.ZERO
	return Vector2(float(line_x.split(",")[0]), float(line_y.split(",")[0]))


func _update_hud(anim: String, dir: String, body_frame: int, info: Dictionary) -> void:
	var plc: Vector2 = _placements.get(_current_abs_idx, Vector2.ZERO)
	_hud.text = "\n".join([
		"Weapon Test  F5=show/hide  1/2=idle cand A/B  F7/F8=walk cand A/B",
		"fine-tune: arrows=+/-1px (arrows also move the character, tap briefly)  0=reset adjustment",
		"anim=%s  dir=%s  body_frame=%d  body_abs_idx=%d" % [anim, dir, body_frame, int(info["absolute_index"])],
		"current_direction=%s  body_z_index=%d  weapon_z_index=%d  weapon_layer=%s" % [
			dir, _body_sprite.z_index, _sprite.z_index,
			"behind_body" if dir in ["w", "nw", "sw"] else "in_front_of_body"],
		"Run frames=31328-31389 (verified)  body_run_frame=%d  weapon_run_frame=%d  weapon_abs_idx=%d" % [
			_hud_run_body_frame, _hud_weapon_run_frame, _current_abs_idx],
		"weapon idx=%d  png exists=%s" % [_current_abs_idx, str(_png_exists.get(_current_abs_idx, false)) if _current_abs_idx >= 0 else "n/a"],
		"Raw Weapon Placement = (%.1f, %.1f)" % [plc.x, plc.y],
		"Test Adjustment      = (%.1f, %.1f)" % [weapon_test_adjustment.x, weapon_test_adjustment.y],
		"Final Weapon Position= (%.1f, %.1f)  [WeaponAnchor.position]" % [_anchor.position.x, _anchor.position.y],
		"WeaponSprite.position=(%.1f, %.1f)  centered=false flip_h=false" % [_sprite.position.x, _sprite.position.y],
		"WeaponAnchor parent path = %s" % str(_anchor.get_path()),
	])
