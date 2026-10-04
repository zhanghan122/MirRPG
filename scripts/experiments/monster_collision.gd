extends CharacterBody2D

# MonsterCollision: 怪物动画场景（ForestStranger 等）的物理包装体。
# 怪物根节点保持为纯动画场景；本身体负责碰撞 + PHASE 4 追击/攻击 AI（move_and_slide）。
#
# 碰撞形状是脚底附近的小圆，不按整张图片大小：
#   由 Mon1 placements 实测，森林怪人各方向 idle 帧的脚底（最低不透明像素）
#   位于怪物根原点下方 y≈+26..+41，故圆放在 (0, +30)、半径 16。
#
# 碰撞层约定（地面为 layer 0，不参与碰撞）：
#   1 = 世界边界 / 静态障碍（combat_field_test 的 WorldBoundary 墙）
#   2 = 玩家（Hum CharacterBody2D）
#   4 = 怪物（本身体）
# 本身体: layer=4, mask=1|4 → 与墙、玩家碰撞；不与地面碰撞。

# ===== 战斗属性（PHASE 3：血条 + 测试伤害）=====
@export var max_hp := 100.0
var hp := 100.0

# ===== PHASE 4e+：怪物死亡（死亡动画 → 定格 corpse_hold_time 秒 → 淡出消失）=====
## 死亡动画播完（forest_stranger 停末帧、dead=true）后，尸体定格 corpse_hold_time 秒，
## 再以 corpse_fade_time 秒淡出（modulate:a→0，血条随本体一起淡出）并从场景移除。
@export var corpse_hold_time := 5.0
@export var corpse_fade_time := 1.0

var _death_started := false
# ===== PHASE 4：追击 + 攻击 AI（经子动画场景公开 API 驱动；forest_stranger.gd 冻结不改）=====
## 追击目标（玩家）。由 combat_field_test 生成时注入；null = 不启用 AI。
var target: Node2D = null
@export var chase_speed := 140.0   # px/s，慢于玩家 walk 200，保证玩家能拉开距离
@export var settle_speed := 60.0   # px/s，上方接近滑入视觉偏移时的速度

# 停止攻击距离（中心距），按怪物所处一侧区分：
# - 其他侧（怪物在玩家 e/w/se/s/sw 侧）：停在 attack_distance=48 —— ≈ 玩家身位一半（视觉身高 ~96px / 2）+ 少量冗余，
#   近战贴身但不接触；且 > 非上方侧最大物理接触距离（e/w=40），无需重叠。inspector 可微调。
# - 上方侧（怪物从 N/NE/NW 接近，即面向 s/se/sw）：脚圆在 (0,+30) r16 → 下缘到 origin+46；
#   玩家 box 半高 32 → 物理接触中心距 = 46+32 = 78（下方侧仅 18、左右侧 40）。
#   停在 78 处怪物脚底落在人物头颈处；要站到小腿/膝盖位置必须与玩家重叠 →
#   进入范围后禁用本身体碰撞形状（set_collision_enabled(false)），以 settle_speed 滑入
#   attack_distance_from_above（实机确认后可在 inspector 微调）。
#   注意：不能靠改 mask 的 layer 2 位——玩家自身 mask=7 已含怪物层，碰撞对仍成立。
@export var attack_distance := 48.0
@export var attack_distance_from_above := 26.0
## 上方侧进入攻击范围的阈值：必须 > 物理接触距离（78），否则怪物会先顶住玩家、永远进不了攻击。
const ATTACK_ENTRY_FROM_ABOVE := 84.0

# ===== PHASE 4b：怪物攻击力（每次攻击周期随机一次伤害）=====
## 单次攻击对目标造成 [attack_min, attack_max] 内随机整数伤害；
## 最终伤害 = max(1, 原始伤害 - 目标防御)。玩家防御目前 0–1（护甲后期加入）。
@export var attack_min := 2
@export var attack_max := 5
## 受击对象（默认跟随 target）。combat_field_test 中 target=玩家物理体（供移动），
## 而 HP/defense 接口在场景根节点 → 需单独指定 damage_target=根节点。
@export var damage_target: Node
# PHASE 4c：roll 出 attack_max（即打出 5）视为暴击 → 调目标 apply_stun() 触发玩家硬直；
## 免疫窗口由目标侧自判（combat_field_test.apply_stun），本文件不持有硬直状态。

# 怪物面向这些方向 = 位于玩家上方一侧（从 N/NE/NW 接近）。
const _ABOVE_FACING := ["s", "se", "sw"]

func take_damage(amount: float) -> void:
	if _death_started:
		return   # PHASE 4e+：死亡序列已启动，不再结算伤害
	hp = maxf(hp - amount, 0.0)
	if hp <= 0.0:
		_start_death()


func heal(amount: float) -> void:
	if _death_started:
		return   # PHASE 4e+：死亡序列不可回滚（怪物恢复走 F7 重生）
	hp = minf(hp + amount, max_hp)


func reset_health() -> void:
	if _death_started:
		return
	hp = max_hp


func is_dead() -> bool:
	return hp <= 0.0


## PHASE 4e+：启动死亡序列 —— play_death（forest_stranger 公开 API，冻结文件未动）；
## AI 已由 _physics_process 的 is_dead() 守卫停止；禁用碰撞形状使尸体不再阻挡移动。
func _start_death() -> void:
	if _death_started:
		return
	_death_started = true
	print("[M-DEATH] monster hp=0 — death anim, hold %.1fs, fade %.1fs" % [corpse_hold_time, corpse_fade_time])
	set_collision_enabled(false)
	_run_corpse_sequence()


