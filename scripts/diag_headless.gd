extends SceneTree
## Headless 诊断脚本（快速版）：只加载目标帧（walk_e/w、run_e/w），
## 打印 Placement / Offset(round) / PNG 尺寸，验证 point 4/5。
## 运行："Godot.exe" --path "Z:\MirRPG" --headless -s res://scripts/diag_headless.gd

const TARGET_ANIMS: Array[String] = ["walk_e", "walk_w", "run_e", "run_w"]


func _initialize() -> void:
	var hum_frames_script := load("res://scripts/hum_frames.gd") as GDScript
	var hum_frames = hum_frames_script.new()
	print("=== DIAG START (headless, target frames only) ===")
	for anim_name in TARGET_ANIMS:
		var parts := anim_name.split("_")
		var action_name := str(parts[0])
		var direction := str(parts[1])
		var local_list = hum_frames.local_frames(action_name, direction)
		print("--- %s (%d frames) ---" % [anim_name, local_list.size()])
		for local_idx in local_list:
			var abs_idx: int = hum_frames.abs_index(int(local_idx))
			var png_path: String = hum_frames.png_path(abs_idx)
			var pl_path: String = hum_frames.placement_path(abs_idx)
			var has_png := ResourceLoader.exists(png_path)
			var has_pl := FileAccess.file_exists(pl_path)
			var placement := Vector2.ZERO
			if has_pl:
				placement = _read_placement(pl_path)
			var offset := placement.round()
			var size_str := "n/a"
			if has_png:
				var tex := load(png_path)
				size_str = "%dx%d" % [tex.get_width(), tex.get_height()]
			print("[DIAG] %s f=%d Hum=%05d place=(%.1f,%.1f) offset_rounded=(%d,%d) png=%s pl_exists=%s png_exists=%s" % [
				anim_name, int(local_idx), abs_idx, placement.x, placement.y,
				int(offset.x), int(offset.y), size_str, str(has_pl), str(has_png)])
	print("=== DIAG END ===")
	quit(0)


func _read_placement(path: String) -> Vector2:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return Vector2.ZERO
	var x_line := file.get_line().strip_edges()
	var y_line := file.get_line().strip_edges()
	file.close()
	if x_line.is_empty() or y_line.is_empty():
		return Vector2.ZERO
	return Vector2(x_line.to_float(), y_line.to_float())
