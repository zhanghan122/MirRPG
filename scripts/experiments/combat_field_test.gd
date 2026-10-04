extends Node2D
## combat_field_test.gd — 战斗地图测试 PHASE 3（在 PHASE 2 基础上增加血条与测试伤害）。
##
## PHASE 3 新增：
## - HealthBar 组件（res://scenes/health_bar.tscn + res://scripts/health_bar.gd）：
##   Node2D + Background/Foreground 两个 ColorRect，前景按 hp 百分比缩放、红→绿插值。
##   不用 ProgressBar，避免主题样式干扰像素风。
## - 头顶固定偏移（实测后常量，挂载时一次性设置，之后不逐帧移动）：
##     MONSTER_BAR_Y = -70  （森林怪人各动作头顶范围 y≈-51..-63，留 7px 间隙）
##   玩家无头顶血条：HP 数值保留（F8/F9/F10 测试键 + HUD 文本），稍后由操作界面 UI 表示。
## - 属性接口（数值 + 血条显示；PHASE 4b 起怪物每次攻击周期对玩家结算一次伤害，仍无死亡行为）：
##   take_damage(amount) / heal(amount) / reset_health() / is_dead()
##     * 玩家侧定义在本脚本（hum_character.gd 不修改），含 defense（目前 0–1，护甲后期加入）；
##     * 怪物侧定义在 monster_collision.gd，含 attack_min/attack_max（单次随机伤害）。
##   伤害公式：最终 = max(1, randi_range(attack_min, attack_max) - 目标 defense)。
## - 测试按键：F8 = 玩家受击 10   F9 = 全体怪物各受击 10   F10 = 全部回满血
##   （原 F9 诊断打印移至 F12）。
##
## PHASE 2（最小地图 + 按住右键移动 + Hair/Weapon 图层）：
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
## - PHASE 2 时无攻击判定/AI；PHASE 3 起有 HP/血条/测试伤害；
##   PHASE 4 怪物追击玩家、到面前播放攻击动作（仍无命中判定/伤害，死亡行为亦为未来阶段）。
##   上方侧（N/NE/NW）接近允许与玩家受控重叠、站到小腿/膝盖位置（monster_collision.gd 内实现）。

const GRASS_COLOR := Color(0.29, 0.56, 0.24)
const BORDER_COLOR := Color(0.43, 0.29, 0.16)
const MARKER_COLOR := Color(1.0, 0.85, 0.3, 0.9)

# Hair/Weapon 组基址（appearance 0；索引规则见文件头注释）。
const HAIR_BASE := 1200
const WEAPON_BASE := 31200

# ===== PHASE 3：怪物血条头顶固定偏移（实测值，挂载时一次性设置）=====
# 玩家不再使用头顶血条（HP 稍后由操作界面 UI 表示），仅怪物保留头顶条。
# 森林怪人 280-547 各动作帧实测：头顶范围 y≈-51(idle/walk)..-63(death 倒地)；
# 条底边 -70 → 与最高点头留 7px 间隙。
const MONSTER_BAR_Y := -70.0

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

# ===== PHASE 3/4b：玩家战斗属性（hum_character.gd 不修改，故定义在本测试脚本）=====
@export var max_hp := 100.0
var hp := 100.0
@export var attack_damage := 25.0   # PHASE 4e：普通攻击单次伤害；暴击 = × attack_crit_multiplier
## 玩家防御：目前 0–1（护甲后期加入）。怪物单次伤害 = max(1, 随机攻击力 - defense)。
@export var defense := 0

# ===== PHASE 4c：玩家受击硬直（stagger）=====
## hum "hit" 动作 = 3 帧 @10fps = 0.3s；播放期间 hum_character 的 action_locked=true 自动封锁移动。
const HIT_STUN_DURATION := 0.3
## 硬直结束后再免疫约 1–2s（防连续硬直致死）；免疫期内伤害照常结算，只是不再触发新硬直。
@export var stun_immunity_after := 1.5
var is_stunned := false
var _stun_immune_until := 0.0   # Time.get_ticks_msec()/1000.0 时间戳

