extends Node2D
## combat_field_test.gd — 战斗地图测试 PHASE 2（最小地图 + 按住右键移动 + Hair/Weapon 图层）。
##
## - 地图：map_size 矩形，四周 border_width 褐色边界；有效区域由两者推导。
## - 玩家：现有 HumAppearance01 preset，通过其自身状态/播放路径驱动
##   （action_locked / last_direction / current_action / _play），不修改 hum_character.gd。
## - Hair/Weapon 图层（本阶段新增）：
##   * 索引规则复用现有 mapping，不新建表：
##       local_index = 身体当前帧在 HUM_ACTIONS 中的本地索引
##                     （取自 player.get_frame_info() 的 absolute_index - appearance_base）
##       hair_abs    = HAIR_BASE + local_index      (1200 + li)
##       weapon_abs  = WEAPON_BASE + local_index    (31200 + li)
##     身体与 Hair/Weapon 的动作布局完全一致（已验证），因此同一 local_index 通用。
##   * 图层节点在代码中构建并挂到 Player 下（自动跟随移动，无延迟），与 SpriteAnchor 同级：
##       Player ├── HairAnchor  └── HairSprite
##              └── WeaponAnchor └── WeaponSprite
##     placement 只应用一次在 Anchor 上：HairAnchor.position = hair_placement、
##     WeaponAnchor.position = weapon_placement；不叠加 Body placement。
##     Sprite 保持 position/offset ZERO、centered=false（与身体 AnimatedSprite2D 同一规则）。
##     Player 内部统一图层：Weapon后层(w/nw/sw)=0 < BodySprite=1 < Weapon前层(其他方向)=2 < HairSprite=3；
##     Hair 必须始终高于身体；方向变化只切换 Weapon 的 z_index，不修改 Hair。
##   * placement 格式与 Hum 相同（第一行 X、第二行 Y），读取结果缓存，禁止每帧读盘。
##   * 某帧纹理缺失时该图层隐藏并 push_warning，不中断播放。
## - 移动规则：
##   * 按住右键：玩家持续朝鼠标当前世界坐标移动；按住期间移动鼠标实时改变方向。
##   * Shift+右键 = run（run_speed）；无 Shift = walk（walk_speed）。
##     每物理帧轮询 Shift，按下/松开立即切换 walk/run。
##   * 松开右键：立即停止并播放最后方向 idle，随后恢复 action_locked。
##   * 鼠标距玩家 < stop_distance：停止避免抖动；到达边界无法继续时播 idle，
##     鼠标移回可移动方向后自动继续。
##   * 目标标记在按住期间跟随鼠标（钳制到有效区域内），松开后隐藏。
## - 碰撞层约定（地面为 layer 0，不参与碰撞）：
##   * 1 = 世界边界 / 静态障碍（WorldBoundary 四面墙）
##   * 2 = 玩家（Hum CharacterBody2D；保留 hum_character.tscn 现有 box 形状，不改场景文件）
##   * 4 = 怪物（MonsterCollision 包装体，脚底小圆碰撞，包裹 ForestStranger 动画场景）
##   玩家 body: layer=2 mask=1|4。怪物 body: layer=4 mask=1|4。墙: layer=1 mask=0。
## - 移动改为物理驱动：velocity + move_and_slide()，沿墙/怪物自动滑动；
##   边界墙保证玩家碰撞体不会进入褐色边界区域（替代旧的直接写 global_position + clamp）。
##   hum_character.gd 自身 WASD 逻辑仍有效（根节点 _physics_process 先于子节点执行）。
## - action_locked 仅在右键按住期间临时占用，松开即恢复，不长期占用。
## - 怪物（本阶段新增）：场景启动时生成 monster_count 只森林怪人（res://scenes/ForestStranger.tscn），
##   只在 valid_rect 内、距玩家 ≥min_player_spawn_distance、彼此 ≥min_monster_spacing；
##   每只最多尝试 spawn_attempt_limit 次，失败则跳过并警告（不无限循环）。
##   初始状态 idle、随机方向、无移动/攻击。F7 = 清除旧怪物并重新生成（仍遵守距离规则）。
## - 深度排序：玩家+怪物按世界 Y 统一排序；只修改怪物的 z_index，不触碰玩家内部图层
##   （weapon=0/2, body=1, hair=3）；地面固定 GROUND_Z 垫底。
## - 本阶段无攻击判定、HP、AI（怪物只播放 idle）。

