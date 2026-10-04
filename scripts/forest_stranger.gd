extends Node2D

# 森林怪人怪物动画控制器（播放代码；mapping 数据见 Mon1Frames / MON1_FRAME_RULES.md）。
# 节点结构：self -> SpriteAnchor(Node2D) -> AnimatedSprite2D(centered=false)。
# Placement 预加载并缓存，frame_changed 时按原始索引应用到 SpriteAnchor.position。
# 非循环动作通过 animation_finished 结束，禁止固定 Timer；死亡后停留最后一帧（或 disappear）。

@export var monster_id := "forest_stranger"
@export var initial_direction := "s"

var dead := false
var action_locked := false
var current_action := "idle"
var last_direction: String = "s"

var _sprite: AnimatedSprite2D
var _anchor: Node2D
var _debug_label: Label
var _frames: SpriteFrames
var _animation_source_indices: Dictionary = {}
var _placement_cache: Dictionary = {}
var _missing_warned: Dictionary = {}
# 载入报告：[{action, direction, expected, actual, indexes:[...]}]
var _load_report: Array = []


func _ready() -> void:
	_anchor = $SpriteAnchor
	_sprite = $SpriteAnchor/AnimatedSprite2D
	var dbg := get_node_or_null("DebugCanvasLayer/DebugLabel")
	if dbg is Label:
		_debug_label = dbg
	last_direction = initial_direction if Mon1Frames.DIRECTIONS.has(initial_direction) else "s"
	_frames = SpriteFrames.new()
	_rebuild_sprite_frames()
	_preload_placements()
	_report_load_counts()
	_sprite.sprite_frames = _frames
	_sprite.frame_changed.connect(_on_frame_changed)
	_sprite.animation_finished.connect(_on_animation_finished)
	_play("idle_" + last_direction)


func play_idle() -> void:
	_start_action("idle")


func play_walk() -> void:
	_start_action("walk")


func play_attack() -> void:
	_start_action("attack")


func play_struck() -> void:
	_start_action("struck")


func play_death() -> void:
	_start_action("death")


# 方向变化时切换到对应方向动画（保持当前动作；死亡后忽略）。
func set_direction(dir: String) -> void:
	if dead or not Mon1Frames.DIRECTIONS.has(dir):
		return
	last_direction = dir
	_play("%s_%s" % [current_action, last_direction])


func cycle_direction(step: int) -> void:
	var dirs := Mon1Frames.DIRECTIONS
	var i := (dirs.find(last_direction) + step) % dirs.size()
	if i < 0:
		i += dirs.size()
	set_direction(dirs[i])


# 测试用：stay_last_frame 死亡后恢复 idle。disappear 怪物已被移除，需由外部重新实例化。
func recover() -> void:
	if not dead:
		return
	dead = false
	action_locked = false
	current_action = "idle"
	_play("idle_" + last_direction)


func get_frame_info() -> Dictionary:
	var key := String(_sprite.animation) if _sprite != null else ""
	var src: Array = _animation_source_indices.get(key, [])
	var fi := int(_sprite.frame) if _sprite != null else -1
	var abs_idx := -1
	if not src.is_empty() and fi >= 0 and fi < src.size():
		abs_idx = int(src[fi])
	return {
		"monster_id": monster_id,
		"display_name": Mon1Frames.display_name(monster_id),
		"action": current_action,
		"direction": last_direction,
		"animation_name": key,
		"godot_frame": fi,
		"frame_count": _frames.get_frame_count(StringName(key)) if _sprite != null else 0,
		"source_index": abs_idx,
		"offset": _anchor.position if _anchor != null else Vector2.ZERO,
		"dead": dead,
		"action_locked": action_locked,
		"playing": _sprite != null and _sprite.is_playing(),
	}


func get_load_report() -> Array:
	return _load_report.duplicate(true)


# 测试钩子：直接跳到指定动画帧并应用该帧 placement（用于逐帧校验）。
func debug_set_frame(anim_name: String, frame: int) -> void:
	var anim := StringName(anim_name)
	if not _frames.has_animation(anim):
		return
	var count := _frames.get_frame_count(anim)
	_sprite.stop()
	_sprite.animation = anim
	_sprite.frame = clampi(frame, 0, max(0, count - 1))
	_apply_current_offset()


func get_anchor_position() -> Vector2:
	return _anchor.position if _anchor != null else Vector2.ZERO


func _start_action(action: String) -> void:
	if dead:
		return
	var actions := Mon1Frames.monster_actions(monster_id)
	if not actions.has(action):
		push_error("ForestStranger: monster '%s' has no action '%s'" % [monster_id, action])
		return
	current_action = action
	action_locked = true
	if action == "death":
		if not actions.has("death"):
			# 无死亡动画（如未来守卫）：不播放假帧，直接消失。
			_apply_disappear()
			return
		_play("death_" + last_direction)
		return
	var spec2: Dictionary = actions[action]
	action_locked = not bool(spec2["loop"])
	_play("%s_%s" % [action, last_direction])


func _on_animation_finished() -> void:
	if current_action == "death":
		_finish_death()
		return
	# attack / struck 单次播放结束：回到同方向 idle。
	action_locked = false
	current_action = "idle"
	_play("idle_" + last_direction)


func _finish_death() -> void:
	dead = true
	if Mon1Frames.death_behavior(monster_id) == "disappear":
		_apply_disappear()
	# stay_last_frame：停留在最后一帧，不返回 idle，不循环。