## 怪物「暴击」（roll 出 attack_max）时调用。返回是否接受本次硬直。
func apply_stun() -> bool:
	if is_dead() or is_stunned or _player == null:
		return false
	var now := Time.get_ticks_msec() / 1000.0
	if now < _stun_immune_until:
		return false   # 免疫窗口内：伤害照常，但不重复硬直
	is_stunned = true
	_player.play_directional_action("hit")
	_stun_immune_until = now + HIT_STUN_DURATION + stun_immunity_after
	print("[STUN] player staggered %.1fs, then %.1fs stun-immune" % [HIT_STUN_DURATION, stun_immunity_after])
	return true


# ===== PHASE 4e：玩家攻击（按住左键连续普通攻击；暴击用重击动画）=====
## 普通攻击 = hum "attack_onehand"（6帧@10fps=0.6s，不循环）；暴击/重击 = "attack_power"（8帧@12fps≈0.67s）。
## 两者播完 hum_character 自动回 idle；左键仍按住 → 下一物理帧再触发一次出手 → 按住即连续攻击。
## 暴击率沿用怪物侧约定（怪物暴击=roll出最大值≈1/5）；重击伤害 = attack_damage × attack_crit_multiplier。
## 命中判定：目标中心距 ≤ attack_range，且位于面向 ±45° 锥内（dot ≥ cos45°）。伤害在出手瞬间结算。
@export var attack_crit_chance := 0.2
@export var attack_crit_multiplier := 2.0
@export var attack_range := 96.0
const ATTACK_CONE_COS := 0.7071

var left_mouse_held := false
# HUD/测试诊断：累计出手次数、最近一次是否暴击与命中数。
var player_attacks_done := 0
var last_attack_crit := false
var last_attack_hits := 0

## 八方向单位向量（对角 = ±1/√2 ≈ ±0.7071068）。
const _DIR_VECTORS := {
	"n": Vector2(0, -1), "ne": Vector2(0.7071068, -0.7071068), "e": Vector2(1, 0),
	"se": Vector2(0.7071068, 0.7071068), "s": Vector2(0, 1), "sw": Vector2(-0.7071068, 0.7071068),
	"w": Vector2(-1, 0), "nw": Vector2(-0.7071068, -0.7071068),
}


## PHASE 4g：攻击结束后一次性恢复移动动画（实机问题：右键+Shift 跑步中攻击后，
## 人物继续位移但 Run 动画停在单帧、腿不再循环，像弓步滑行）。
## 原因：hum 的 _on_animation_finished 会把 action_locked 置 false，而右键移动依赖
## 「右键按下时设置的 action_locked=true」来压制 hum 自身 _physics_process 里
## 「无输入即 current_action='idle' + _play('idle_<dir>')」的逻辑。攻击结束后锁被解除，
## hum 每物理帧把动作顶回 idle，父节点的 run_<dir> 每帧被重启在 frame 0 → 单帧定格。
## 修法（只在本文件、只在「攻击结束 → 恢复移动」这一个状态转换点调用一次）：
## 按当前输入状态重新启动 run_<dir> / walk_<dir> / idle_<dir>（先 frame=0 再 play 强制重启），
## 并恢复移动锁；不改 hum_character.gd、不改全局 _play()、不改帧数组/FPS/loop。
var _resume_move_after_attack := false


## PHASE 4g：攻击/硬直动画播放中（标记用于结束后的移动恢复）。
func _mark_attack_anim_started() -> void:
	_resume_move_after_attack = true


