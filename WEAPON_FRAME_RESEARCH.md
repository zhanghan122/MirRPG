# WEAPON_FRAME_RESEARCH（武器 Idle 帧研究）

## 1. 任务范围

- 独立实验场景：`scenes/experiments/weapon_idle_test.tscn` + `scripts/experiments/weapon_idle_test.gd`。
- 稳定人物 `res://scenes/hum_character.tscn` / `res://scripts/hum_character.gd` 完全未修改，只被实例化和读取（`get_frame_info()`）。
- 武器只做覆盖显示：WeaponAnchor + WeaponSprite（Sprite2D），不控制人物、不修改身体 SpriteAnchor、不叠加身体 Placement。

## 2. 素材盘点（路径存在性检查）

- `res://Weapon/` PNG 总数：29742
- `res://Weapon/Placements/` txt 总数：45600
- 31200–31263 区间 Placement 全部存在，无缺失。
- 31200–31263 区间 PNG 缺失列表（共 32 个）：

```
31204, 31205, 31206, 31207   (slot NE 的后半)
31212, 31213, 31214, 31215   (slot SE 的后半)
31220, 31221, 31222, 31223   (slot SW 的后半)
31228, 31229, 31230, 31231   (slot NW 的后半)
31236-31239, 31244-31247, 31252-31255, 31260-31263 (各 slot 后半)
```

## 3. 候选 A / B 对比与结论

| 方向 | 候选A（8槽布局，每槽前4帧有效） | 候选B（连续4帧） |
|------|--------------------------------|------------------|
| n    | 31200-31203                    | 31200-31203      |
| ne   | 31208-31211                    | 31204-31207      |
| e    | 31216-31219                    | 31208-31211      |
| se   | 31224-31227                    | 31212-31215      |
| s    | 31232-31235                    | 31216-31219      |
| sw   | 31240-31243                    | 31220-31223      |
| w    | 31248-31251                    | 31224-31227      |
| nw   | 31256-31259                    | 31228-31231      |

**证据（支持候选 A）：**

1. PNG 存在性：候选 A 的 8 方向 × 4 帧 = 32 个 PNG 全部存在；
   候选 B 的 ne/se/sw/nw 四个范围（31204-31207、31212-31215、31220-31223、31228-31231）PNG 全部缺失。
2. Placement 值：候选 B 的四个对角范围 Placement 全部为 (0, 0)（占位空值）；
   候选 A 的全部 32 个索引都有非零、方向合理的 Placement。
3. 几何一致性：按候选 B 的解释，"e" 会取到 31208-31211，其 Placement 为 (24,-15)~(25,-20)，
   明显是东北侧偏移而非正东；只有候选 A 的方向标签与 Placement 几何一致。

**结论：武器 Idle 的真实布局是候选 A —— 8 个方向各占一个 8 索引槽位（N, NE, E, SE, S, SW, W, NW，
起始偏移 +0/+8/+16/+24/+32/+40/+48/+56），每槽只有前 4 帧有效，后 4 个索引为填充（无 PNG、Placement=0）。**

## 4. 候选 A Placement 值表（res://Weapon/Placements/%05d.txt）

| 方向 | 帧0 | 帧1 | 帧2 | 帧3 |
|------|-----|-----|-----|-----|
| n    | (35, -33)  | (35, -37) | (35, -39) | (35, -38) |
| ne   | (24, -15)  | (24, -19) | (25, -20) | (25, -20) |
| e    | (12, -12)  | (13, -11) | (13, -11) | (13, -11) |
| se   | (6, -18)   | (7, -18)  | (7, -17)  | (7, -17)  |
| s    | (-1, -26)  | (0, -25)  | (0, -25)  | (0, -25)  |
| sw   | (-30, -30) | (-31, -30)| (-32, -30)| (-32, -29)|
| w    | (-28, -27) | (-31, -27)| (-32, -27)| (-32, -27)|
| nw   | (2, -33)   | (0, -36)  | (-1, -38) | (0, -37)  |

