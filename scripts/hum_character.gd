extends CharacterBody2D

const WALK_SPEED := 200.0
const RUN_SPEED := 360.0

const _DIR_MAP := {
	"0,-1": "n", "1,-1": "ne", "1,0": "e", "1,1": "se",
	"0,1": "s", "-1,1": "sw", "-1,0": "w", "-1,-1": "nw",
}

@export var appearance_id: int = 0
@export var preset_name: String = ""
@export var weapon_enabled: bool = false

var appearance_base: int = 0

var action_locked := false
var dead := false
var current_action := "idle"
var last_direction := "s"

var _sprite: AnimatedSprite2D
var _anchor: Node2D
var _debug_label: Label
var _frames: SpriteFrames
var _animation_source_indices: Dictionary = {}
var _placement_cache: Dictionary = {}
var _missing_warned: Dictionary = {}
var _debug_override := false


func _ready() -> void:
	_anchor = $SpriteAnchor
	_sprite = $SpriteAnchor/AnimatedSprite2D
	_debug_label = $DebugCanvasLayer/DebugLabel
	HumFrames.set_appearance(appearance_id)
	appearance_base = appearance_id * 600
	_frames = SpriteFrames.new()
	_rebuild_sprite_frames()
	_preload_placements()
	_sprite.sprite_frames = _frames
	_sprite.frame_changed.connect(_on_frame_changed)
	_sprite.animation_finished.connect(_on_animation_finished)
	_play("idle_" + last_direction)


func _process(_delta: float) -> void:
	if _debug_label != null and _debug_label.visible:
		_debug_label.text = _build_diag_text()


func _physics_process(_delta: float) -> void:
	if dead or action_locked:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	var v := _input_dir()
	if v != Vector2.ZERO:
		_debug_override = false
		var running := _run_held()
		last_direction = _direction_from_vector(v)
		current_action = "run" if running else "walk"
		velocity = v * (RUN_SPEED if running else WALK_SPEED)
		move_and_slide()
		_play("%s_%s" % [current_action, last_direction])
		return
	velocity = Vector2.ZERO
	move_and_slide()
	if _debug_override:
		return
	if current_action != "idle":
		current_action = "idle"
		_play("idle_" + last_direction)


func play_directional_action(action_name: StringName) -> void:
	if not HumFrames.HUM_ACTIONS.has(String(action_name)):
		return
	_start_action(String(action_name))


func recover() -> void:
	if not dead:
		return
	dead = false
	action_locked = false
	current_action = "idle"
	velocity = Vector2.ZERO
	_play("idle_" + last_direction)


func get_frame_info() -> Dictionary:
	var key := String(_sprite.animation)
	var src: Array = _animation_source_indices.get(key, [])
	var fi := _sprite.frame
	var abs_idx := -1
	if not src.is_empty() and fi >= 0 and fi < src.size():
		abs_idx = appearance_base + int(src[fi])
	return {
		"preset_name": preset_name,
		"appearance_id": appearance_id,
		"appearance_base": appearance_base,
		"animation_name": key,
		"godot_frame": fi,
		"absolute_index": abs_idx,
	}


func _start_action(action: String) -> void:
	if dead or action == current_action:
		return
	_debug_override = false
	velocity = Vector2.ZERO
	action_locked = true
	current_action = action
	_play("%s_%s" % [action, last_direction])


func _force_debug(action: String) -> void:
	if dead:
		return
	action_locked = false
	_debug_override = true
	last_direction = "s"
	current_action = action
	velocity = Vector2.ZERO
	_play("%s_s" % action)


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_P:
			_start_action("pose")
		KEY_J:
			_start_action("attack_onehand")
		KEY_K:
			_start_action("attack_twohand")
		KEY_L:
			_start_action("attack_power")
		KEY_U:
			_start_action("cast")
		KEY_I:
			_start_action("dig")
		KEY_H:
			_start_action("hit")
		KEY_Y:
			_start_action("death")
		KEY_R:
			recover()
		KEY_F1:
			if _debug_label != null:
				_debug_label.visible = not _debug_label.visible
		KEY_F2:
			_force_debug("idle")
		KEY_F3:
			_force_debug("walk")
		KEY_F4:
			_force_debug("run")