## PHASE 4g：攻击结束 → 按「右键是否仍按住 / Shift 是否仍按住」一次性恢复移动动画。
func _resume_move_animation() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var spr := _player.get_node_or_null("SpriteAnchor/AnimatedSprite2D") as AnimatedSprite2D
	var dir_name := String(_player.last_direction)
	var shift_held := Input.is_physical_key_pressed(KEY_SHIFT)
	var alive := not is_dead() and not bool(_player.dead)
	var resume := "idle"
	var anim_name := "idle_" + dir_name
	var force_restart := false
	if alive:
		# 右键仍按住：Shift 仍按住 → run_<dir>，否则 walk_<dir>；右键已松开 → idle_<dir>。
		if right_mouse_held:
			resume = "run" if shift_held else "walk"
			anim_name = ("run_" if shift_held else "walk_") + dir_name
		force_restart = true
	else:
		# 玩家已死：不打断也不重启 death 序列（death 播完停末帧，由 hum 自己锁定）。
		resume = "death"
		anim_name = "death_" + dir_name
	# 恢复移动锁（与右键按下时一致）；死亡分支不动 hum 的 death 锁。
	_player.action_locked = right_mouse_held and alive
	if alive:
		_player.current_action = resume
	# 强制重启动画：先归零 frame 再 play()，确保真正开始循环
	# （hum 的 _play() 在「同名且 is_playing」时会提前 return，无法用来强制重启）。
	if force_restart and spr != null and spr.sprite_frames != null \
			and spr.sprite_frames.has_animation(StringName(anim_name)):
		spr.frame = 0
		spr.play(StringName(anim_name))   # 切换/重启 → frame_changed → hum 自动应用 placement
	var playing := spr != null and spr.is_playing()
	var frame := int(spr.frame) if spr != null else -1
	print("[P-ATK-END] right_held=%s shift=%s resume=%s animation=%s playing=%s frame=%d locked=%s" % [
		str(right_mouse_held), str(shift_held), resume, anim_name, str(playing), frame,
		str(_player.action_locked)])


## PHASE 4e：左键按住 = 连续攻击。触发条件：未死、未硬直、当前动作为 idle|walk|run
## （攻击/hit/death 动画进行中 → 等待其播完，hum 自动回 idle 后下一帧再触发）。
func _try_player_attack() -> void:
	if not left_mouse_held or is_dead() or is_stunned or _player == null:
		return
	var action := String(_player.current_action)
	if action != "idle" and action != "walk" and action != "run":
		return
	var crit := randf() < attack_crit_chance
	_resolve_player_attack(crit)
	_mark_attack_anim_started()   # PHASE 4g：标记需要在动画结束后恢复移动动画
	_player.play_directional_action("attack_power" if crit else "attack_onehand")


## PHASE 4e：一次出手的伤害结算 —— 面向 ±45° 锥内、≤ attack_range 的全部存活怪物。
func _resolve_player_attack(crit: bool) -> void:
	var dmg := attack_damage * (attack_crit_multiplier if crit else 1.0)
	var facing: Vector2 = _DIR_VECTORS.get(String(_player.last_direction), Vector2(0, 1))
	var hits := 0
	for m in _monsters:
		if not is_instance_valid(m):
			continue
		if "is_dead" in m and bool(m.is_dead()):
			continue
		var delta_vec: Vector2 = (m as Node2D).global_position - _player.global_position
		var dist := delta_vec.length()
		if dist < 0.001 or dist > attack_range:
			continue
		if delta_vec.normalized().dot(facing) < ATTACK_CONE_COS:
			continue
		m.take_damage(dmg)
		hits += 1
	player_attacks_done += 1
	last_attack_crit = crit
	last_attack_hits = hits
	print("[P-ATK] %s dmg=%.0f -> %d monster(s)" % ["CRIT" if crit else "hit", dmg, hits])


## PHASE 4e：玩家是否正在播放攻击动画（用于移动暂停与右键松开守卫）。
func _is_player_attacking() -> bool:
	return String(_player.current_action) in ["attack_onehand", "attack_power"]


## PHASE 4c：hit 动画播完（animation_finished）→ 硬直结束；hum_character 同时自动回 idle。
## PHASE 4g：攻击/硬直动画播完的那一个状态转换点 → 一次性恢复移动动画（run/walk/idle）。
## 注意回调顺序：hum 自己的 _on_animation_finished 先连接先执行，故此处 current_action 已被
## hum 改成 idle/death；「刚才是攻击」由 _resume_move_after_attack 标记判断，不依赖 current_action。
func _on_player_anim_finished() -> void:
	if is_stunned:
		is_stunned = false
	if _resume_move_after_attack:
		_resume_move_after_attack = false
		_resume_move_animation()   # 只在此转换点调用一次，不在每个物理帧重复重启

# ===== PHASE 4d：玩家死亡（死亡动画 + 怪物停止攻击 + 屏幕缓慢褪为黑白）=====
## 屏幕灰度淡入/淡出时长（秒），「慢慢」→ 默认 3s。
@export var death_fade_duration := 3.0
## 灰色叠加层最大 alpha（压暗氛围）；真正的去饱和由 WorldEnvironment saturation 调整完成。
const DEATH_OVERLAY_MAX_ALPHA := 0.4
var _fade_value := 0.0        # 当前 fade 值 0..1
var _fade_target := 0.0       # 目标值：1 = 死亡，0 = 存活
var _death_env: Environment   # WorldEnvironment 的环境资源（saturation 1→0）
var _overlay_rect: ColorRect  # 全屏灰色叠加层（alpha 0 → DEATH_OVERLAY_MAX_ALPHA）


