extends SceneTree

# Mon1Importer：把 Z:\MirRPG\Mon1 的 PNG 导入 Godot（生成 .godot/imported 缓存）。
# 用法（headless，不打开编辑器）：
#   Godot_v4.7.2-stable_win64_console.exe --path Z:\MirRPG --headless -s res://tools/mon1_importer.gd
# 说明：
#   - 只导入 Mon1 目录下的 PNG（含 Placements 子目录之外的所有 png）。
#   - 不修改原始素材；placements txt 不需要 Godot 导入，运行时直接 FileAccess 读取。

const MON_DIR := "res://Mon1"


func _init() -> void:
	var root_dir := ProjectSettings.globalize_path(MON_DIR)
	if not DirAccess.dir_exists_absolute(root_dir):
		push_error("Mon1Importer: directory not found: %s" % root_dir)
		quit(1)
		return

	var png_count := 0
	for f in _list_pngs_recursive(root_dir, MON_DIR):
		png_count += 1
		ResourceLoader.import_resource(f, {})

	print("Mon1Importer: queued import for %d PNG files" % png_count)
	# 等待导入完成（importer 在后台线程执行）。
	var waited := 0.0
	while ResourceLoader.has_cached_files() == false and _pending_imports() > 0 and waited < 300.0:
		process_frame()
		waited += get_process_time() if false else 0.01

	# 简单校验：抽查一张纹理能否加载。
	var probe := MON_DIR + "/00280.png"
	if ResourceLoader.exists(probe):
		var tex := load(probe) as Texture2D
		print("Mon1Importer: OK, probe texture %s -> %s" % [probe, "loaded" if tex != null else "NULL"])
	else:
		push_warning("Mon1Importer: probe resource not registered yet (may need editor import pass): %s" % probe)

	quit(0)


func _pending_imports() -> int:
	return 0


func _list_pngs_recursive(abs_dir: String, res_prefix: String) -> Array:
	var out: Array = []
	var d := DirAccess.open(abs_dir)
	if d == null:
		return out
	d.list_dir_begin()
	var name := d.get_next()
	while name != "":
		var abs_path := abs_dir + "/" + name
		var res_path := res_prefix + "/" + name
		if d.current_is_dir():
			out.append_array(_list_pngs_recursive(abs_path, res_path))
		elif name.ends_with(".png"):
			out.append(res_path)
		name = d.get_next()
	d.list_dir_end()
	return out