const GRASS_COLOR := Color(0.29, 0.56, 0.24)
const BORDER_COLOR := Color(0.43, 0.29, 0.16)
const MARKER_COLOR := Color(1.0, 0.85, 0.3, 0.9)

# Hair/Weapon 组基址（appearance 0；索引规则见文件头注释）。
const HAIR_BASE := 1200
const WEAPON_BASE := 31200

@export var map_size := Vector2(2560, 1440)
@export var border_width := 64.0
@export var walk_speed := 200.0
@export var run_speed := 360.0
@export var stop_distance := 8.0

# ===== 怪物生成配置（阶段二）=====
@export var monster_count := 5
@export var min_player_spawn_distance := 220.0
@export var min_monster_spacing := 100.0
@export var spawn_attempt_limit := 50

# 地面固定层：必须低于所有角色（怪物在玩家后方时 z 可为负），保证草地始终垫底。
const GROUND_Z := -10


var valid_rect := Rect2()
var right_mouse_held := false
var target_pos := Vector2.ZERO

var _player: CharacterBody2D
var _marker: Node2D
var _hud: Label
# Hair/Weapon 图层（代码构建，挂在 Player 下自动跟随）。
var _hair_anchor: Node2D
var _hair_sprite: Sprite2D
var _weapon_anchor: Node2D
var _weapon_sprite: Sprite2D
# placement 缓存：path -> Vector2（禁止每帧读盘）。
var _placement_cache := {}
# HUD/诊断用最近一次索引。
var _diag_hair_abs := -1
var _diag_weapon_abs := -1
var _hair_missing_warned := {}
var _weapon_missing_warned := {}
# 怪物实例列表（阶段二）。
var _monsters: Array = []


func _ready() -> void:
	valid_rect = Rect2(
		Vector2(border_width, border_width),
		map_size - Vector2(border_width, border_width) * 2.0
	)
	_player = $Player
	# 碰撞层在运行时设置；hum_character.tscn 保留其现有 box 形状，不修改场景文件。
	_player.collision_layer = 2
	_player.collision_mask = 1 | 4
	_hud = $HudCanvasLayer/HudLabel
	_build_ground($GroundLayer)
	_build_boundary()
	_marker = _build_marker()
	add_child(_marker)
	_build_layers()

	# Player 内部统一图层（固定常量，不做动态累加）：
	#   Weapon后层(w/nw/sw)=0 < BodySprite=1 < Weapon前层(其他方向)=2 < HairSprite=3。
	# Hair 必须始终高于身体；方向变化只切换 Weapon 的 z_index（见 _update_weapon_layer）。
	$GroundLayer.z_index = GROUND_Z
	var body_sprite := _player.get_node_or_null("SpriteAnchor/AnimatedSprite2D") as CanvasItem
	if body_sprite != null:
		body_sprite.z_index = 1

	_player.global_position = map_size * 0.5
	var cam := _player.get_node_or_null("Camera2D") as Camera2D
	if cam != null:
		# 抖动诊断第一轮：只关闭相机平滑，不修改其他设置（等待实机测试）。
		cam.position_smoothing_enabled = false
	_spawn_monsters()
	_update_depth_sort()
	_print_sprite_diagnostics()


func _process(_delta: float) -> void:
	_update_hair_weapon()
	_update_depth_sort()
	_update_hud()