func _on_frame_changed() -> void:
	_apply_current_offset()


func _on_animation_finished() -> void:
	if current_action == "death":
		dead = true
		action_locked = true
		return
	if action_locked:
		action_locked = false
	current_action = "idle"
	_play("idle_" + last_direction)


func _play(anim_name: String) -> void:
	if not _frames.has_animation(StringName(anim_name)):
		anim_name = "idle_" + last_direction
	if String(_sprite.animation) == anim_name and _sprite.is_playing():
		return
	_sprite.play(StringName(anim_name))
	_apply_current_offset()


func _rebuild_sprite_frames() -> void:
	for action in HumFrames.ALL_ACTIONS:
		var spec: Dictionary = HumFrames.HUM_ACTIONS[action]
		var fps: float = spec["fps"]
		var loop: bool = spec["loop"]
		for dir in HumFrames.DIRECTIONS:
			var local_frames: Array = spec["frames"][dir]
			var key := "%s_%s" % [action, dir]
			_frames.add_animation(StringName(key))
			_frames.set_animation_loop(StringName(key), loop)
			_frames.set_animation_speed(StringName(key), fps)
			var src: Array = []
			for li in local_frames:
				var abs_idx := appearance_base + int(li)
				var tex := _load_texture(abs_idx)
				if tex == null:
					continue
				_frames.add_frame(StringName(key), tex)
				src.append(int(li))
			_animation_source_indices[key] = src


func _preload_placements() -> void:
	for key in _animation_source_indices.keys():
		var src: Array = _animation_source_indices[key]
		for li in src:
			var abs_idx := appearance_base + int(li)
			if not _placement_cache.has(abs_idx):
				_placement_cache[abs_idx] = _read_placement(abs_idx)


func _apply_current_offset() -> void:
	var key := String(_sprite.animation)
	if not _animation_source_indices.has(key):
		return
	var src: Array = _animation_source_indices[key]
	var fi := _sprite.frame
	if fi < 0 or fi >= src.size():
		return
	var abs_idx := appearance_base + int(src[fi])
	_anchor.position = _placement_cache.get(abs_idx, Vector2.ZERO)


func _load_texture(abs_idx: int) -> Texture2D:
	var path := HumFrames.png_path(abs_idx)
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	if not _missing_warned.has(path):
		_missing_warned[path] = true
		push_warning("Hum texture missing, frame skipped: %s" % path)
	return null


func _read_placement(abs_idx: int) -> Vector2:
	var path := HumFrames.placement_path(abs_idx)
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


func _input_dir() -> Vector2:
	var v := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if v.length() > 1.0:
		v = v.normalized()
	return v


func _run_held() -> bool:
	return Input.is_action_pressed("run") or Input.is_key_pressed(KEY_SPACE)


func _direction_from_vector(v: Vector2) -> String:
	var dx := 1 if v.x > 0.5 else (-1 if v.x < -0.5 else 0)
	var dy := 1 if v.y > 0.5 else (-1 if v.y < -0.5 else 0)
	return _DIR_MAP.get("%d,%d" % [dx, dy], last_direction)


func _build_diag_text() -> String:
	var info := get_frame_info()
	var src: Array = _animation_source_indices.get(String(info["animation_name"]), [])
	return "\n".join([
		preset_name,
		"appearance_id=%d  base=%d" % [appearance_id, appearance_base],
		"action=%s  dir=%s  locked=%s  dead=%s" % [current_action, last_direction, str(action_locked), str(dead)],
		"anim=%s  frame=%d/%d  abs_idx=%d" % [info["animation_name"], info["godot_frame"], src.size(), info["absolute_index"]],
		"offset=(%.1f, %.1f)" % [_anchor.position.x, _anchor.position.y],
	])
