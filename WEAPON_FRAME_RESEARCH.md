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
