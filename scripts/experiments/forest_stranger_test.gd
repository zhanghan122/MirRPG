extends Node2D

# 森林怪人交互测试场景脚本：手动切换八方向、播放五个动作，HUD 实时显示状态。
# 运行（编辑器）：F6 打开 scenes/experiments/forest_stranger_test.tscn 后按运行；
# 或命令行：Godot_v4.7.2-stable_win64_console.exe --path Z:\MirRPG res://scenes/experiments/forest_stranger_test.tscn

var _monster: Node2D
var _hud: Label


func _ready() -> void:
	var scene := load("res://scenes/ForestStranger.tscn") as PackedScene
	if scene == null:
		push_error("ForestStrangerTest: cannot load ForestStranger.tscn")
		return
	_monster = scene.instantiate()
	add_child(_monster)
	_build_ui()


func _build_ui() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 10
	add_child(canvas)

	var root_v := VBoxContainer.new()
	root_v.position = Vector2(12, 12)
	root_v.add_theme_constant_override("separation", 6)
	canvas.add_child(root_v)

	_hud = Label.new()
	_hud.add_theme_font_size_override("font_size", 14)
	root_v.add_child(_hud)

	var dir_row := HBoxContainer.new()
	dir_row.add_theme_constant_override("separation", 4)
	root_v.add_child(dir_row)
	for d in Mon1Frames.DIRECTIONS:
		var b := Button.new()
		b.text = str(d).to_upper()
		b.pressed.connect(_on_direction_pressed.bind(str(d)))
		dir_row.add_child(b)

	var act_row := HBoxContainer.new()
	act_row.add_theme_constant_override("separation", 4)
	root_v.add_child(act_row)
	for a in ["idle", "walk", "attack", "struck", "death"]:
		var b2 := Button.new()
		b2.text = str(a).to_upper()
		b2.pressed.connect(_on_action_pressed.bind(str(a)))
		act_row.add_child(b2)

	var rec := Button.new()
	rec.text = "RECOVER"
	rec.tooltip_text = "从 death 状态恢复（测试用）"
	rec.pressed.connect(func(): _monster.recover())
	act_row.add_child(rec)


func _on_direction_pressed(dir: String) -> void:
	if _monster != null:
		_monster.set_direction(dir)


func _on_action_pressed(action: String) -> void:
	if _monster == null:
		return
	match action:
		"idle":
			_monster.play_idle()
		"walk":
			_monster.play_walk()
		"attack":
			_monster.play_attack()
		"struck":
			_monster.play_struck()
		"death":
			_monster.play_death()


func _process(_delta: float) -> void:
	if _hud == null or _monster == null:
		return
	var info: Dictionary = _monster.get_frame_info()
	var off := info["offset"] as Vector2
	_hud.text = "action=%s  dir=%s  frame=%d/%d  source_index=%05d  offset=(%.1f, %.1f)  dead=%s" % [
		str(info["action"]), str(info["direction"]), int(info["godot_frame"]), int(info["frame_count"]),
		int(info["source_index"]), off.x, off.y, str(bool(info["dead"]))]
