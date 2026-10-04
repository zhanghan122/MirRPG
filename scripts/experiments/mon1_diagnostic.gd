extends Node2D

# Mon1 森林怪人诊断工具（一次性生成，可重复运行）：
#   1) res://mon1_00280_00547_index_list.txt —— 00280-00547 每个索引的 PNG/placement/透明度清单
#   2) res://forest_stranger_contact_sheet.png —— 按动作分块、每行一个方向(N→NW)、每格标注 source_index
# 运行：Godot_v4.7.2-stable_win64_console.exe --path Z:\MirRPG --headless res://scenes/experiments/mon1_diagnostic.tscn

const START_INDEX := 280
const END_INDEX := 547
const CELL_W := 100
const CELL_H := 130
const MARGIN := 20
const ROW_LABEL_W := 44
const BLOCK_TITLE_H := 44
const BLOCK_GAP := 64

# 4x6 位图字体（headless 下 Image 无 draw_string，用 fill_rect 逐像素绘制）。
const FONT := {
	" ": ["....", "....", "....", "....", "....", "...."],
	"0": ["####", "#..#", "#..#", "#..#", "#..#", "####"],
	"1": [".#..", "##..", ".#..", ".#..", ".#..", "####"],
	"2": ["####", "#..#", "...#", "..#.", ".#..", "####"],
	"3": ["####", "#..#", "...#", "..#.", "#..#", "####"],
	"4": ["#..#", "#..#", "####", "...#", "...#", "...#"],
	"5": ["####", "#...", "####", "...#", "#..#", "####"],
	"6": ["####", "#...", "####", "#..#", "#..#", "####"],
	"7": ["####", "...#", "..#.", ".#..", ".#..", ".#.."],
	"8": ["####", "#..#", "#..#", "####", "#..#", "####"],
	"9": ["####", "#..#", "#..#", "####", "...#", "####"],
	"A": [".##.", "#..#", "#..#", "####", "#..#", "#..#"],
	"B": ["###.", "#..#", "###.", "#..#", "#..#", "###."],
	"C": ["####", "#...", "#...", "#...", "#...", "####"],
	"D": ["###.", "#..#", "#..#", "#..#", "#..#", "###."],
	"E": ["####", "#...", "###.", "#...", "#...", "####"],
	"F": ["####", "#...", "###.", "#...", "#...", "#..."],
	"G": ["####", "#...", "#..#", "#..#", "#..#", "####"],
	"H": ["#..#", "#..#", "####", "#..#", "#..#", "#..#"],
	"I": ["####", ".#..", ".#..", ".#..", ".#..", "####"],
	"K": ["#...", "#..#", "##..", "#..#", "#...", "#..."],
	"L": ["#...", "#...", "#...", "#...", "#...", "####"],
	"M": ["#...", "##.#", "#.#.", "#.#.", "#...", "#..."],
	"N": ["#..#", "#..#", "##.#", "#.##", "#..#", "#..#"],
	"O": ["####", "#..#", "#..#", "#..#", "#..#", "####"],
	"P": ["###.", "#..#", "#..#", "###.", "#...", "#..."],
	"R": ["###.", "#..#", "#..#", "###.", "#..#", "#..."],
	"S": ["####", "#...", "####", "...#", "...#", "####"],
	"T": ["####", ".#..", ".#..", ".#..", ".#..", ".#.."],
	"U": ["#..#", "#..#", "#..#", "#..#", "#..#", "####"],
	"W": ["#...", "#...", "#.#.", "##.#", "#.#.", "#..."],
	"Y": ["#..#", "#..#", ".##.", ".#..", ".#..", ".#.."],
}


func _ready() -> void:
	_write_index_list()
	_make_contact_sheet()
	print("DIAGNOSTIC DONE")
	get_tree().quit(0)


# ---------- 索引清单 ----------

func _write_index_list() -> void:
	var lines: Array = []
	lines.append("# Mon1 index diagnostic (forest_stranger range)")
	lines.append("# range=%d-%d" % [START_INDEX, END_INDEX])
	lines.append("%-8s %-6s %-7s %-5s %-5s %-8s %-8s %-12s %s" % ["index", "png", "valid", "w", "h", "px", "py", "alpha", "note"])
	var valid_count := 0
	for i in range(START_INDEX, END_INDEX + 1):
		var png_path := Mon1Frames.png_path(i)
		var has_png := FileAccess.file_exists(png_path)
		var w := -1
		var h := -1
		var alpha := "-"
		var note := ""
		if has_png:
			var img := Image.load_from_file(png_path)
			if img != null and not img.is_empty():
				w = img.get_width()
				h = img.get_height()
				alpha = _alpha_stats(img)
				valid_count += 1
			else:
				note = "invalid image"
		var px := "-"
		var py := "-"
		var ppath := Mon1Frames.placement_path(i)
		if FileAccess.file_exists(ppath):
			var f := FileAccess.open(ppath, FileAccess.READ)
			if f != null:
				var lx := f.get_line().strip_edges()
				var ly := f.get_line().strip_edges()
				f.close()
				if not lx.is_empty():
					px = str(lx.split(",")[0])
				if not ly.is_empty():
					py = str(ly.split(",")[0])
			else:
				note += " placement unreadable"
		lines.append("%-8d %-6s %-7s %-5d %-5d %-8s %-8s %-12s %s" % [i, str(has_png), str(has_png and w > 0), w, h, px, py, alpha, note])
	var out := FileAccess.open("res://mon1_00280_00547_index_list.txt", FileAccess.WRITE)
	if out == null:
		push_error("cannot write index list")
		return
	for line in lines:
		out.store_line(str(line))
	out.close()
	print("index list written (valid pngs=%d)" % valid_count)