## 5. 实验场景说明

节点结构：

```
WeaponIdleTest (Node2D, weapon_idle_test.gd)
├── Player (实例化 res://scenes/hum_character.tscn，稳定人物，未修改)
│   └── WeaponAnchor (Node2D)
│       └── WeaponSprite (Sprite2D, centered=false, position/offset=ZERO, flip_h=false)
└── HudCanvasLayer / HudLabel（画面显示）
```

按键：

- F5 = 显示/隐藏武器（just_pressed，切换一次生效一次）
- 1 = 使用候选 A
- 2 = 使用候选 B

行为规则：

- 武器只读取稳定人物当前动画的方向后缀（idle_s → s；walk_e → e），
  人物移动时继续显示当前方向的武器 Idle 帧，不实现武器 Walk。
- 每方向 4 帧循环，5 fps（与 Hum idle 一致，属本实验假设值）。
- Placement 预加载缓存（启动时读取候选 A+B 全部 60 个索引），运行时零磁盘读取；
  每次显示的武器帧变化时应用一次：`WeaponAnchor.position = Vector2(x, y)`（赋值，不累积、不叠加身体 Placement）。
- PNG 不存在时：`WeaponSprite.texture = null` 且 `visible = false`，不保留上一帧图片。

画面显示字段：当前人物方向 / 当前 Idle 候选(A/B) / 武器绝对编号 / PNG是否存在 / Placement X,Y / WeaponAnchor.position。

## 6. 验证状态

- Godot headless 检查：通过（场景加载、脚本解析无错误）。
- Idle 实机测试：已进行。W-idle 武器位置有固定视觉误差，其余方向待确认。
- Walk 实机测试：待进行（F7/F8 对比候选 A 与 B；预期候选 A 正确，见第 7 节证据）。

## 7. Walk 武器帧研究（2026-09-07）

### 7.1 身体 walk 规格（来自 hum_frames.gd / HUM_FRAME_RULES.md）

- body walk：每方向 **6 帧 @ 8fps**，循环。
- body idle：每方向 4 帧 @ 5fps，循环。
- 因此武器 walk 候选每方向取前 6 帧；idle 候选每方向取前 4 帧。

### 7.2 Walk 候选 A / B 索引表（31264–31325）

| 方向 | 候选A（8槽布局，每槽前6帧有效） | 候选B（连续6帧） |
|------|--------------------------------|------------------|
| n    | 31264-31269                    | 31264-31269      |
| ne   | 31272-31277                    | 31270-31275      |
| e    | 31280-31285                    | 31276-31281      |
| se   | 31288-31293                    | 31282-31287      |
| s    | 31296-31301                    | 31288-31293      |
| sw   | 31304-31309                    | 31294-31299      |
| w    | 31312-31317                    | 31300-31305      |
| nw   | 31320-31325                    | 31306-31311      |

### 7.3 PNG 存在性检查（31264–31325，逐文件 Test-Path）

缺失共 14 个：`31270, 31271, 31278, 31279, 31286, 31287, 31294, 31295, 31302, 31303, 31310, 31311, 31318, 31319`

- **候选 A：48/48 全部存在。** 缺失的 14 个恰好是每方向槽位内的填充索引（与 idle 区 31200–31263 的布局规律一致）。
- **候选 B：缺 14 帧**，ne/e/se/sw/w/nw 六个方向全部断裂。

结论倾向：**Walk 真实布局为候选 A（8 索引槽位）**，与 idle 区布局同构。待实机 F7/F8 确认。

### 7.4 帧同步规则（本次修复的核心）

- 旧实现用独立 5fps Timer 推进武器帧，与身体 Godot 帧会漂移；且曾误用 `31200 + body_local_index` 计算编号。
- 新实现：**每物理帧读取人物当前动画名与 godot_frame N，直接取该方向候选数组第 N 帧**（body idle 4 帧 / walk 6 帧与武器数组长度一致，恒等映射）。
- 不再使用任何 `31200 + local` 或独立计时器。