func take_damage(amount: float) -> void:
	if is_dead():
		return   # PHASE 4d：已死不再结算伤害（怪物侧也已停止攻击）
	hp = maxf(hp - amount, 0.0)
	if hp <= 0.0:
		_on_player_died()


## PHASE 4d：玩家死亡 —— hum 播放 death_<dir>（播完停在最后一帧、dead=true），
## 怪物自行检查 is_dead() 停止追击/攻击，屏幕在 death_fade_duration 内褪为黑白。
func _on_player_died() -> void:
	print("[DEATH] player hp=0 — death anim, monsters stop, grayscale fade %.1fs" % death_fade_duration)
	is_stunned = false   # 死亡优先于硬直状态
	if _player != null and not bool(_player.dead):
		_player.play_directional_action("death")
	_fade_target = 1.0


func heal(amount: float) -> void:
	hp = minf(hp + amount, max_hp)


func reset_health() -> void:
	hp = max_hp
	# PHASE 4d：若玩家处于死亡状态，回满血即复活（recover 回 idle、屏幕褪回彩色）。
	if _player != null and bool(_player.dead):
		_player.recover()
		is_stunned = false
		_stun_immune_until = 0.0
		_fade_target = 0.0


func is_dead() -> bool:
	return hp <= 0.0

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
# PHASE 3：怪物血条（挂在各 MonsterCollision 下自动跟随，名 "HealthBar"）；玩家无头顶血条。
const HEALTH_BAR_SCENE := preload("res://scenes/health_bar.tscn")


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
	var body_sprite := _player.get_node_or_null("SpriteAnchor/AnimatedSprite2D") as AnimatedSprite2D
	if body_sprite != null:
		body_sprite.z_index = 1
		# PHASE 4c：监听动画结束 → hit 播完即解除硬直（不用固定 Timer，符合 HUM_FRAME_RULES）。
		if not body_sprite.animation_finished.is_connected(_on_player_anim_finished):
			body_sprite.animation_finished.connect(_on_player_anim_finished)

	_player.global_position = map_size * 0.5
	var cam := _player.get_node_or_null("Camera2D") as Camera2D
	if cam != null:
		# 抖动诊断第一轮：只关闭相机平滑，不修改其他设置（等待实机测试）。
		cam.position_smoothing_enabled = false
	_build_death_fade_overlay()
	_spawn_monsters()
	_update_depth_sort()
	_print_sprite_diagnostics()


## PHASE 4d：屏幕黑白淡入 = WorldEnvironment saturation 调整（真去饱和，作用于整个 viewport）
## + 全屏灰色叠加层（压暗氛围）。两者都由 _fade_value(0..1) 驱动。
func _build_death_fade_overlay() -> void:
	var env := Environment.new()
	env.adjustment_saturation = 1.0
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	_death_env = env
	var layer := CanvasLayer.new()
	layer.layer = 20   # 高于 HUD，死亡时整个屏幕（含 HUD）一起褪为黑白
	add_child(layer)
	var rect := ColorRect.new()
	rect.color = Color(0.5, 0.5, 0.5, 0.0)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(rect)
	_overlay_rect = rect


## PHASE 4d：每帧向 _fade_target 缓动 fade（死亡→1，复活→0），速度 = 1/death_fade_duration。
func _update_death_fade(delta: float) -> void:
	var step := delta / maxf(death_fade_duration, 0.1)
	if _fade_value < _fade_target:
		_fade_value = minf(_fade_value + step, _fade_target)
	elif _fade_value > _fade_target:
		_fade_value = maxf(_fade_value - step, _fade_target)
	if _death_env != null and is_instance_valid(_death_env):
		_death_env.adjustment_saturation = lerpf(1.0, 0.0, _fade_value)
	if _overlay_rect != null and is_instance_valid(_overlay_rect):
		_overlay_rect.color = Color(0.5, 0.5, 0.5, DEATH_OVERLAY_MAX_ALPHA * _fade_value)