func _alpha_stats(img: Image) -> String:
	var opaque := 0
	var total := img.get_width() * img.get_height()
	for y in range(img.get_height()):
		for x in range(img.get_width()):
			if img.get_pixel(x, y).a > 0.01:
				opaque += 1
	return "FULL" if opaque == 0 else ("%d/%d" % [opaque, total])


# ---------- contact sheet ----------

func _make_contact_sheet() -> void:
	var actions := Mon1Frames.monster_actions("forest_stranger")
	var order := Mon1Frames.action_order("forest_stranger")
	var dirs := Mon1Frames.DIRECTIONS
	var max_cols := 0
	for action in order:
		if not actions.has(action):
			continue
		var spec: Dictionary = actions[action]
		for dir in dirs:
			max_cols = maxi(max_cols, int((spec["frames"] as Dictionary)[dir].size()))

	var block_h := BLOCK_TITLE_H + dirs.size() * CELL_H
	var W := MARGIN + ROW_LABEL_W + max_cols * CELL_W + MARGIN
	var H := MARGIN + order.size() * (block_h + BLOCK_GAP)
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.13, 0.14, 0.17))

	var y := MARGIN
	for action in order:
		if not actions.has(action):
			continue
		var spec: Dictionary = actions[action]
		_draw_text(img, Vector2i(MARGIN, y + 10), "%s %d" % [str(action).to_upper(), int(spec["frames_per_direction"])], 3, Color(0.95, 0.95, 0.6))
		y += BLOCK_TITLE_H
		for dir in dirs:
			_draw_text(img, Vector2i(MARGIN + 8, y + CELL_H / 2 - 12), str(dir).to_upper(), 2, Color(0.75, 0.8, 0.9))
			var indexes: Array = (spec["frames"] as Dictionary)[dir]
			for ci in range(indexes.size()):
				var idx := int(indexes[ci])
				var cx := MARGIN + ROW_LABEL_W + ci * CELL_W
				img.fill_rect(Rect2i(cx, y, CELL_W - 4, CELL_H - 4), Color(0.2, 0.22, 0.27))
				var timg := Image.load_from_file(Mon1Frames.png_path(idx))
				if timg != null and not timg.is_empty():
					_blit_centered(img, timg, cx + (CELL_W - 4) / 2, y + (CELL_H - 4) / 2)
				else:
					img.fill_rect(Rect2i(cx + 8, y + CELL_H / 2 - 10, CELL_W - 20, 20), Color(0.6, 0.2, 0.2))
				_draw_text(img, Vector2i(cx + 4, y + CELL_H - 22), "%05d" % idx, 2, Color(0.95, 0.85, 0.35))
			y += CELL_H
		y += BLOCK_GAP

	var err := img.save_png("res://forest_stranger_contact_sheet.png")
	if err != OK:
		push_error("contact sheet save failed: %d" % err)
	else:
		print("contact sheet written (%dx%d)" % [W, H])


# 将 src 图像以 (cx, cy) 为中心逐像素绘制到 dst（纯 CPU，headless 可用）。
func _blit_centered(dst: Image, src: Image, cx: int, cy: int) -> void:
	var ox := cx - src.get_width() / 2
	var oy := cy - src.get_height() / 2
	for sy in range(src.get_height()):
		var dy := oy + sy
		if dy < 0 or dy >= dst.get_height():
			continue
		for sx in range(src.get_width()):
			var dx := ox + sx
			if dx < 0 or dx >= dst.get_width():
				continue
			var c := src.get_pixel(sx, sy)
			if c.a > 0.01:
				dst.set_pixel(dx, dy, c)


# 位图字体绘制：scale=2 → 每字符 8x12 px，字距 1px。
func _draw_text(img: Image, pos: Vector2i, text: String, scale: int, color: Color) -> void:
	var x := pos.x
	for ch in text:
		var glyph: Array = FONT.get(ch, [])
		if glyph.is_empty():
			x += 3 * scale
			continue
		for row in range(6):
			var line := str(glyph[row])
			for col in range(line.length()):
				if line[col] == "#":
					img.fill_rect(Rect2i(x + col * scale, pos.y + row * scale, scale, scale), color)
		x += 5 * scale