### 7.5 W-idle 原始 Placement（res://Weapon/Placements/%05d.txt）

| 索引 | X | Y |
|------|-----|-----|
| 31248 | -28 | -27 |
| 31249 | -31 | -27 |
| 31250 | -32 | -27 |
| 31251 | -32 | -27 |

节点结构已按代码与 tscn 双重确认：WeaponAnchor 的父节点是 Player（CharacterBody2D 根，即角色逻辑原点），与 SpriteAnchor 同级；Placement 只应用到 WeaponAnchor.position 一次；WeaponSprite position/offset=ZERO、centered=false。若实机仍有固定像素误差，则属于素材数据本身的问题，用第 7.6 节微调记录数值。

### 7.6 walk_e 诊断输出与实验性微调

- 播放 `walk_e` 时，每帧在 Godot Output 打印一行（每个身体帧号一次）：
  body_frame / body_abs_idx / body_placement(SpriteAnchor.position) / weapon_idx / weapon_placement / WeaponAnchor.position / WeaponAnchor.global_position / WeaponSprite.global_position。
- 实验性微调（仅本场景、默认 ZERO、不写入人物与 TXT）：
  - 方向键 ←/→/↑/↓ = weapon_test_adjustment X/Y ±1px；`0` = 归零。
  - HUD 每帧显示：Raw Weapon Placement / Test Adjustment / Final Weapon Position（= Raw + Adjustment）。
  - **注意**：project.godot 中方向键已映射为角色移动，按微调键时角色会同时朝该方向走一小段，建议短按；也可用 WASD 移动、方向键微调。
- 非 idle/walk 动作：`run` 使用第 9 节已确认的映射；pose/attack/death 等继续显示当前方向的武器 idle 帧。

### 7.7 按键汇总

| 键 | 功能 |
|----|------|
| F5 | 武器显示/隐藏 |
| 1 / 2 | Idle 候选 A / B |
| F7 / F8 | Walk 候选 A / B |
| ← → ↑ ↓ | weapon_test_adjustment ±1px（同时会移动角色，短按） |
| 0 | weapon_test_adjustment 归零 |

## 8. 武器前后遮挡图层规则（2026-09-07）

### 8.1 规则

| 方向 | 关系 | z_index 设置 |
|------|------|--------------|
| w / nw / sw | 身体在前，人物遮挡武器 | WeaponSprite.z_index = BodySprite.z_index - 1 |
| n / ne / e / se / s | 武器在前，武器遮挡人物 | WeaponSprite.z_index = BodySprite.z_index + 1 |

- 实现：`_update_weapon_layer(direction)`，仅在方向变化时调用一次（不在每个动画帧重复修改）。
- Idle 与 Walk 共用同一套规则。
- 未改动任何节点位置：WeaponAnchor.position、SpriteAnchor.position、全部 Placement、WeaponSprite.position/offset 均不变。
- 仍只有一个 WeaponSprite，通过 z_index 切换前后层；未添加 WeaponBackSprite / WeaponFrontSprite。

### 8.2 调试显示

HUD 新增字段：current_direction、body_z_index、weapon_z_index、weapon_layer（behind_body / in_front_of_body）。

### 8.3 验证要点

- W / NW / SW：人物遮挡武器；
- E / N / S：武器显示在人物前面。

## 9. 持武器 Run 映射（已确认，2026-09-07）

### 9.1 范围与冻结声明

- 已实机验证并冻结，本轮未改动：Weapon Idle、Weapon Walk、Weapon Placement、
  手部对齐、W/NW/SW 前后遮挡规则。
- 稳定人物（`hum_character.gd/.tscn`）、正式测试场景完全未修改；身体 Run 速度、
  动画、方向判断均不变。
- 本轮只固定持武器 Run 映射（用户实机确认 Mode A 正确），移除 F6 A/B 切换逻辑，
  不添加攻击/施法/挖掘/受击/死亡帧，不扫描 Weapon 目录，
  不猜测 31392 之后的动作，不合并到正式人物模板。

