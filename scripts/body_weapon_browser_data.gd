class_name BodyWeaponBrowserData
extends RefCounted
## Body + Weapon 浏览器数据接入层（只负责数据，不含 UI）。
##
## 职责：
## - 枚举 24 个 Body preset，提供实例化与 appearance_id / appearance_base 读取
##   （真实值来自实例化节点的 get_frame_info()，不在本脚本硬编码）
## - 提供已确认的 16 个 weapon base 与 ACTION_LAYOUT；单一事实来源为
##   scripts/experiments/weapon_base_switch_test.gd（运行时读取其常量，不复制数据）
## - 按索引规则计算 body / weapon 各动作帧的绝对资源索引（不逐张硬编码 PNG 路径）
## - 读取 body / weapon placement；缺失时记录错误信息并返回安全默认值，不崩溃
##
## 只读：不修改 HumFrames、现有 preset、weapon 实验脚本或任何原始素材。

const PRESET_DIR := "res://scenes/characters/presets"
const PRESET_COUNT := 24
# Weapon mapping（16 bases + ACTION_LAYOUT + DIR_INDEX）的单一事实来源。
const WEAPON_MAPPING_SCRIPT := "res://scripts/experiments/weapon_base_switch_test.gd"
const WEAPON_PNG_DIR := "res://Weapon/"
const WEAPON_PLACEMENT_DIR := "res://Weapon/Placements/"

# 浏览器动作别名 -> weapon layout 原始动作名（attack 默认取 attack_onehand，
# attack_twohand / attack_power 可直接按原名传入）。
const ACTION_ALIASES := {
	"idle": "idle",
	"walk": "walk",
	"run": "run",
	"attack": "attack_onehand",
}

static var _errors: Array = []
static var _missing_warned: Dictionary = {}
static var _weapon_const_cache: Dictionary = {}
static var _weapon_constants_failed := false


# ---------- 错误报告 ----------

## 记录一条错误（同时 push_warning 到控制台）。缺失项不会导致崩溃。
static func report_error(msg: String) -> void:
	_errors.append(msg)
	push_warning("BodyWeaponBrowserData: %s" % msg)


## 取出并清空已记录的错误列表。
static func take_errors() -> PackedStringArray:
	var out := PackedStringArray(_errors)
	_errors.clear()
	return out


static func has_errors() -> bool:
	return not _errors.is_empty()


# ---------- Body preset（24 套） ----------

## preset_number 取 1..24，对应 HumAppearance01.tscn .. HumAppearance24.tscn。
static func preset_path(preset_number: int) -> String:
	if preset_number < 1 or preset_number > PRESET_COUNT:
		report_error("preset number out of range (1..%d): %d" % [PRESET_COUNT, preset_number])
		return ""
	return "%s/HumAppearance%02d.tscn" % [PRESET_DIR, preset_number]


## 全部 24 个 preset 路径（按编号顺序）。
static func all_preset_paths() -> Array[String]:
	var out: Array[String] = []
	for i in PRESET_COUNT:
		out.append(preset_path(i + 1))
	return out


## 实际不存在的 preset 路径列表（诊断用；正常应为空）。
static func missing_preset_paths() -> Array[String]:
	var out: Array[String] = []
	for p in all_preset_paths():
		if not ResourceLoader.exists(p):
			out.append(p)
	return out


## 加载 preset 的 PackedScene；不存在或类型不符时返回 null 并记录错误。
static func load_preset_scene(preset_number: int) -> PackedScene:
	var path := preset_path(preset_number)
	if path.is_empty():
		return null
	if not ResourceLoader.exists(path):
		report_error("preset scene missing: %s" % path)
		return null
	var res := load(path)
	if res is PackedScene:
		return res
	report_error("not a PackedScene: %s" % path)
	return null


## 实例化 preset 并挂到 parent（触发 _ready，完成 SpriteFrames/placement 构建）。
static func instantiate_body(preset_number: int, parent: Node) -> Node2D:
	if parent == null:
		report_error("instantiate_body: parent is null")
		return null
	var scene := load_preset_scene(preset_number)
	if scene == null:
		return null
	var node = scene.instantiate()
	if not (node is Node):
		report_error("preset instantiate failed: %d" % preset_number)
		return null
	parent.add_child(node)
	return node


## 从已实例化 body 节点的 get_frame_info() 读取 appearance_id / appearance_base。
static func body_info(body_node: Node) -> Dictionary:
	if body_node == null or not body_node.has_method("get_frame_info"):
		report_error("body_info: node has no get_frame_info()")
		return {"ok": false, "appearance_id": -1, "appearance_base": -1, "preset_name": ""}
	var info: Dictionary = body_node.get_frame_info()
	return {
		"ok": true,
		"appearance_id": int(info.get("appearance_id", -1)),
		"appearance_base": int(info.get("appearance_base", -1)),
		"preset_name": str(info.get("preset_name", "")),
	}


