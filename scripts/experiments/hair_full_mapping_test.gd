extends Node2D

# Hair 完整 600 索引动作同步实验（独立场景，不复用旧 hair_movement_test / hair_single_frame_test）。
# 帧结构唯一事实来源：HUM_FRAME_RULES.md / HumFrames.HUM_ACTIONS。
# 本脚本只读取身体当前 animation/frame，绝不写回身体任何状态。

const HAIR_BASE := 1200

var hair_enabled := true

var _body: CharacterBody2D
var _body_sprite: AnimatedSprite2D
var _hair_anchor: Node2D
var _hair_sprite: Sprite2D
var _hud_label: Label

var _placement_cache: Dictionary = {}
var _texture_cache: Dictionary = {}
var _missing_warned: Dictionary = {}


func _ready() -> void:
	_body = $StableHumCharacter
	_body_sprite = $StableHumCharacter/SpriteAnchor/AnimatedSprite2D
	_hair_anchor = $StableHumCharacter/HairAnchor
	_hair_sprite = $StableHumCharacter/HairAnchor/HairSprite
	_hud_label = $HudCanvasLayer/HudLabel
	if _body == null or _body_sprite == null or _hair_anchor == null \
			or _hair_sprite == null or _hud_label == null:
		push_error("HAIR FULL MAPPING TEST: node path error, missing body/sprite/anchor/hud")
		return
	_hair_sprite.z_index = _body_sprite.z_index + 1
	_preload_hair_resources()
	print_startup_report()


func _process(_delta: float) -> void:
	if _hair_sprite == null or _hud_label == null:
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
	var placement: Vector2 = info["hair_placement"]
	var anchor_pos := _hair_anchor.position if _hair_anchor != null else Vector2.ZERO
	return "\n".join([
		"HAIR FULL MAPPING TEST",
		"hair_enabled=%s" % str(hair_enabled),
		"hair_base=%d" % HAIR_BASE,
		"body_animation=%s  body_frame=%d" % [str(info["body_animation"]), int(info["body_frame"])],
		"current_action=%s  current_direction=%s" % [str(info["current_action"]), str(info["current_direction"])],
		"local_index=%d  hair_absolute_index=%d" % [int(info["local_index"]), int(info["hair_absolute_index"])],
		"hair_png_exists=%s  hair_placement_exists=%s" % [str(info["hair_png_exists"]), str(info["hair_placement_exists"])],
		"hair_placement=(%.1f, %.1f)" % [placement.x, placement.y],
		"HairAnchor.position=(%.1f, %.1f)" % [anchor_pos.x, anchor_pos.y],
		"HairSprite.visible=%s  z_index=%d" % [str(_hair_sprite.visible), _hair_sprite.z_index],
	])


func print_startup_report() -> void:
	var png_count := 0
	for abs_idx in _texture_cache.keys():
		if _texture_cache[abs_idx] != null:
			png_count += 1
	print("HAIR FULL MAPPING TEST")
	print("hair_base=%d" % HAIR_BASE)
	print("valid_frames_expected=416")
	print("textures_loaded=%d/%d" % [png_count, _texture_cache.size()])
	print("placements_cached=%d" % _placement_cache.size())
	print("body_z_index=%d  hair_z_index=%d" % [_body_sprite.z_index, _hair_sprite.z_index])