### 9.2 持武器 Run 映射表（31328–31389，已确认）

按与 idle/walk 相同的布局：每方向占一个 8 索引槽位
（N, NE, E, SE, S, SW, W, NW，起始偏移 +0/+8/+16/+24/+32/+40/+48/+56），前 6 帧有效。

| 方向 | Run 索引（每方向 6 帧） |
|------|------------------------|
| n    | 31328, 31329, 31330, 31331, 31332, 31333 |
| ne   | 31336, 31337, 31338, 31339, 31340, 31341 |
| e    | 31344, 31345, 31346, 31347, 31348, 31349 |
| se   | 31352, 31353, 31354, 31355, 31356, 31357 |
| s    | 31360, 31361, 31362, 31363, 31364, 31365 |
| sw   | 31368, 31369, 31370, 31371, 31372, 31373 |
| w    | 31376, 31377, 31378, 31379, 31380, 31381 |
| nw   | 31384, 31385, 31386, 31387, 31388, 31389 |

用户实机确认（2026-09-07）：Mode A 正确，31328 是 N 方向持武器 Run 的第一帧。
上表为最终映射，不再存在模式切换。

### 9.3 帧同步规则

- 身体 run：每方向 6 帧 @ 10fps，循环（hum_frames.gd / HUM_FRAME_RULES.md）。
- 人物播放 `run_<dir>` 时，武器层播放上表对应方向的帧；
  同索引同步：身体 Run 帧 N → 武器 Run 帧 N（N = 0..5），与 idle/walk 一致。
- 不修改身体 Run 速度、Run 动画或方向判断。

### 9.4 Placement 与图层

- 每张武器 PNG 使用同编号 Placement：`res://Weapon/Placements/%05d.txt`（31328–31389）。
- Weapon Placement 仍然只应用一次：`WeaponAnchor.position = weapon_placement`；
  `WeaponSprite.centered=false`、position/offset=ZERO、flip_h=false；未添加任何新补偿。
- 图层完全复用第 8 节方向规则（w/nw/sw 武器在后，其余在前），未修改 `_update_weapon_layer()`。

### 9.5 HUD 显示

- F6 A/B 切换已移除：Run 映射恒用 9.2 已确认表，无需按键。
- HUD 字段：`body_run_frame`（当前身体 Run 帧号）、
  `weapon_run_frame`（当前武器 Run 帧索引）、`weapon_abs_idx`（当前武器绝对索引）；
  原有方向、Placement、PNG 存在性字段继续有效。

### 9.6 验证状态

- Godot headless 检查：通过（场景加载、脚本解析无错误）。
- **用户实机确认（2026-09-07）：31328–31389 为持武器 Run 映射，Mode A 正确。** 本节规则已冻结。

## 10. Pose 与单手攻击（2026-09-07）

### 10.1 Pose 映射（31392–31399，用户实机确认正确）

每方向 1 帧连续排列：N=31392, NE=31393, E=31394, SE=31395, S=31396, SW=31397, W=31398, NW=31399。
按 P 时武器帧与人物 Pose 完全对应（用户实机确认）。本节已冻结。

### 10.2 单手攻击候选（31400–31461）PNG/Placement 存在性检查

只检查指定索引，未扫描整个 Weapon 目录：

| 方向 | 有效帧索引 | PNG 存在 | Placement 存在 |
|------|-----------|----------|----------------|
| n    | 31400-31405 | 6/6 | 6/6 |
| ne   | 31408-31413 | 6/6 | 6/6 |
| e    | 31416-31421 | 6/6 | 6/6 |
| se   | 31424-31429 | 6/6 | 6/6 |
| s    | 31432-31437 | 6/6 | 6/6 |
| sw   | 31440-31445 | 6/6 | 6/6 |
| w    | 31448-31453 | 6/6 | 6/6 |
| nw   | 31456-31461 | 6/6 | 6/6 |