# ---------- Body 帧（复用 HumFrames mapping，不另建一套） ----------

## body 全部动作名（来自 HumFrames.ALL_ACTIONS）。
static func body_actions() -> Array[String]:
	if HumFrames == null:
		report_error("HumFrames autoload unavailable")
		return []
	var out: Array[String] = []
	for a in HumFrames.ALL_ACTIONS:
		out.append(String(a))
	return out


## 八方向顺序（来自 HumFrames.DIRECTIONS：n ne e se s sw w nw）。
static func body_directions() -> Array[String]:
	if HumFrames == null:
		report_error("HumFrames autoload unavailable")
		return []
	var out: Array[String] = []
	for d in HumFrames.DIRECTIONS:
		out.append(String(d))
	return out


## 某动作/方向的套内 local 帧索引数组；未知动作或方向返回空并记录错误。
static func body_local_frames(action: String, dir: String) -> Array[int]:
	if HumFrames == null:
		report_error("HumFrames autoload unavailable")
		return []
	var spec = HumFrames.HUM_ACTIONS.get(action)
	if spec == null:
		report_error("unknown body action: %s" % action)
		return []
	var frames_by_dir: Dictionary = (spec as Dictionary).get("frames", {})
	var local: Array = (frames_by_dir as Dictionary).get(dir, [])
	if local.is_empty():
		report_error("body action/dir has no frames: %s/%s" % [action, dir])
		return []
	var out: Array[int] = []
	for li in local:
		out.append(int(li))
	return out


## appearance_base + local 索引 -> 绝对资源索引列表。
static func body_abs_indices(appearance_base: int, action: String, dir: String) -> Array[int]:
	var local := body_local_frames(action, dir)
	if local.is_empty():
		return []
	var base := int(appearance_base)
	var out: Array[int] = []
	for li in local:
		out.append(base + li)
	return out


## 加载 body 帧纹理；缺失时返回 null 并记录错误（同一路径只报告一次）。
static func load_body_texture(abs_idx: int) -> Texture2D:
	if HumFrames == null:
		report_error("HumFrames autoload unavailable")
		return null
	var path := String(HumFrames.png_path(abs_idx))
	if not ResourceLoader.exists(path):
		_warn_missing("body texture", path)
		return null
	var tex := load(path) as Texture2D
	if tex == null:
		report_error("body texture failed to load: %s" % path)
		return null
	return tex


## body placement：第一行 X、第二行 Y（与 hum_character.gd 相同格式）。
static func read_body_placement(abs_idx: int) -> Vector2:
	if HumFrames == null:
		report_error("HumFrames autoload unavailable")
		return Vector2.ZERO
	var path := String(HumFrames.placement_path(abs_idx))
	return _read_placement_file(path, "body placement", abs_idx)