func _process(delta: float) -> void:
	_update_death_fade(delta)
	_update_hair_weapon()
	_update_depth_sort()
	_update_health_bars()
	_update_hud()


## PHASE 3：每帧把怪物当前 hp 同步到各自血条（条本身不移动，只改前景宽度与颜色）。
func _update_health_bars() -> void:
	for m in _monsters:
		if not is_instance_valid(m):
			continue
		var bar := (m as Node).get_node_or_null("HealthBar")
		if bar != null and "hp" in m:
			bar.set_hp(m.hp, m.max_hp)


func _physics_process(delta: float) -> void:
	if _player == null:
		return
	# PHASE 4e：左键按住 = 连续攻击（独立于右键移动状态；挥击期间原地站定）。
	_try_player_attack()
	# PHASE 4c：硬直期间强制站定 —— 不移动、也不播放 walk/run（否则会打断 hit 动画）。
	if not right_mouse_held or is_stunned:
		return
	# PHASE 4e：攻击动画进行中 → 本帧暂停移动，避免 walk/run 覆盖挥击动画
	# （hum_character 的 action_locked 已把自身 velocity 清零，不会漂移）。
	if _is_player_attacking():
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
	if mi == null:
		return
	if mi.button_index == MOUSE_BUTTON_LEFT:
		# PHASE 4e：左键按住 = 连续攻击（由 _physics_process 轮询触发；松开即停）。
		left_mouse_held = mi.pressed
		return
	if mi.button_index != MOUSE_BUTTON_RIGHT:
		return
	right_mouse_held = mi.pressed
	if is_stunned:
		# PHASE 4c：硬直期间忽略右键状态切换 —— 不清 action_locked、不强制 idle，
		# 避免打断 hit 动画；移动本身已被 _physics_process 的 is_stunned 守卫封锁。
		return
	if mi.pressed:
		# 最小临时处理：按住期间冻结角色自身输入状态机，防止其覆盖动画。
		_player.action_locked = true
		_marker.show()
	else:
		# 松开 → 立即停止（清零速度）+ 最后方向 idle，然后恢复 action_locked。
		_player.velocity = Vector2.ZERO
		# PHASE 4e：挥击进行中不强制 idle —— 让本次攻击播完，hum 结束后自动回 idle。
		if not _is_player_attacking():
			_set_action("idle")
			_player.action_locked = false
		_marker.hide()