func _physics_process(delta: float) -> void:
	if not right_mouse_held or _player == null:
		return
	var target := _clamp_to_valid(get_global_mouse_position())
	target_pos = target
	_marker.global_position = target
	var to_target := target - _player.global_position
	var dist := to_target.length()
	if dist <= stop_distance:
		# 鼠标过近，或已到边界无法继续移动 → idle（防抖）。
		_player.velocity = Vector2.ZERO
		_set_action("idle")
		return
	var running := Input.is_physical_key_pressed(KEY_SHIFT)
	var step_dir := to_target / dist
	var dir_name := _direction_name(step_dir)
	if String(_player.last_direction) != dir_name:
		_player.last_direction = dir_name
	# 角色自身的播放助手：同一动画幂等，并逐帧应用 placement 偏移。
	_set_action("run" if running else "walk")
	var speed := run_speed if running else walk_speed
	# 物理移动：velocity + move_and_slide() 沿墙/怪物自动滑动；
	# 边界墙保证玩家碰撞体不进入褐色边界区域（替代旧的直接写 global_position + clamp）。
	_player.velocity = step_dir * speed
	_player.move_and_slide()


func _unhandled_input(event: InputEvent) -> void:
	var mi := event as InputEventMouseButton
	if mi == null or mi.button_index != MOUSE_BUTTON_RIGHT:
		return
	if mi.pressed:
		right_mouse_held = true
		# 最小临时处理：按住期间冻结角色自身输入状态机，防止其覆盖动画。
		_player.action_locked = true
		_marker.show()
	else:
		right_mouse_held = false
		# 松开 → 立即停止（清零速度）+ 最后方向 idle，然后恢复 action_locked。
		_player.velocity = Vector2.ZERO
		_set_action("idle")
		_player.action_locked = false
		_marker.hide()


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_ESCAPE:
		get_tree().quit()
	elif key.keycode == KEY_F9:
		# 诊断：随时重新打印 Sprite/位置/相机/Hair-Weapon 图层状态。
		_print_sprite_diagnostics()
	elif key.keycode == KEY_F7:
		# 重新生成怪物（清除旧的，按距离规则重新放置）。
		_spawn_monsters()


## 切换角色动画并同步 current_action（walk/run/idle），同一动画幂等。
func _set_action(action_name: String) -> void:
	var dir_name := String(_player.last_direction)
	_player.current_action = action_name
	_player._play("%s_%s" % [action_name, dir_name])


# ===== 怪物生成（阶段二）=====

## 生成 monster_count 只森林怪人：只在 valid_rect 内、距玩家 ≥min_player_spawn_distance、
## 彼此 ≥min_monster_spacing；每只最多尝试 spawn_attempt_limit 次，失败则跳过并警告。
func _spawn_monsters() -> void:
	_clear_monsters()
	var player_pos := _player.global_position if _player != null else Vector2.ZERO
	var placed: Array = []
	for i in range(monster_count):
		var pos := Vector2.ZERO
		var found := false
		for attempt in range(spawn_attempt_limit):
			var cand := valid_rect.position + Vector2(randf(), randf()) * valid_rect.size
			if (cand - player_pos).length() < min_player_spawn_distance:
				continue
			var too_close := false
			for p in placed:
				if (cand - p).length() < min_monster_spacing:
					too_close = true
					break
			if too_close:
				continue
			pos = cand
			found = true
			break
		if not found:
			push_warning("CombatFieldTest: 怪物 %d/%d 在 %d 次尝试内未找到合法位置，跳过" % [i + 1, monster_count, spawn_attempt_limit])
			continue
		placed.append(pos)
		var m := _instantiate_monster(pos)
		if m != null:
			_monsters.append(m)
	print("CombatFieldTest: spawned %d/%d monsters" % [_monsters.size(), monster_count])


