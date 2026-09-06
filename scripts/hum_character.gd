extends CharacterBody2D


@export var appearance_id: int = 0
@export var walk_speed: float = 150.0
@export var run_speed: float = 300.0

var _sprite: AnimatedSprite2D
var _frames: SpriteFrames
var _frame_offsets: Dictionary = {}
var _current_action := "idle"
var _current_dir := "s"


func _ready() -> void:
	_sprite = $Sprite as AnimatedSprite2D
	HumFrames.set_appearance(appearance_id)
	_frames = SpriteFrames.new()
	_build_animations()
	_sprite.sprite_frames = _frames
	_sprite.play(&"idle_s")
	var offs: Array = _frame_offsets.get("idle_s", [])
	if not offs.is_empty():
		_sprite.offset = offs[0]
	_sprite.frame_changed.connect(_on_frame_changed)


func _build_animations() -> void:
	for action in HumFrames.BUILT_ACTIONS:
		var spec: Dictionary = HumFrames.HUM_ACTIONS[action]
		var fps: float = spec["fps"]
		var loop: bool = spec["loop"]
		for dir in HumFrames.DIRECTIONS:
			var local_frames: Array = spec["frames"][dir]
			var key: String = str(action) + "_" + str(dir)
			_frames.add_animation(StringName(key))
			_frames.set_animation_loop(StringName(key), loop)
			_frames.set_animation_speed(StringName(key), fps)
			var offsets: Array = []
			for i in local_frames.size():
				var abs_idx: int = HumFrames.abs_index(local_frames[i])
				_frames.add_frame(StringName(key), _load_texture(abs_idx))
				offsets.append(_load_offset(abs_idx))
			_frame_offsets[key] = offsets


func _on_frame_changed() -> void:
	var key: String = String(_sprite.animation)
	if not _frame_offsets.has(key):
		return
	var fi: int = _sprite.frame
	var offs: Array = _frame_offsets[key]
	if fi < offs.size():
		_sprite.offset = offs[fi]


func _load_texture(abs_idx: int) -> Texture2D:
	var path := HumFrames.png_path(abs_idx)
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	push_warning("Hum texture missing: %s" % path)
	return null


func _load_offset(abs_idx: int) -> Vector2:
	var path := HumFrames.placement_path(abs_idx)
	if not FileAccess.file_exists(path):
		return Vector2.ZERO
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return Vector2.ZERO
	var line_x := f.get_line().strip_edges()
	var line_y := f.get_line().strip_edges()
	f.close()
	return Vector2(float(line_x), float(line_y))


func _physics_process(_delta: float) -> void:
	var input_vec := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input_vec == Vector2.ZERO:
		_play("idle", _current_dir)
		return

	var angle := input_vec.angle()
	_current_dir = _dir_from_angle(angle)
	var running: bool = Input.is_action_pressed("run")
	var action := "run" if running else "walk"
	velocity = input_vec * (run_speed if running else walk_speed)
	move_and_slide()
	_play(action, _current_dir)


func _play(action: String, dir: String) -> void:
	if action == _current_action and dir == _current_dir:
		return
	var key := action + "_" + dir
	if not _frames.has_animation(StringName(key)):
		key = "idle_" + dir
	_current_action = action
	_current_dir = dir
	_sprite.play(StringName(key))
	var offs: Array = _frame_offsets.get(key, [])
	if not offs.is_empty():
		_sprite.offset = offs[0]


func _dir_from_angle(angle: float) -> String:
	var a := fposmod(angle, TAU)
	if a < PI / 8 or a >= 15 * PI / 8:
		return "e"
	if a < 3 * PI / 8:
		return "ne"
	if a < 5 * PI / 8:
		return "n"
	if a < 7 * PI / 8:
		return "nw"
	if a < 9 * PI / 8:
		return "w"
	if a < 11 * PI / 8:
		return "sw"
	if a < 13 * PI / 8:
		return "s"
	return "se"