func _apply_disappear() -> void:
	dead = true
	action_locked = true
	if _sprite != null and _sprite.is_playing():
		_sprite.stop()
	visible = false
	queue_free()


func _play(anim_name: String) -> void:
	if not _frames.has_animation(StringName(anim_name)):
		push_error("ForestStranger: missing animation '%s', falling back to idle_%s" % [anim_name, last_direction])
		anim_name = "idle_" + last_direction
	if String(_sprite.animation) == anim_name and _sprite.is_playing():
		return
	_sprite.play(StringName(anim_name))
	_apply_current_offset()


func _rebuild_sprite_frames() -> void:
	var actions := Mon1Frames.monster_actions(monster_id)
	for action in Mon1Frames.action_order(monster_id):
		if not actions.has(action):
			continue
		var spec: Dictionary = actions[action]
		var fps: float = float(spec["fps"])
		var loop: bool = bool(spec["loop"])
		var expected_per_dir := int(spec.get("frames_per_direction", -1))
		for dir in Mon1Frames.DIRECTIONS:
			var local_frames: Array = (spec["frames"] as Dictionary)[dir]
			var key := "%s_%s" % [action, dir]
			_frames.add_animation(StringName(key))
			_frames.set_animation_loop(StringName(key), loop)
			_frames.set_animation_speed(StringName(key), fps)
			var src: Array = []
			for idx in local_frames:
				var abs_idx := int(idx)
				var tex := _load_texture(abs_idx)
				if tex == null:
					continue
				_frames.add_frame(StringName(key), tex)
				src.append(abs_idx)
			_load_report.append({
				"action": action, "direction": dir,
				"expected": expected_per_dir, "actual": src.size(),
				"indexes": src.duplicate(),
			})
			_animation_source_indices[key] = src


func _preload_placements() -> void:
	for key in _animation_source_indices.keys():
		var src: Array = _animation_source_indices[key]
		for idx in src:
			var abs_idx := int(idx)
			if not _placement_cache.has(abs_idx):
				_placement_cache[abs_idx] = _read_placement(abs_idx)


func _apply_current_offset() -> void:
	var key := String(_sprite.animation)
	if not _animation_source_indices.has(key):
		return
	var src: Array = _animation_source_indices[key]
	var fi := int(_sprite.frame)
	if fi < 0 or fi >= src.size():
		return
	var abs_idx := int(src[fi])
	_anchor.position = _placement_cache.get(abs_idx, Vector2.ZERO)


func _on_frame_changed() -> void:
	_apply_current_offset()


func _report_load_counts() -> void:
	print("=== ForestStranger load report (monster=%s %s) ===" % [monster_id, Mon1Frames.display_name(monster_id)])
	var mismatch := false
	for entry in _load_report:
		var ok := int(entry["expected"]) == -1 or int(entry["actual"]) == int(entry["expected"])
		if not ok:
			mismatch = true
		print("  %-7s dir=%-2s expected=%d actual=%d indexes=[%s] %s" % [
			str(entry["action"]), str(entry["direction"]), int(entry["expected"]), int(entry["actual"]),
			", ".join(_format_indexes(entry["indexes"])), "OK" if ok else "MISMATCH"])
	if mismatch:
		push_error("ForestStranger: frame count mismatch detected, see diagnostic file")
		_write_diag_file()


func _write_diag_file() -> void:
	var dir_path := "res://data/diagnostics"
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(dir_path)):
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir_path))
	var path := ProjectSettings.globalize_path("res://data/diagnostics/forest_stranger_load_report.txt")
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("ForestStranger: cannot write diagnostic file %s" % path)
		return
	f.store_line("monster_id=%s display_name=%s" % [monster_id, Mon1Frames.display_name(monster_id)])
	for entry in _load_report:
		f.store_line("%s|%s|expected=%d|actual=%d|indexes=[%s]" % [
			str(entry["action"]), str(entry["direction"]), int(entry["expected"]), int(entry["actual"]),
			", ".join(_format_indexes(entry["indexes"]))])
	f.close()


func _format_indexes(indexes: Array) -> Array:
	var out := []
	for idx in indexes:
		out.append("%05d" % int(idx))
	return out


func _load_texture(abs_idx: int) -> Texture2D:
	var path := Mon1Frames.png_path(abs_idx)
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	if not _missing_warned.has(path):
		_missing_warned[path] = true
		push_warning("Mon1 texture missing, frame skipped: %s" % path)
	return null


func _read_placement(abs_idx: int) -> Vector2:
	var path := Mon1Frames.placement_path(abs_idx)
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


func _build_diag_text() -> String:
	var info := get_frame_info()
	return "\n".join([
		str(info["display_name"]),
		"action=%s  dir=%s  locked=%s  dead=%s" % [str(info["action"]), str(info["direction"]), str(bool(info["action_locked"])), str(bool(info["dead"]))],
		"anim=%s  frame=%d  source_index=%05d" % [str(info["animation_name"]), int(info["godot_frame"]), int(info["source_index"])],
		"offset=(%.1f, %.1f)" % [float(info["offset"].x), float(info["offset"].y)],
	])


func _process(_delta: float) -> void:
	if _debug_label != null and _debug_label.visible:
		_debug_label.text = _build_diag_text()