**结论：48/48 PNG 全部存在，48/48 Placement 全部存在。候选缺失不是武器消失的原因。**
布局与 idle/walk/run 同构（8 索引槽位，每方向前 6 帧有效）。

### 10.3 J 键武器消失的准确原因（已定位并修复）

- 身体动画名由 `hum_character.gd` 构造为 `"%s_%s" % [action, direction]`，
  即 J 时播放 `attack_onehand_<dir>`（8 个方向名均已确认）。
- **Bug**：旧解析用 `anim.get_slice("_", 0)` / `get_slice("_", 1)`。
  对 `"attack_onehand_s"`：`get_slice("_", 0)` = `"attack"`（不是 `attack_onehand`），
  `get_slice("_", 1)` = `"onehand"`（不是方向）。
- 后果链：parsed_action=`"attack"` → match 无匹配 → 落入默认分支；
  dir=`"onehand"` → `_idle_candidate().get("onehand")` = 空数组 →
  `_apply_frame()` 判定无帧 → `texture=null, visible=false` → **武器立即消失**。
- **修复**：方向取最后一个下划线段（`rfind("_")`），action 取其前全部字符。
  对 idle/walk/run/pose（名称只含一个下划线）解析结果与旧逻辑完全相同，
  已冻结功能不受影响；仅多下划线的 `attack_onehand_*` 被正确识别。

### 10.4 缺图处理核查（未修改）

- `_apply_frame()`：当前帧 PNG 不存在 → `texture=null, visible=false`；
  下一帧 PNG 存在 → 恢复对应纹理且 `visible = weapon_enabled`。
- 不存在"一帧缺图永久关闭武器图层"的路径；`weapon_enabled` 只由 F5 切换。

### 10.5 J-diag 诊断显示（只读）

- HUD 在 weapon_action == "attack_onehand" 时持续追加一行：
  `body_animation / parsed_action / parsed_direction / body_frame / weapon_action /
  weapon_frame / weapon_absolute_index / weapon_png_path / weapon_png_exists /
  weapon_visible / weapon_layer_enabled`。
- 武器动作切换时在 Godot Output 打印一次 `[weapon] action ... -> ... dir=... body_frame=...`。

### 10.6 验证状态

- Godot headless 检查：通过（场景加载、脚本解析无错误）。
- **用户实机确认（2026-09-07）：Pose 与单手攻击映射正确，已保存到 Git。本节规则冻结。**

## 11. 双手攻击（2026-09-07）

### 11.1 候选帧 PNG/Placement 存在性检查（31464–31525）

只检查指定索引，未扫描整个 Weapon 目录：

| 方向 | 有效帧索引 | PNG 存在 | Placement 存在 |
|------|-----------|----------|----------------|
| n    | 31464-31469 | 6/6 | 6/6 |
| ne   | 31472-31477 | 6/6 | 6/6 |
| e    | 31480-31485 | 6/6 | 6/6 |
| se   | 31488-31493 | 6/6 | 6/6 |
| s    | 31496-31501 | 6/6 | 6/6 |
| sw   | 31504-31509 | 6/6 | 6/6 |
| w    | 31512-31517 | 6/6 | 6/6 |
| nw   | 31520-31525 | 6/6 | 6/6 |

**结论：48/48 PNG 全部存在，48/48 Placement 全部存在。**
布局与 idle/walk/run/onehand 同构（8 索引槽位，每方向前 6 帧有效；
空槽 31470-31471、31478-31479、31486-31487、31494-31495、31502-31503、
31510-31511、31518-31519、31526-31527 不属于动画，永不加载）。

### 11.2 实现（scripts/experiments/weapon_idle_test.gd）

- 新增常量 `ATTACK_TWOHAND_FRAMES`（上表索引），加入预加载列表。
- `_process()` match 新增 `"attack_twohand"` 分支：身体播放
  `attack_twohand_<dir>` 时，武器按身体当前帧 N → 武器方向帧 N 同步显示
  （与 onehand 相同的同序号同步规则）。
