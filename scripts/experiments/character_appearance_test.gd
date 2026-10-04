extends Node2D

# 人物外观测试：场景中始终只有一个 Hum 人物 + Hair Group A (1200) 同步。
# 身体帧结构唯一事实来源：HUM_FRAME_RULES.md / HumFrames.HUM_ACTIONS。
# Hair 同步逻辑直接复制已验证的 hair_full_mapping_test 实现（只读身体 animation/frame，绝不写回）。
# PageDown/PageUp/Home/End 切换外观预设；F5 显示/隐藏 Hair 层。

const HAIR_BASE := 1200
const APPEARANCE_COUNT := 24

var appearance_number := 1
var hair_enabled := true

var _body: CharacterBody2D
var _body_sprite: AnimatedSprite2D
var _hair_anchor: Node2D
var _hair_sprite: Sprite2D
var _hud_label: Label

var _scene_cache: Dictionary = {}
var _placement_cache: Dictionary = {}
var _texture_cache: Dictionary = {}
var _missing_warned: Dictionary = {}


func _ready() -> void:
	_hud_label = $HudCanvasLayer/HudLabel
	if _hud_label == null:
		push_error("CHARACTER APPEARANCE TEST: node path error, missing hud")
		return
	_preload_hair_resources()
	_switch_appearance(1)
	print_startup_report()


func _process(_delta: float) -> void:
	if _body_sprite == null or _hud_label == null:
		return
	var info := _sync_hair_to_body()
	_hud_label.text = _build_hud_text(info)


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_F5:
			hair_enabled = not hair_enabled
			if _hair_anchor != null:
				_hair_anchor.visible = hair_enabled
		KEY_PAGEDOWN:
			var next_number := appearance_number + 1
			if next_number > APPEARANCE_COUNT:
				next_number = 1
			_switch_appearance(next_number)
		KEY_PAGEUP:
			var prev_number := appearance_number - 1
			if prev_number < 1:
				prev_number = APPEARANCE_COUNT
			_switch_appearance(prev_number)
		KEY_HOME:
			_switch_appearance(1)
		KEY_END:
			_switch_appearance(APPEARANCE_COUNT)


func _scene_path_for(number: int) -> String:
	return "res://scenes/characters/presets/HumAppearance%02d.tscn" % number


func _switch_appearance(new_number: int) -> void:
	if new_number < 1 or new_number > APPEARANCE_COUNT:
		return
	if new_number == appearance_number and _body != null:
		return
	var saved_pos := Vector2.ZERO
	var saved_dir := "s"
	if _body != null:
		saved_pos = _body.global_position
		saved_dir = String(_body.last_direction)
		_body.free()
		_body = null
		_hair_anchor = null
		_hair_sprite = null

	var scene_path := _scene_path_for(new_number)
	if not _scene_cache.has(scene_path):
		if not ResourceLoader.exists(scene_path):
			push_error("CHARACTER APPEARANCE TEST: preset scene missing: %s" % scene_path)
			return
		_scene_cache[scene_path] = load(scene_path) as PackedScene
	var packed: PackedScene = _scene_cache.get(scene_path)
	if packed == null:
		push_error("CHARACTER APPEARANCE TEST: failed to load preset scene: %s" % scene_path)
		return

	var new_body := packed.instantiate() as CharacterBody2D
	new_body.name = "HumCharacter"
	new_body.last_direction = saved_dir
	add_child(new_body)
	new_body.global_position = saved_pos
	appearance_number = new_number

	_body = new_body
	_body_sprite = _body.get_node("SpriteAnchor/AnimatedSprite2D") as AnimatedSprite2D
	if _body_sprite == null:
		push_error("CHARACTER APPEARANCE TEST: node path error, missing body sprite in %s" % scene_path)
		return
	_attach_hair()


func _attach_hair() -> void:
	var anchor := Node2D.new()
	anchor.name = "HairAnchor"
	_body.add_child(anchor)

	var sprite := Sprite2D.new()
	sprite.name = "HairSprite"
	sprite.centered = false
	sprite.position = Vector2.ZERO
	sprite.offset = Vector2.ZERO
	sprite.flip_h = false
	sprite.visible = true
	sprite.modulate = Color.WHITE
	sprite.scale = Vector2.ONE
	anchor.add_child(sprite)

	sprite.z_index = _body_sprite.z_index + 1
	anchor.visible = hair_enabled

	_hair_anchor = anchor
	_hair_sprite = sprite