## PHASE 4e+：尸体序列协程 —— 等死亡动画播完（dead=true、停末帧）→ 定格 → 淡出 → 移除。
func _run_corpse_sequence() -> void:
	var monster := get_monster()
	if monster != null and monster.has_method("play_death"):
		monster.play_death()
	while monster != null and is_instance_valid(monster) and not ("dead" in monster and bool(monster.dead)):
		await get_tree().process_frame
	if not is_inside_tree():
		return   # 已被外部释放（如 F7 重生），中止序列
	await get_tree().create_timer(corpse_hold_time).timeout
	if not is_inside_tree():
		return
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, corpse_fade_time)
	await tw.finished
	queue_free()


var _shape_node: CollisionShape2D


func _ready() -> void:
	_shape_node = get_node_or_null("FeetShape") as CollisionShape2D
	hp = clampf(hp, 0.0, max_hp)   # 防止 inspector 里 max_hp 改小后 hp 越界


## 启用/禁用本身体碰撞形状（PHASE 4 上方侧重叠滑入用；未来死亡处理也可复用）。状态未变化时不重复设置。
var _collision_enabled := true


func set_collision_enabled(enabled: bool) -> void:
	if enabled == _collision_enabled or _shape_node == null:
		return
	_collision_enabled = enabled
	_shape_node.set_deferred("disabled", not enabled)


## PHASE 4b：一次出手结算 —— 随机 [attack_min, attack_max]，减去目标防御，最低 1。
## 受击对象接口：take_damage(amount) + defense（combat_field_test.gd 根节点的玩家属性）。
func _deal_hit_to_target() -> void:
	var t := damage_target if (damage_target != null and is_instance_valid(damage_target)) else target
	if t == null or not is_instance_valid(t) or not t.has_method("take_damage"):
		return
	var raw := randi_range(attack_min, attack_max)
	var defense := float(t.defense) if "defense" in t else 0.0
	var final_dmg := maxf(1.0, float(raw) - defense)
	t.take_damage(final_dmg)
	# PHASE 4c：roll 出最大值（== attack_max，即打出 5）视为暴击 → 触发玩家硬直。
	# 是否接受由目标自判（免疫窗口内只受伤、不重复硬直）。
	var crit := raw >= attack_max
	var stunned := false
	if crit and t.has_method("apply_stun"):
		stunned = bool(t.apply_stun())
	print("[HIT] monster atk=%d def=%.0f -> player -%.0f (hp %.0f/%.0f)%s" % [
		raw, defense, final_dmg,
		float(t.hp) if "hp" in t else 0.0,
		float(t.max_hp) if "max_hp" in t else 0.0,
		"   CRIT -> STUN" if stunned else ("   crit (immune)" if crit else "")])


# 返回子怪物动画节点（ForestStranger）。
func get_monster() -> Node2D:
	for child in get_children():
		if not (child is CollisionShape2D):
			return child as Node2D
	return null


# ===== PHASE 4：追击 + 攻击 AI =====

## 每物理帧：进入攻击范围 → 面向玩家播放攻击；否则朝玩家行走。
## 动画经 ForestStranger 公开 API 驱动（play_walk / play_attack / set_direction）：
## - play_* 对同一动画幂等（forest_stranger._play 内部守卫），逐帧调用安全；
## - attack 单次播完自动回同方向 idle，下一帧再次触发 → 在范围内持续攻击直到离开范围。
func _physics_process(_delta: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	if is_dead():
		return   # PHASE 4e+：死亡序列（动画→定格→淡出）由 take_damage 触发驱动，此处只停 AI。
	# PHASE 4d：玩家已死 → 停止追击/攻击，原地站定（当前动画自然播完）。
	var dmg_t := damage_target if (damage_target != null and is_instance_valid(damage_target)) else target
	if dmg_t != null and dmg_t.has_method("is_dead") and bool(dmg_t.is_dead()):
		return
	var monster := get_monster()
	if monster == null:
		return
	var to_target := target.global_position - global_position
	var dist := to_target.length()
	if dist < 0.001:
		return
	var step_dir := to_target / dist   # 怪物 → 玩家
	# 八方向量化（与玩家侧 _direction_name 相同阈值规则）：面向玩家并切换动画方向。
	var dir_name := _dir8(step_dir)
	if String(monster.last_direction) != dir_name:
		monster.set_direction(dir_name)
	var from_above := dir_name in _ABOVE_FACING
	var entry_dist := ATTACK_ENTRY_FROM_ABOVE if from_above else attack_distance
	if dist <= entry_dist:
		# 在攻击范围内：面向玩家持续播放攻击。
		# 新攻击周期（上一状态不是 attack）= 一次出手 → 结算一次伤害；
		# attack 动画播放期间 current_action=="attack"，不会重复结算。
		var new_cycle := String(monster.current_action) != "attack"
		monster.play_attack()
		if new_cycle:
			_deal_hit_to_target()
		if from_above:
			# 上方侧需要与玩家重叠才能站到小腿/膝盖位置：范围内保持碰撞形状禁用，
			# 未到位时以 settle_speed 滑入目标偏移；离开范围（玩家走开）立即恢复碰撞。
			set_collision_enabled(false)
			if dist > attack_distance_from_above + 0.5:
				var away := -step_dir   # 玩家 → 怪物方向
				var point := target.global_position + away * attack_distance_from_above
				velocity = (point - global_position).limit_length(settle_speed)
			else:
				velocity = Vector2.ZERO
		else:
			set_collision_enabled(true)
			velocity = Vector2.ZERO
	else:
		# 追击：朝玩家当前位置行走。
		set_collision_enabled(true)
		monster.play_walk()
		velocity = step_dir * chase_speed
	move_and_slide()


## 八方向量化，与 combat_field_test._direction_name / hum_character.gd 相同阈值规则（作用于单位向量）。
func _dir8(v: Vector2) -> String:
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
	return "s"