## 实例化一只森林怪人：MonsterCollision（CharacterBody2D + 脚底小圆碰撞）包裹动画场景。
## initial_direction 必须在 add_child 前设置（其 _ready 会读取）。返回物理包装体。
func _instantiate_monster(pos: Vector2) -> Node2D:
	var monster_scene := load("res://scenes/ForestStranger.tscn") as PackedScene
	if monster_scene == null:
		push_error("CombatFieldTest: 无法加载 res://scenes/ForestStranger.tscn")
		return null
	var body_scene := load("res://scenes/experiments/monster_collision.tscn") as PackedScene
	if body_scene == null:
		push_error("CombatFieldTest: 无法加载 res://scenes/experiments/monster_collision.tscn")
		return null
	var m := monster_scene.instantiate() as Node2D
	m.initial_direction = Mon1Frames.DIRECTIONS.pick_random()
	var body := body_scene.instantiate() as CharacterBody2D
	body.add_child(m)  # 触发其 _ready → 播放该方向 idle（初始状态 idle，无移动/攻击）。
	body.position = pos
	add_child(body)
	return body


func _clear_monsters() -> void:
	for m in _monsters:
		if is_instance_valid(m):
			m.queue_free()
	_monsters.clear()


## 深度排序：玩家+怪物按世界 Y（脚底）统一排序。只修改怪物的 z_index（绝对值），
## 不触碰玩家内部图层（weapon=0/2, body=1, hair=3）；地面固定 GROUND_Z 垫底。
## 玩家在玩家上方的怪物取负层(-1,-2...)，下方从 4 起递增，顺序恒正确。
func _update_depth_sort() -> void:
	if _player == null or _monsters.is_empty():
		return
	var entries: Array = []
	for m in _monsters:
		if is_instance_valid(m):
			entries.append([m, m.global_position.y])
	entries.append([null, _player.global_position.y])
	entries.sort_custom(func(a, b): return a[1] < b[1])
	var p := -1
	for i in range(entries.size()):
		if entries[i][0] == null:
			p = i
			break
	if p < 0:
		return
	for i in range(entries.size()):
		var node = entries[i][0]
		if node == null:
			continue
		var z := (i - p) if i < p else (i - p + 3)
		# 怪物现在由 MonsterCollision 物理体包裹，动画场景是其子节点。
		var body := node as CharacterBody2D
		var monster: Node = body.get_monster() if body != null and body.has_method("get_monster") else null
		var spr := (monster.get_node_or_null("SpriteAnchor/AnimatedSprite2D") as CanvasItem) if monster != null else null
		if spr != null:
			spr.z_index = z


## 构建 Hair/Weapon 图层：挂在 Player 下自动跟随，与 SpriteAnchor 同级。
## placement 只写在 Anchor.position；Sprite position/offset ZERO、centered=false，
## 与身体 AnimatedSprite2D（hum_character.tscn）同一套坐标规则。
func _build_layers() -> void:
	_weapon_anchor = Node2D.new()
	_weapon_anchor.name = "WeaponAnchor"
	_weapon_anchor.z_as_relative = true
	_weapon_sprite = Sprite2D.new()
	_weapon_sprite.name = "WeaponSprite"
	_weapon_sprite.centered = false
	_weapon_sprite.position = Vector2.ZERO
	_weapon_sprite.offset = Vector2.ZERO
	_weapon_sprite.z_index = 2
	_weapon_sprite.z_as_relative = true
	_weapon_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_weapon_sprite.visible = false
	_weapon_anchor.add_child(_weapon_sprite)
	_player.add_child(_weapon_anchor)

	_hair_anchor = Node2D.new()
	_hair_anchor.name = "HairAnchor"
	_hair_anchor.z_as_relative = true
	_hair_sprite = Sprite2D.new()
	_hair_sprite.name = "HairSprite"
	_hair_sprite.centered = false
	_hair_sprite.position = Vector2.ZERO
	_hair_sprite.offset = Vector2.ZERO
	_hair_sprite.z_index = 3
	_hair_sprite.z_as_relative = true
	_hair_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_hair_sprite.visible = false
	_hair_anchor.add_child(_hair_sprite)
	_player.add_child(_hair_anchor)