func _sync_hair_to_body() -> Dictionary:
	var anim_name := String(_body_sprite.animation)
	var body_frame := int(_body_sprite.frame)
	var action := ""
	var direction := ""
	if anim_name != "":
		var us := anim_name.rfind("_")
		if us > 0:
			direction = anim_name.substr(us + 1)
			action = anim_name.substr(0, us)
	var local_index := -1
	if action != "" and direction != "" \
			and HumFrames.HUM_ACTIONS.has(action):
		var frames_dict: Dictionary = HumFrames.HUM_ACTIONS[action]["frames"]
		if frames_dict.has(direction):
			var frames: Array = frames_dict[direction]
			if body_frame >= 0 and body_frame < frames.size():
				local_index = int(frames[body_frame])
	var abs_idx := -1
	var png_exists := false
	var placement_exists := false
	var placement := Vector2.ZERO
	var tex: Texture2D = null
	if local_index >= 0:
		abs_idx = HAIR_BASE + local_index
		tex = _texture_cache.get(abs_idx)
		png_exists = tex != null
		placement_exists = _placement_cache.has(abs_idx)
		placement = _placement_cache.get(abs_idx, Vector2.ZERO)
	if tex == null:
		_hair_sprite.texture = null
		_hair_sprite.visible = false
	else:
		_hair_sprite.texture = tex
		_hair_anchor.position = placement
		_hair_sprite.visible = true
	return {
		"body_animation": anim_name,
		"body_frame": body_frame,
		"current_action": action,
		"current_direction": direction,
		"local_index": local_index,
		"hair_absolute_index": abs_idx,
		"hair_png_exists": png_exists,
		"hair_placement_exists": placement_exists,
		"hair_placement": placement,
	}


func _preload_hair_resources() -> void:
	for action in HumFrames.ALL_ACTIONS:
		var spec: Dictionary = HumFrames.HUM_ACTIONS[action]
		for dir in HumFrames.DIRECTIONS:
			var local_frames: Array = spec["frames"][dir]
			for li in local_frames:
				var abs_idx := HAIR_BASE + int(li)
				if not _placement_cache.has(abs_idx):
					_placement_cache[abs_idx] = _read_hair_placement(abs_idx)
				if not _texture_cache.has(abs_idx):
					_texture_cache[abs_idx] = _load_hair_texture(abs_idx)


func _load_hair_texture(abs_idx: int) -> Texture2D:
	var path := "res://Hair/%05d.png" % abs_idx
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	if not _missing_warned.has("png:" + path):
		_missing_warned["png:" + path] = true
		push_warning("Hair texture missing: %s" % path)
	return null


func _read_hair_placement(abs_idx: int) -> Vector2:
	var path := "res://Hair/Placements/%05d.txt" % abs_idx
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


func _build_hud_text(info: Dictionary) -> String:
	return "\n".join([
		"CHARACTER APPEARANCE TEST",
		"appearance_number=%d/%d" % [appearance_number, APPEARANCE_COUNT],
		"appearance_scene_path=%s" % _scene_path_for(appearance_number),
		"hair_base=%d" % HAIR_BASE,
		"hair_enabled=%s" % str(hair_enabled),
		"body_animation=%s" % str(info["body_animation"]),
		"hair_absolute_index=%d" % int(info["hair_absolute_index"]),
	])


func print_startup_report() -> void:
	var png_count := 0
	for abs_idx in _texture_cache.keys():
		if _texture_cache[abs_idx] != null:
			png_count += 1
	print("CHARACTER APPEARANCE TEST")
	print("appearance_number=%d/%d" % [appearance_number, APPEARANCE_COUNT])
	print("appearance_scene_path=%s" % _scene_path_for(appearance_number))
	print("hair_base=%d" % HAIR_BASE)
	print("valid_frames_expected=416")
	print("textures_loaded=%d/%d" % [png_count, _texture_cache.size()])
	print("placements_cached=%d" % _placement_cache.size())
	if _body_sprite != null and _hair_sprite != null:
		print("body_z_index=%d  hair_z_index=%d" % [_body_sprite.z_index, _hair_sprite.z_index])