## PHASE 4c：硬直期间禁止的角色动作键（攻击/施法/挖掘等）——在此吞掉，hum_character 收不到。
const _STUN_BLOCKED_KEYS := [KEY_J, KEY_K, KEY_L, KEY_U, KEY_I, KEY_H]


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	# PHASE 4c：硬直时不能攻击/触发任何角色动作（动画播完才能动）。
	if is_stunned and key.keycode in _STUN_BLOCKED_KEYS:
		get_viewport().set_input_as_handled()
		return
	if key.keycode == KEY_ESCAPE:
		get_tree().quit()
	elif key.keycode == KEY_F8:
		# PHASE 3 测试：玩家受击 10（血条应缩短、颜色偏红）。
		take_damage(10)
		print("[F8] player hp = %.0f / %.0f" % [hp, max_hp])
	elif key.keycode == KEY_F9:
		# PHASE 3 测试：全体存活怪物各受击 10（各自血条应缩短）。
		var hit := 0
		for m in _monsters:
			if is_instance_valid(m) and m.has_method("take_damage") and not m.is_dead():
				m.take_damage(10)
				hit += 1
		print("[F9] %d monsters -10 hp each" % hit)
	elif key.keycode == KEY_F10:
		# PHASE 3 测试：玩家与全体怪物回满血。
		reset_health()
		for m in _monsters:
			if is_instance_valid(m) and m.has_method("reset_health"):
				m.reset_health()
		print("[F10] all HP reset to full")
	elif key.keycode == KEY_F11:
		# PHASE 4c 测试：手动触发一次玩家硬直（验证 hit 动画 + 免疫窗口）。
		var ok := apply_stun()
		print("[F11] force stun -> %s" % ("accepted" if ok else "rejected (stunned/immune/dead)"))
	elif key.keycode == KEY_F7:
		# PHASE 4d：玩家已死则先复活（回满血 + recover + 屏幕褪回彩色），再重新生成怪物。
		if is_dead():
			reset_health()
		_spawn_monsters()
	elif key.keycode == KEY_F12:
		# 诊断：随时重新打印 Sprite/位置/相机/Hair-Weapon 图层状态。
		_print_sprite_diagnostics()


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
	body.target = _player   # PHASE 4：追击目标=玩家；进入场景后 AI 立即接管移动/攻击。
	# PHASE 4b：受击对象=本根节点（HP/defense 接口在此，$Player 上没有）。
	body.damage_target = self
	body.add_child(m)  # 触发其 _ready → 播放该方向 idle，随后由 MonsterCollision 的 PHASE 4 AI 驱动。
	# PHASE 3：怪物血条挂在物理体（角色物理根节点）下，与动画场景同级；
	# HealthBar.position = Vector2(+条宽*0.5, MONSTER_BAR_Y)，一次性设置；
	# X 向右补偿条自身长度 50%（默认条宽 50px → +25px），使血条向身体视觉中心靠拢。
	# z_index 由 _update_depth_sort() 每帧设为 动画层+1，保证随深度排序正确遮挡。
	var bar := HEALTH_BAR_SCENE.instantiate() as Node2D
	bar.name = "HealthBar"
	bar.position = Vector2(25, MONSTER_BAR_Y)
	body.add_child(bar)
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
		# PHASE 3：怪物血条 z = 动画层+1（盖在怪物身上，且随整体深度正确遮挡玩家）。
		var bar := (body.get_node_or_null("HealthBar") as CanvasItem) if body != null else null
		if bar != null:
			bar.z_index = z + 1


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
	# PHASE 4c：硬直状态显示（STUNNED / 免疫剩余时间）。
	var stun_text := ""
	if is_stunned:
		stun_text = "   STUNNED"
	elif Time.get_ticks_msec() / 1000.0 < _stun_immune_until:
		stun_text = "   stun-immune %.1fs" % (_stun_immune_until - Time.get_ticks_msec() / 1000.0)
	var lines := [
		"COMBAT FIELD TEST - PHASE 3",
		"player pos : (%.0f, %.0f)" % [_player.global_position.x, _player.global_position.y],
		"target     : " + target_text,
		"direction  : " + String(_player.last_direction),
		"action     : " + String(_player.current_action),
		"dist       : " + dist_text,
		"hair_abs   : %d    weapon_abs: %d" % [_diag_hair_abs, _diag_weapon_abs],
		"player HP  : %.0f / %.0f   def=%d%s%s" % [hp, max_hp, defense, "   (DEAD)" if is_dead() else "", stun_text],
	]
	var atk_last := ""
	if player_attacks_done > 0:
		atk_last = "   last=%s -%.0f -> %d" % ["CRIT" if last_attack_crit else "hit",
				attack_damage * (attack_crit_multiplier if last_attack_crit else 1.0), last_attack_hits]
	lines.append("attack     : LMB hold | crit=%.0f%% x%.1f range=%.0f%s" % [
			attack_crit_chance * 100.0, attack_crit_multiplier, attack_range, atk_last])
	if _fade_value > 0.0 or _fade_target > 0.0:
		lines.append("screen     : grayscale fade %.0f%%" % (_fade_value * 100.0))
	lines.append_array(_monster_hud_lines())
	lines.append("")
	lines.append("hold left mouse = attack (crit -> heavy)   hold right mouse = move   Shift+RMB = run")
	lines.append("F7=复活+重生怪 F8=player-10hp F9=monsters-10hp F10=reset HP(含复活) F11=硬直测试 F12=诊断 Esc=quit")
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
		var hp_text := "" if not ("hp" in m) else " hp=%.0f/%.0f%s" % [m.hp, m.max_hp, "(dead)" if m.is_dead() else ""]
		var atk_text := "" if not ("attack_min" in m) else " atk=%d-%d" % [int(m.attack_min), int(m.attack_max)]
		lines.append("  [%d] (%.0f, %.0f) dir=%-2s dist=%.0f%s%s%s" % [
			i, m.global_position.x, m.global_position.y, str(monster.last_direction) if monster != null else "?", d,
			hp_text, atk_text, "  <- nearest" if i == nearest_i else "",
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