- 复用已验证机制，未改动：WeaponAnchor Offset（Placement + 实验微调）、
  w/nw/sw 身体在前 / 其余方向武器在前的遮挡规则、缺图清帧不保留上一帧。
- HUD 追加 K-diag 行（与 J-diag 同字段），动作切换时控制台打印一次。

### 11.3 验证状态

- Godot headless：`--check-only --script` 通过；测试场景加载运行 10 帧无错误，
  初始 `[weapon] action -> idle dir=s` 正常输出。
- **待用户实机确认（按 K）：** 武器是否显示 31464–31525 对应方向帧，
  以及帧序是否与身体双手攻击动作对齐。
- 未修改：Weapon Idle/Walk/Run/Pose/单手攻击、Placement、前后图层规则、Hum 人物。
- 未修改：Weapon Idle/Walk/Run/Pose、Placement、前后图层规则、Hum 人物、PNG/TXT。

## 12. Cast 施法（U 键，2026-09-07）

### 12.1 范围与冻结声明

- 已冻结且本轮未改动：Weapon Idle、Walk、Run、Pose、J 单手攻击、K 双手攻击、
  L 强力攻击、Weapon Placement、w/nw/sw 前后遮挡规则。
- 只新增 U 键 cast 武器帧映射；不添加 dig/hit/death 帧；不扫描 Weapon 目录；
  不修改 Hum 人物与正式测试场景。

### 12.2 Cast 映射表（31592–31653）

按与 idle/walk/run/onehand/twohand 相同的布局：每方向占一个 8 索引槽位
（N, NE, E, SE, S, SW, W, NW，起始偏移 +0/+8/+16/+24/+32/+40/+48/+56），前 6 帧有效。

| 方向 | Cast 索引（每方向 6 帧） |
|------|------------------------|
| n    | 31592, 31593, 31594, 31595, 31596, 31597 |
| ne   | 31600, 31601, 31602, 31603, 31604, 31605 |
| e    | 31608, 31609, 31610, 31611, 31612, 31613 |
| se   | 31616, 31617, 31618, 31619, 31620, 31621 |
| s    | 31624, 31625, 31626, 31627, 31628, 31629 |
| sw   | 31632, 31633, 31634, 31635, 31636, 31637 |
| w    | 31640, 31641, 31642, 31643, 31644, 31645 |
| nw   | 31648, 31649, 31650, 31651, 31652, 31653 |

空槽（无 PNG，不属于动画，永不加载）：31598-31599、31606-31607、31614-31615、
31622-31623、31630-31631、31638-31639、31646-31647、31654-31655。

### 12.3 PNG/Placement 存在性检查（只检查指定索引，未扫描整个 Weapon 目录）

| 方向 | 有效帧索引 | PNG 存在 | Placement 存在 |
|------|-----------|----------|----------------|
| n    | 31592-31597 | 6/6 | 6/6 |
| ne   | 31600-31605 | 6/6 | 6/6 |
| e    | 31608-31613 | 6/6 | 6/6 |
| se   | 31616-31621 | 6/6 | 6/6 |
| s    | 31624-31629 | 6/6 | 6/6 |
| sw   | 31632-31637 | 6/6 | 6/6 |
| w    | 31640-31645 | 6/6 | 6/6 |
| nw   | 31648-31653 | 6/6 | 6/6 |

**结论：48/48 PNG 全部存在，48/48 Placement 全部存在。**

### 12.4 实现（scripts/experiments/weapon_idle_test.gd）

- 新增常量 `CAST_FRAMES`（上表索引），加入预加载列表；
  每张武器 PNG 读取同编号 Placement TXT：`res://Weapon/Placements/%05d.txt`。
- `_process()` match 新增 `"cast"` 分支：身体播放 `cast_<dir>` 时，
  武器按上表对应方向显示帧。
- 帧同步：身体 cast 每方向 6 帧，同序号同步——身体帧 N → 武器帧 N（N = 0..5），
  与 idle/walk/run/攻击一致；不使用独立计时器、不做 `31200 + local` 类计算。