## 某动作/方向逐帧数据：[{abs_index, texture, placement}, ...]。
static func body_frame_data(appearance_base: int, action: String, dir: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for abs_idx in body_abs_indices(appearance_base, action, dir):
		out.append({
			"abs_index": abs_idx,
			"texture": load_body_texture(abs_idx),
			"placement": read_body_placement(abs_idx),
		})
	return out


# ---------- Weapon（16 bases + ACTION_LAYOUT，运行时读取实验脚本常量） ----------

## 从 weapon_base_switch_test.gd 惰性加载 WEAPON_BASES / ACTION_LAYOUT / DIR_INDEX。
static func _weapon_constants() -> Dictionary:
	if not _weapon_constants_failed and not _weapon_const_cache.is_empty():
		return _weapon_const_cache
	if _weapon_constants_failed:
		return {}
	if not ResourceLoader.exists(WEAPON_MAPPING_SCRIPT):
		_weapon_constants_failed = true
		report_error("weapon mapping script missing: %s" % WEAPON_MAPPING_SCRIPT)
		return {}
	var res := load(WEAPON_MAPPING_SCRIPT)
	if res is GDScript:
		var map: Dictionary = (res as GDScript).get_script_constant_map()
		if map.has("WEAPON_BASES") and map.has("ACTION_LAYOUT") and map.has("DIR_INDEX"):
			_weapon_const_cache = {
				"bases": map["WEAPON_BASES"],
				"layout": map["ACTION_LAYOUT"],
				"dir_index": map["DIR_INDEX"],
			}
			return _weapon_const_cache
		report_error(
			"weapon mapping script lacks WEAPON_BASES/ACTION_LAYOUT/DIR_INDEX: %s"
			% WEAPON_MAPPING_SCRIPT
		)
	else:
		report_error("weapon mapping is not a GDScript: %s" % WEAPON_MAPPING_SCRIPT)
	_weapon_constants_failed = true
	return {}


## 已确认的 16 个 weapon base（来源：weapon_base_switch_test.gd）。
static func weapon_bases() -> Array[int]:
	var c := _weapon_constants()
	if c.is_empty():
		return []
	var out: Array[int] = []
	for b in (c["bases"] as Array):
		out.append(int(b))
	return out


## 动作别名解析；未知动作记录错误并原样返回。
static func resolve_action(action: String) -> String:
	var resolved := String(ACTION_ALIASES.get(action, action))
	var c := _weapon_constants()
	if not c.is_empty():
		var layout: Dictionary = c["layout"]
		if not (layout as Dictionary).has(resolved):
			report_error("unknown weapon action: %s (resolved: %s)" % [action, resolved])
	return resolved


## local_index = offset + dir_index * stride + frame（规则同 weapon_base_switch_test.gd）。
static func weapon_local_index(action: String, dir: String, frame: int) -> int:
	var c := _weapon_constants()
	if c.is_empty():
		return -1
	var layout: Dictionary = c["layout"]
	var spec = (layout as Dictionary).get(resolve_action(action))
	if spec == null:
		return -1
	var dir_index_map: Dictionary = c["dir_index"]
	if not (dir_index_map as Dictionary).has(dir):
		report_error("unknown weapon direction: %s" % dir)
		return -1
	var frames_count := int((spec as Dictionary).get("frames", 0))
	if frame < 0 or frame >= frames_count:
		report_error(
			"weapon frame out of range: %s/%s frame=%d (count=%d)"
			% [action, dir, frame, frames_count]
		)
		return -1
	return int((spec as Dictionary)["offset"]) + int((dir_index_map as Dictionary)[dir]) * int((spec as Dictionary)["stride"]) + frame


## 某动作/方向全部帧的 weapon 绝对索引列表（weapon_base + local）。
static func weapon_abs_indices(weapon_base: int, action: String, dir: String) -> Array[int]:
	var c := _weapon_constants()
	if c.is_empty():
		return []
	var layout: Dictionary = c["layout"]
	var resolved := resolve_action(action)
	var spec = (layout as Dictionary).get(resolved)
	if spec == null:
		return []
	var dir_index_map: Dictionary = c["dir_index"]
	if not (dir_index_map as Dictionary).has(dir):
		report_error("unknown weapon direction: %s" % dir)
		return []
	var frames_count := int((spec as Dictionary).get("frames", 0))
	var base := int(weapon_base)
	var offset := int((spec as Dictionary)["offset"])
	var stride := int((spec as Dictionary)["stride"])
	var d_idx := int((dir_index_map as Dictionary)[dir])
	var out: Array[int] = []
	for f in frames_count:
		out.append(base + offset + d_idx * stride + f)
	return out


## 加载 weapon 帧纹理；缺失时返回 null 并记录错误（同一路径只报告一次）。
static func load_weapon_texture(abs_idx: int) -> Texture2D:
	var path := WEAPON_PNG_DIR + str(abs_idx).pad_zeros(5) + ".png"
	if not ResourceLoader.exists(path):
		_warn_missing("weapon texture", path)
		return null
	var tex := load(path) as Texture2D
	if tex == null:
		report_error("weapon texture failed to load: %s" % path)
		return null
	return tex


## weapon placement：第一行 X、第二行 Y（与 weapon_base_switch_test.gd 相同格式）。
static func read_weapon_placement(abs_idx: int) -> Vector2:
	var path := WEAPON_PLACEMENT_DIR + str(abs_idx).pad_zeros(5) + ".txt"
	return _read_placement_file(path, "weapon placement", abs_idx)


## 某动作/方向逐帧数据：[{abs_index, texture, placement}, ...]。
static func weapon_frame_data(weapon_base: int, action: String, dir: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for abs_idx in weapon_abs_indices(weapon_base, action, dir):
		out.append({
			"abs_index": abs_idx,
			"texture": load_weapon_texture(abs_idx),
			"placement": read_weapon_placement(abs_idx),
		})
	return out


# ---------- 内部工具 ----------

## placement 文件统一读取：第一行 X、第二行 Y，各取第一个逗号前数值。
static func _read_placement_file(path: String, what: String, abs_idx: int) -> Vector2:
	if not FileAccess.file_exists(path):
		report_error("%s missing for index %d: %s" % [what, abs_idx, path])
		return Vector2.ZERO
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		report_error("cannot open %s (err=%d): %s" % [what, FileAccess.get_open_error(), path])
		return Vector2.ZERO
	var line_x := f.get_line().strip_edges()
	var line_y := f.get_line().strip_edges()
	f.close()
	if line_x.is_empty() or line_y.is_empty():
		report_error("%s malformed for index %d: %s" % [what, abs_idx, path])
		return Vector2.ZERO
	return Vector2(float(line_x.split(",")[0]), float(line_y.split(",")[0]))


## 缺失资源只报告一次，避免逐帧刷屏。
static func _warn_missing(what: String, path: String) -> void:
	if _missing_warned.has(path):
		return
	_missing_warned[path] = true
	report_error("%s missing: %s" % [what, path])