## 每帧同步 Hair/Weapon：从身体当前帧取 local_index（现有 mapping），
## 按 base + local_index 载入纹理并应用 placement。
func _update_hair_weapon() -> void:
	if not is_instance_valid(_player):
		return
	var info = _player.get_frame_info()
	var abs_idx := int(info["absolute_index"])
	if abs_idx < 0:
		_hide_layer(_hair_anchor, _hair_sprite)
		_hide_layer(_weapon_anchor, _weapon_sprite)
		return
	var local_index := abs_idx - int(info["appearance_base"])
	_diag_hair_abs = HAIR_BASE + local_index
	_diag_weapon_abs = WEAPON_BASE + local_index
	_apply_layer(HAIR_BASE + local_index, "res://Hair/%05d.png",
			"res://Hair/Placements/%05d.txt", _hair_anchor, _hair_sprite, _hair_missing_warned)
	_apply_layer(WEAPON_BASE + local_index, "res://Weapon/%05d.png",
			"res://Weapon/Placements/%05d.txt", _weapon_anchor, _weapon_sprite, _weapon_missing_warned)
	_update_weapon_layer(String(_player.last_direction))


## Weapon 叠放规则（只改 Weapon，不触碰 Hair）：w/nw/sw → 后层(0)；其余方向 → 前层(2)。
func _update_weapon_layer(dir_name: String) -> void:
	if dir_name in ["w", "nw", "sw"]:
		_weapon_sprite.z_index = 0
	else:
		_weapon_sprite.z_index = 2


## 载入单个图层帧：纹理存在则显示并应用 placement；缺失则隐藏该层。
func _apply_layer(abs_idx: int, png_fmt: String, placement_fmt: String,
		anchor: Node2D, sprite: Sprite2D, warned: Dictionary) -> void:
	var png_path := png_fmt % abs_idx
	if not ResourceLoader.exists(png_path):
		_hide_layer(anchor, sprite)
		if not warned.has(abs_idx):
			warned[abs_idx] = true
			push_warning("Layer texture missing (hidden this frame): %s" % png_path)
		return
	var tex := load(png_path) as Texture2D
	if tex == null:
		_hide_layer(anchor, sprite)
		return
	sprite.texture = tex
	sprite.visible = true
	anchor.position = _read_placement(placement_fmt % abs_idx)


func _hide_layer(anchor: Node2D, sprite: Sprite2D) -> void:
	sprite.visible = false


## placement 读取（与 hum_character.gd 相同格式：第一行 X、第二行 Y），带缓存。
func _read_placement(path: String) -> Vector2:
	if not _placement_cache.has(path):
		_placement_cache[path] = _load_placement_file(path)
	return _placement_cache[path]


func _load_placement_file(path: String) -> Vector2:
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


## 八方向量化，与 hum_character.gd 相同的阈值规则（作用于单位向量）。
func _direction_name(v: Vector2) -> String:
	var dx := 1 if v.x > 0.5 else (-1 if v.x < -0.5 else 0)
	var dy := 1 if v.y > 0.5 else (-1 if v.y < -0.5 else 0)
	match "%d,%d" % [dx, dy]:
		"0,-1": return "n"
		"1,-1": return "ne"
		"1,0": return "e"
		"1,1": return "se"
		"0,1": return "s"
		"-1,1": return "sw"
		"-1,0": return "w"
		"-1,-1": return "nw"
	return String(_player.last_direction) if _player != null else "s"


func _clamp_to_valid(p: Vector2) -> Vector2:
	return Vector2(
		clampf(p.x, valid_rect.position.x, valid_rect.end.x),
		clampf(p.y, valid_rect.position.y, valid_rect.end.y)
	)