- 复用已验证机制，未改动：WeaponAnchor.position = weapon_placement（+实验微调）、
  w/nw/sw 身体在前 / 其余方向武器在前的遮挡规则、缺图清帧不保留上一帧。
- HUD 追加 U-diag 行（与 J/K/L-diag 同字段）：cast 时显示 `weapon_action=cast`
  与当前 `weapon_absolute_index`；动作切换时在 Godot Output 打印一次。

### 12.5 验证状态

- Godot 语法检查：通过（`--check-only --script`）。
- **待用户实机确认（按 U）：** 身体播放 cast_<dir>，武器显示 31592–31653 对应方向帧，
  HUD 显示 weapon_action=cast 与当前 weapon_absolute_index。
- 未修改：Weapon Idle/Walk/Run/Pose/J/K/L、Placement、前后图层规则、Hum 人物、PNG/TXT。

## 13. Dig 挖掘武器帧研究（I 键，2026-09-07）

### 13.1 范围

- 只新增 I 键 dig 武器帧映射；不添加 hit/death 帧；不扫描 Weapon 目录；
  不修改 `hum_character.gd`、`hum_frames.gd`、任何 Placement TXT。
- 身体侧规格来自 `hum_frames.gd` / HUM_FRAME_RULES.md：dig 本地索引 456–471，
  每方向 2 帧，8 fps，非循环；按键 I（`hum_character.gd` KEY_I → `_start_action("dig")`）。

### 13.2 Weapon dig 映射（用户提供，候选）

与 idle/walk/run/onehand/twohand/cast 相同的 8 索引槽位布局：每方向占一个 8 索引槽
（起始偏移 +0/+8/+16/+24/+32/+40/+48/+56），每槽只有前 2 帧有效，后 6 个索引为填充。

| 方向 | Weapon 绝对索引（帧0, 帧1） | 空白槽（不加载、不显示） |
|------|----------------------------|--------------------------|
| n    | 31656, 31657               | 31658–31663              |
| ne   | 31664, 31665               | 31666–31671              |
| e    | 31672, 31673               | 31674–31679              |
| se   | 31680, 31681               | 31682–31687              |
| s    | 31688, 31689               | 31690–31695              |
| sw   | 31696, 31697               | 31698–31703              |
| w    | 31704, 31705               | 31706–31711              |
| nw   | 31712, 31713               | 31714–31719              |

### 13.3 PNG/Placement 存在性检查（只检查指定索引，未扫描整个 Weapon 目录）

- 16/16 PNG 全部存在：`res://Weapon/%05d.png`
- 16/16 Placement 全部存在：`res://Weapon/Placements/%05d.txt`
- 空白槽不进入任何数组，永不加载、永不显示。

### 13.4 实现（scripts/experiments/weapon_idle_test.gd）

- 新增常量 `DIG_FRAMES`（上表映射）。
- `_process()` match 新增 `"dig"` 分支：身体动画名 `dig_<dir>` → 武器使用 `DIG_FRAMES[dir]`。
- 帧同步规则与其他动作完全一致：**身体 dig 第 N 帧 -> 武器 dig 第 N 帧**（N = 0..1，同索引同步）。
- `_preload_weapon_data()` 预加载列表加入 DIG_FRAMES；只检查/加载指定 16 个索引。
- HUD 新增 Dig 映射说明行与 `I-diag` 诊断行（当前动作 / 方向 / 帧号 / 绝对索引 / PNG 路径 / 是否存在）。

### 13.5 验证状态

- Godot headless：`--check-only --script` 通过；测试场景加载运行 10 帧无错误。
- **待用户实机确认（按 I）：** 身体播放 dig_<dir>，武器显示上表对应方向帧，
  HUD 显示 weapon_action=dig 与当前 weapon_absolute_index。
- 未修改：Weapon Idle/Walk/Run/Pose/J/K/L/U、Placement、前后图层规则、Hum 人物、PNG/TXT。
