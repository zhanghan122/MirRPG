extends Node2D

# ForestStranger 运行时冒烟测试（headless 可跑）：
#   - 校验 5 动作 × 8 方向帧数与 Mon1Frames mapping 一致
#   - 逐帧校验 SpriteAnchor offset == placement (px, py)
#   - 校验 attack/struck 单次播放后回 idle、death 停在最后一帧且锁定后续动作
# 运行：Godot_v4.7.2-stable_win64_console.exe --path Z:\MirRPG --headless res://scenes/experiments/forest_stranger_smoke.tscn

var _failures: Array = []


func _ready() -> void:
	var scene := load("res://scenes/ForestStranger.tscn") as PackedScene
	if scene == null:
		push_error("SMOKE FAIL: cannot load ForestStranger.tscn")
		get_tree().quit(1)
		return
	var m: Node2D = scene.instantiate()
	add_child(m)

	var actions := Mon1Frames.monster_actions("forest_stranger")

	# 1) 帧数校验（5 动作 × 8 方向 = 40 条载入记录）
	var report: Array = m.get_load_report()
	if report.size() != 40:
		_failures.append("load report entries expected=40 actual=%d" % report.size())
	for entry in report:
		if int(entry["expected"]) != -1 and int(entry["actual"]) != int(entry["expected"]):
			var idx_strs := []
			for i in entry["indexes"]:
				idx_strs.append("%05d" % int(i))
			_failures.append("frame count %s/%s expected=%d actual=%d indexes=[%s]" % [
				str(entry["action"]), str(entry["direction"]), int(entry["expected"]), int(entry["actual"]),
				", ".join(idx_strs)])

	# 2) 逐帧 placement 校验（每个动作取 N/S/E/W 四个方向的全部帧）
	for action in Mon1Frames.action_order("forest_stranger"):
		var spec: Dictionary = actions[action]
		for dir in ["n", "s", "e", "w"]:
			var indexes: Array = (spec["frames"] as Dictionary)[dir]
			for fi in range(indexes.size()):
				m.debug_set_frame("%s_%s" % [action, dir], fi)
				var info: Dictionary = m.get_frame_info()
				var idx := int(info["source_index"])
				if idx != int(indexes[fi]):
					_failures.append("source index mismatch %s/%s frame=%d expected=%d actual=%d" % [action, dir, fi, indexes[fi], idx])
					continue
				var off: Vector2 = info["offset"]
				var p := _read_placement(idx)
				if absf(off.x - p.x) > 0.5 or absf(off.y - p.y) > 0.5:
					_failures.append("placement mismatch %s/%s idx=%d expected=(%d,%d) actual=(%.1f,%.1f)" % [action, dir, idx, int(p.x), int(p.y), off.x, off.y])

	# 3) 行为校验：attack/struck 单次播放后回 idle
	m.set_direction("s")
	m.play_attack()
	await get_tree().create_timer(1.0).timeout
	if m.get_frame_info()["action"] != "idle":
		_failures.append("after attack expected action=idle, got=%s" % str(m.get_frame_info()["action"]))
	m.play_struck()
	await get_tree().create_timer(0.6).timeout
	if m.get_frame_info()["action"] != "idle":
		_failures.append("after struck expected action=idle, got=%s" % str(m.get_frame_info()["action"]))

	# 4) death：停在最后一帧，且后续动作被锁定
	m.play_death()
	await get_tree().create_timer(1.2).timeout
	var info: Dictionary = m.get_frame_info()
	if not bool(info["dead"]):
		_failures.append("after death expected dead=true")
	if int(info["godot_frame"]) != 3:
		_failures.append("death should stay on last frame (idx=3), got=%d" % int(info["godot_frame"]))
	m.play_idle()
	await get_tree().create_timer(0.2).timeout
	if m.get_frame_info()["action"] != "death":
		_failures.append("after death, play_idle must be ignored")

	if _failures.is_empty():
		print("SMOKE PASS: all checks OK (40 animations, placements, behavior)")
		get_tree().quit(0)
	else:
		for f in _failures:
			push_error("SMOKE FAIL: " + str(f))
		print("SMOKE FAILURES: %d" % _failures.size())
		get_tree().quit(1)


func _read_placement(idx: int) -> Vector2:
	var path := Mon1Frames.placement_path(idx)
	if not FileAccess.file_exists(path):
		return Vector2.ZERO
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return Vector2.ZERO
	var lx := f.get_line().strip_edges()
	var ly := f.get_line().strip_edges()
	f.close()
	if lx.is_empty() or ly.is_empty():
		return Vector2.ZERO
	return Vector2(float(lx.split(",")[0]), float(ly.split(",")[0]))