func _build_ground(layer: Node) -> void:
	var border := Polygon2D.new()
	border.color = BORDER_COLOR
	border.polygon = PackedVector2Array([
		Vector2.ZERO, Vector2(map_size.x, 0.0), map_size, Vector2(0.0, map_size.y),
	])
	layer.add_child(border)
	var grass := Polygon2D.new()
	grass.color = GRASS_COLOR
	grass.polygon = PackedVector2Array([
		valid_rect.position,
		Vector2(valid_rect.end.x, valid_rect.position.y),
		valid_rect.end,
		Vector2(valid_rect.position.x, valid_rect.end.y),
	])
	layer.add_child(grass)


## 世界边界墙：StaticBody2D + 四面矩形，layer=1 mask=0。
## 墙体在四角各外扩 border_width 避免接缝；玩家/怪物的碰撞体无法越过它们，
## 因此角色不会进入褐色边界区域（地面 Polygon2D 本身不参与碰撞）。
func _build_boundary() -> void:
	var body := StaticBody2D.new()
	body.name = "WorldBoundary"
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	var t := border_width
	var cx := valid_rect.position.x + valid_rect.size.x * 0.5
	var cy := valid_rect.position.y + valid_rect.size.y * 0.5
	# [中心, 尺寸]：上、下、左、右；左右墙加高覆盖四角。
	var specs: Array = [
		[Vector2(cx, valid_rect.position.y - t * 0.5), Vector2(valid_rect.size.x + t, t)],
		[Vector2(cx, valid_rect.end.y + t * 0.5), Vector2(valid_rect.size.x + t, t)],
		[Vector2(valid_rect.position.x - t * 0.5, cy), Vector2(t, valid_rect.size.y + t)],
		[Vector2(valid_rect.end.x + t * 0.5, cy), Vector2(t, valid_rect.size.y + t)],
	]
	for spec in specs:
		var shape := RectangleShape2D.new()
		shape.size = spec[1]
		var node := CollisionShape2D.new()
		node.shape = shape
		node.position = spec[0]
		body.add_child(node)


func _build_marker() -> Node2D:
	var root := Node2D.new()
	root.name = "TargetMarker"
	root.visible = false
	var poly := Polygon2D.new()
	poly.color = MARKER_COLOR
	poly.polygon = PackedVector2Array([
		Vector2(0.0, -14.0), Vector2(14.0, 0.0), Vector2(0.0, 14.0), Vector2(-14.0, 0.0),
	])
	root.add_child(poly)
	return root


func _update_hud() -> void:
	if _hud == null or _player == null:
		return
	var target_text := "--" if not right_mouse_held else "(%.0f, %.0f)" % [target_pos.x, target_pos.y]
	var dist_text := "--" if not right_mouse_held else "%.1f" % (target_pos - _player.global_position).length()
	var lines := [
		"COMBAT FIELD TEST - PHASE 2",
		"player pos : (%.0f, %.0f)" % [_player.global_position.x, _player.global_position.y],
		"target     : " + target_text,
		"direction  : " + String(_player.last_direction),
		"action     : " + String(_player.current_action),
		"dist       : " + dist_text,
		"hair_abs   : %d    weapon_abs: %d" % [_diag_hair_abs, _diag_weapon_abs],
	]
	lines.append_array(_monster_hud_lines())
	lines.append("")
	lines.append("hold right mouse = move   Shift+right mouse = run   release = stop")
	lines.append("F7 = respawn monsters   F9 = 诊断打印   Esc = quit")
	_hud.text = "\n".join(lines)


