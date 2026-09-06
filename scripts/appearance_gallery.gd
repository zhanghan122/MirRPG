extends Node2D
## 外观画廊：数字键 [1-9]/[0] 直接跳转，[/] 或 ,/. 循环切换全部 24 套。
## WASD / 方向键移动当前角色，Shift = Run（由 hum_character.gd 自身处理）。

const PRESET_COUNT := 24
const PRESET_DIR := "res://scenes/characters/presets"

@onready var camera: Camera2D = $Camera2D
@onready var info_label: Label = $UI/InfoLabel

var _presets: Array[PackedScene] = []
var _current: Node2D = null
var _index := 0


func _ready() -> void:
	for i in range(PRESET_COUNT):
		var path := "%s/HumAppearance%02d.tscn" % [PRESET_DIR, i + 1]
		if not ResourceLoader.exists(path):
			push_error("appearance_gallery: missing preset %s" % path)
			continue
		var res := load(path)
		if res is PackedScene:
			_presets.append(res)
		else:
			push_error("appearance_gallery: not a PackedScene: %s" % path)
	switch_to(0)


func _process(_delta: float) -> void:
	if _current != null and is_instance_valid(_current):
		camera.position = _current.position
		info_label.text = _build_info()


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode >= KEY_1 and key.keycode <= KEY_9:
		switch_to(key.keycode - KEY_1)
	elif key.keycode == KEY_0:
		switch_to(9)
	elif key.keycode in [KEY_BRACKETLEFT, KEY_COMMA]:
		cycle(-1)
	elif key.keycode in [KEY_BRACKETRIGHT, KEY_PERIOD]:
		cycle(1)


func cycle(delta: int) -> void:
	if _presets.is_empty():
		return
	switch_to((_index + delta + _presets.size()) % _presets.size())


func switch_to(index: int) -> void:
	if index < 0 or index >= _presets.size():
		return
	if index == _index and is_instance_valid(_current):
		return
	_index = index
	if _current != null and is_instance_valid(_current):
		var old := _current
		remove_child(old)
		old.queue_free()
		_current = null
	var node = _presets[index].instantiate()
	node.position = Vector2.ZERO
	add_child(node)
	# 关闭角色自带相机，避免与画廊相机冲突。
	var cam := node.get_node_or_null("Camera2D")
	if cam != null:
		cam.enabled = false
	_current = node


func _build_info() -> String:
	if not is_instance_valid(_current):
		return ""
	var info: Dictionary = {}
	if _current.has_method("get_frame_info"):
		info = _current.get_frame_info()
	var first := int(info.get("appearance_base", 0))
	var lines: PackedStringArray = []
	lines.append("%s" % str(info.get("preset_name", "")))
	lines.append("appearance_id=%s   first_index=%d   last_index=%d" % [str(info.get("appearance_id", "?")), first, first + 599])
	lines.append("animation=%s   godot_frame=%s   absolute_index=%s" % [str(info.get("animation_name", "")), str(info.get("godot_frame", -1)), str(info.get("absolute_index", -1))])
	return "\n".join(lines)