## HUD 怪物块：生成数量、每只位置/方向/与玩家距离，并标出最近一只。
func _monster_hud_lines() -> Array:
	var alive := 0
	for m in _monsters:
		if is_instance_valid(m):
			alive += 1
	var lines := ["monsters   : %d/%d" % [alive, monster_count]]
	if _player == null or alive == 0:
		return lines
	var nearest_d := INF
	var nearest_i := -1
	for i in range(_monsters.size()):
		var m = _monsters[i]
		if not is_instance_valid(m):
			continue
		var d: float = (m.global_position - _player.global_position).length()
		if d < nearest_d:
			nearest_d = d
			nearest_i = i
	for i in range(_monsters.size()):
		var m = _monsters[i]
		if not is_instance_valid(m):
			continue
		var d: float = (m.global_position - _player.global_position).length()
		var body := m as CharacterBody2D
		var monster: Node = body.get_monster() if body != null and body.has_method("get_monster") else null
		lines.append("  [%d] (%.0f, %.0f) dir=%-2s dist=%.0f%s" % [
			i, m.global_position.x, m.global_position.y, str(monster.last_direction) if monster != null else "?", d,
			"  <- nearest" if i == nearest_i else "",
		])
	return lines


## 诊断：列出场景中全部 AnimatedSprite2D（排查重复人物实例），
## 并打印 Player / SpriteAnchor / Camera2D 的精确坐标、相机平滑与纹理过滤设置，
## 以及 Hair/Weapon 图层当前纹理与 placement。
func _print_sprite_diagnostics() -> void:
	print("=== AnimatedSprite2D diagnostics ===")
	var sprites := _find_sprites(get_tree().root)
	for s in sprites:
		print("%s | global_pos=(%.6f, %.6f) visible=%s z_index=%d" % [
			s.get_path(), s.global_position.x, s.global_position.y, str(s.visible), s.z_index,
		])
	if _player == null:
		return
	print("=== Position / camera diagnostics ===")
	print("Player     global_pos = (%.6f, %.6f)" % [_player.global_position.x, _player.global_position.y])
	var anchor := _player.get_node_or_null("SpriteAnchor") as Node2D
	if anchor != null:
		print("SpriteAnchor pos       = (%.6f, %.6f)  global_pos = (%.6f, %.6f)" % [
			anchor.position.x, anchor.position.y, anchor.global_position.x, anchor.global_position.y,
		])
	var cam := _player.get_node_or_null("Camera2D") as Camera2D
	if cam != null:
		print("Camera2D   global_pos = (%.6f, %.6f)  smoothing_enabled=%s  zoom=(%.3f, %.3f)" % [
			cam.global_position.x, cam.global_position.y, str(cam.position_smoothing_enabled),
			cam.zoom.x, cam.zoom.y,
		])
	var spr := _player.get_node_or_null("SpriteAnchor/AnimatedSprite2D") as AnimatedSprite2D
	if spr != null:
		print("Body texture_filter = %d (0=Default/Linear 1=Nearest)" % spr.texture_filter)
	print("=== Hair / Weapon layer diagnostics ===")
	_print_layer_diag("Hair", _hair_anchor, _hair_sprite, _diag_hair_abs)
	_print_layer_diag("Weapon", _weapon_anchor, _weapon_sprite, _diag_weapon_abs)


func _print_layer_diag(label: String, anchor: Node2D, sprite: Sprite2D, abs_idx: int) -> void:
	if anchor == null or sprite == null:
		print("%s layer : NOT BUILT" % label)
		return
	var tex_path := "none" if sprite.texture == null else sprite.texture.resource_path
	print("%s layer : abs=%d visible=%s z_index=%d centered=%s pos=(%.2f, %.2f) offset=(%.2f, %.2f) anchor_pos=(%.2f, %.2f) texture=%s" % [
		label, abs_idx, str(sprite.visible), sprite.z_index, str(sprite.centered),
		sprite.position.x, sprite.position.y, sprite.offset.x, sprite.offset.y,
		anchor.position.x, anchor.position.y, tex_path,
	])


func _find_sprites(root_node: Node) -> Array:
	var out: Array = []
	for c in root_node.get_children():
		if c is AnimatedSprite2D:
			out.append(c)
		out.append_array(_find_sprites(c))
	return out
