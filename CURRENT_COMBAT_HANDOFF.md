# MirRPG 当前战斗任务交接文档（CURRENT_COMBAT_HANDOFF）

- 生成日期：2026-10-04
- 环境：Windows (win32)，PowerShell 5.1，工作目录 `Z:\MirRPG`（即 Godot 项目根目录，`res://` = `Z:\MirRPG\`）
- Git 仓库：是。当前分支 HEAD = `3289a4e`，**有 5 个已暂存（staged）未提交的变更**（见第 6 节）。
- Godot 引擎二进制：`Z:\MirRPG\Godot_v4.7.2-stable_win64_console.exe`（已确认存在；PROJECT_STATUS.md 记载为 4.7.2-stable win64 console）

---

## 0. 本交接红线（新 Session 必须遵守，违反即回滚）

1. **第一步只能测量坐标，不能直接改偏移。** 在拿到第 3 节规定的完整测量数据之前，禁止修改任何 position/offset 数值。
2. **不允许使用 `+=` / `-=` 迭代试错**，不允许继续盲目加减 25 或 50（半宽）来"凑"对齐。必须按第 3.3 节公式算出精确目标值后一次性赋值。
3. **血条不能每帧跟随不同纹理宽度调整 X。** 每帧图片宽度不同，若逐帧重算居中会导致血条左右抖动；血条 X 必须是固定值（挂载时设置一次），只允许 Foreground 的 `size.x` 随 hp 变化。
4. **测量与验证必须使用 idle_s 第 0 帧作为固定参考帧**（方向 S、idle 动作、frame index 0），保证每次测量可复现。
5. **森林怪人已经稳定，不得重新实现或重复验证。** `scripts/mon1_frames.gd`、`scripts/forest_stranger.gd`、`scenes/ForestStranger.tscn`、`MON1_FRAME_RULES.md` 及其测试场景均为冻结状态；本任务只允许在战斗场（combat_field_test）层面操作。
6. **不修改任何代码、场景或 Git 暂存状态**，除非测量结果证明需要修正且已按第 3 节流程执行。
7. `tools/mon1_importer.gd` **必须单独提交**，不能与血条相关提交混在一起（见第 6.4 节）。
8. 未跟踪杂散文件 `"ter health bars?"` 记录为**待检查/删除**，任何情况下不得提交。

---

## 1. TL;DR

- 项目是 MirRPG（传奇类）的 Godot 4.7 复刻：人物（Hum，0–599 × 24 套外观）已完成并冻结为 v1.0-stable 基线；怪物（Mon1）第一个怪「森林怪人」（原始索引 00280–00547）的导入、mapping、播放与测试**已完成且稳定**。
- **PHASE 4（AI 移动 + 攻击动画）已完成并 headless 验证**：怪物追击玩家、进入范围后面向玩家持续播放 attack；上方侧经碰撞形状禁用滑入小腿/膝盖位置（详见第 9 节）。
- **PHASE 4b（伤害结算）已完成并 headless 验证**：其他侧停止距离改为 **48px**（≈玩家半个身位+冗余，原 64）；怪物每次攻击周期对玩家结算一次随机 **2–5** 伤害；玩家防御目前 **0–1**（护甲后期加入），公式 `max(1, 原始 - defense)`。
- **PHASE 4c（玩家受击硬直）已完成并 headless 验证**：怪物 roll 出最大值（== attack_max，即打出 5）视为暴击 → 玩家播放 hum `hit` 动作 0.3s（3帧@10fps），期间不能移动/攻击、动画播完才能动；硬直结束后另有 **~1.5s 免疫窗口**（伤害照常结算、不再重复硬直，防连续硬直致死）。详见第 9.7 节。
- **待办任务：PHASE 3 血条中心对齐实机验证。** 血条组件已实现（宽 50 × 高 6），玩家 Y=-54、怪物 Y=-70，但**尚未在实机确认血条是否对准 Body 可见主体中心**。下一步是纯测量任务：分别对玩家和第一只怪物采集第 3.2 节列出的全部坐标量，按公式计算 `center_error`，再决定是否需要一次性修正。
- 帧结构唯一事实来源：人物 = `HUM_FRAME_RULES.md` + `scripts/hum_frames.gd`；怪物 = `MON1_FRAME_RULES.md` + `scripts/mon1_frames.gd`（Autoload `Mon1Frames`）。
- 播放控制器统一模式：`AnimatedSprite2D(centered=false)` + `SpriteAnchor`，placement 在 `_ready()` 一次性预加载缓存（按绝对索引为键），逐帧只改 `SpriteAnchor.position`，禁止每帧读盘。

---

## 2. 血条组件当前状态（目标规格）

### 2.1 尺寸与内部结构（已实现，作为对齐基准）

| 项 | 值 |
| --- | --- |
| bar_width（宽） | **50** |
| bar_height（高） | **6** |
| Background.position | **(-25, 0)** |
| Foreground.position | **(-25, 0)** |
| 满血时 size | **(50, 6)** |

- 组件结构：Node2D 根 + Background/Foreground 两个 ColorRect（刻意不用 ProgressBar，避免主题样式干扰像素风）。
- 几何约定：条以 HealthBar 根节点原点为中心水平居中 `x∈[-width/2, +width/2]`；挂载方只需一次性设 `HealthBar.position = Vector2(0, y)`，组件内无第二处 X 偏移。
- API：`set_hp(current, max)`（只改 Foreground `size.x` 与颜色红→绿插值）、`set_bar_size(w, h)`。
- `mouse_filter=IGNORE`，不拦截输入。

### 2.2 挂载位置（已实现）

| 对象 | HealthBar.position.y | 依据 |
| --- | --- | --- |
| 玩家 | **-54** | 玩家头顶最高 y≈-48，留 6px |
| 怪物（森林怪人） | **-70** | 各动作头顶范围 y≈-51..-63，留 7px |

- 血条挂到物理根节点下自动跟随移动；z_index：玩家血条=4（高于玩家内部最高图层 Hair=3），怪物血条 z = 动画层 +1。
- **X 方向当前假设为 0（即与物理根节点同 X）。本任务要验证的就是这个假设是否等于 Body 可见主体中心。**

### 2.3 待确认问题（本任务核心）

> 当前血条仍需实机确认是否对准 Body 可见主体中心。
> 物理碰撞体中心 ≠ 纹理视觉中心：`AnimatedSprite2D(centered=false)` + placement offset 使纹理相对根节点有 X 偏移，且不同帧宽度不同。若直接用根节点 X 挂血条，血条可能整体偏左或偏右。

---

## 3. 测量协议（新 Session 第一步：只测不改）

### 3.1 前置条件

- 运行战斗场测试场景 `scenes/experiments/combat_field_test.tscn`（右键移动；F7 重生怪物）。
- 将玩家与第一只怪物都置于**静止状态**，动作 = **idle**、方向 = **S**、帧 = **第 0 帧**（固定参考帧，保证可复现）。
- 相机保持默认，不做任何缩放/旋转。

### 3.2 必须分别对「玩家」和「第一只怪物」各测一组，每组包含：

| # | 量 | 说明 |
| --- | --- | --- |
| 1 | 物理根节点 `global_position` | CharacterBody2D（Player / Monster） |
| 2 | SpriteAnchor `global_position` | placement offset 载体 |
| 3 | BodySprite `global_position` | AnimatedSprite2D（centered=false），即纹理左上角的世界坐标 |
| 4 | texture 宽度 | `texture.get_width()`（idle_s 第 0 帧） |
| 5 | body_visual_center_x | 按 3.3 公式计算 |
| 6 | HealthBar `global_position` | 血条根节点 |
| 7 | Background `global_position` 和 `size` | ColorRect |
| 8 | bar_center_x | 按 3.3 公式计算 |
| 9 | center_error | 按 3.3 公式计算 |

### 3.3 计算公式（唯一允许的对齐判据）

```text
body_visual_center_x = BodySprite.global_position.x + BodySprite.texture.get_width() * 0.5

bar_center_x         = Background.global_position.x + Background.size.x * 0.5

center_error         = bar_center_x - body_visual_center_x
```

- `center_error == 0`（像素级）→ 对齐正确，无需改动。
- `center_error != 0` → 需要修正时，**一次性**把 HealthBar 的 X 设为 `-center_error`（相对物理根节点），禁止用 `+=` 迭代逼近，禁止盲目加减 25/50。

### 3.4 测量输出要求

- 将两组完整数据（玩家 / 第一只怪物）连同计算过程打印到控制台并记录在案。
- 若任一方向数量、坐标或公式结果异常，停止修改，报告冲突，不得猜测。

---

## 4. 项目结构（主要文件与职责）

### 规则文档（唯一事实来源，勿改）
| 文件 | 职责 |
| --- | --- |
| `HUM_FRAME_RULES.md` | Hum 人物套内 0–599 帧结构：11 动作 × 8 方向精确索引数组；24 套外观 = appearance_id × 600 基址（绝对索引 0–14399） |
| `MON1_FRAME_RULES.md` | Mon1 怪物帧规则：森林怪人 00280–00547 的槽位表 + 五动作精确数组；守卫 00000–00189 标记为 TODO（缺 death） |
| `PROJECT_STATUS.md` | v1.0-stable 基线说明：冻结模块清单、模板接口、运行命令（只覆盖 Hum，未含 Mon1 新工作） |
| `CHARACTER_TEMPLATE.md` / `MOVEMENT_OFFSET_BASELINE.md` | 人物模板派生规则 / 移动与 Offset 冻结参照 |

### Autoload（mapping 数据层，纯数据 + 路径助手）
| 文件 | 职责 |
| --- | --- |
| `scripts/hum_frames.gd` → `HumFrames` | Hum 帧数组、`set_appearance()`、`abs_index()`、`png_path()/placement_path()`、`local_frames(action, dir)` |
| `scripts/mon1_frames.gd` → `Mon1Frames` | Mon1 怪物注册表 `MONSTERS`（含 `death_behavior: "stay_last_frame" \| "disappear"`）、森林怪人五动作精确数组、方向常量 `DIRECTIONS = [n, ne, e, se, s, sw, w, nw]`、路径助手 |

### 播放控制器（数据与播放分离）
| 文件 | 职责 |
| --- | --- |
| `scripts/hum_character.gd` | 人物模板：CharacterBody2D + SpriteAnchor + AnimatedSprite2D(centered=false) + WeaponLayer；WASD/方向键移动、Shift=Run、11 动作状态机、placement 预加载缓存 |
| `scripts/forest_stranger.gd` | 森林怪人播放控制器（Node2D → SpriteAnchor → AnimatedSprite2D）：`play_idle/walk/attack/struck/death()`、`set_direction()/cycle_direction()`、`recover()`、`get_frame_info()`、载入报告 + 诊断文件写出；支持 `death_behavior="disappear"` |

### 场景
| 文件 | 职责 |
| --- | --- |
| `scenes/test_scene.tscn` | 项目主场景（project.godot main scene），人物测试 |
| `scenes/appearance_gallery.tscn` | 24 套外观画廊 |
| `scenes/ForestStranger.tscn` | 森林怪人怪物场景（显示名「森林怪人」）——**已稳定，勿动** |
| `scenes/experiments/forest_stranger_test.tscn` + `scripts/experiments/forest_stranger_test.gd` | 森林怪人交互测试：8 方向按钮 + idle/walk/attack/struck/death/RECOVER 按钮，HUD 实时显示 action/dir/frame/source_index/offset/dead |
| `scenes/experiments/forest_stranger_smoke.tscn` + `scripts/experiments/forest_stranger_smoke.gd` | 冒烟测试（headless 可跑） |
| `scenes/experiments/mon1_diagnostic.tscn/.gd` | Mon1 索引诊断 / contact sheet 生成 |
| `scenes/experiments/combat_field_test.tscn` + `scripts/experiments/combat_field_test.gd` | **当前任务主场景**：战斗场测试（PHASE 3：最小地图 + 右键移动 + Hair/Weapon 图层 + 怪物生成 + 血条 + 测试伤害） |
| `scenes/experiments/monster_collision.gd` | 怪物碰撞体（CharacterBody2D，layer=4 mask=1\|4），PHASE 3 起带 HP 接口 |
| `scenes/health_bar.tscn` + `scripts/health_bar.gd` | **新增**：通用像素风血条组件（见第 2 节） |

### 工具与资产
| 文件 / 目录 | 职责 |
| --- | --- |
| `tools/mon1_importer.gd` | **新增**：headless PNG 导入工具（遍历 `res://Mon1`，对每个 png 调 `ResourceLoader.import_resource()`）——**提交时必须与血条分开** |
| `Z:\MirRPG\Hum\*.png` + `Hum\Placements\%05d.txt` | Hum 素材：9984 张 PNG、14400 个 placement（完整覆盖 0–14399）。placement 格式：第一行 X、第二行 Y |
| `Z:\MirRPG\Mon1\%05d.png` + `Mon1\Placements\%05d.txt` | Mon1 素材：实测 464 张 PNG、1086 个 placement（覆盖索引 0–1085）。**原始素材目录，禁止修改/移动/重命名** |
| `forest_stranger_contact_sheet.png` | 森林怪人 contact sheet（动作分块 × 方向行 × frame 列，每格标 source_index） |

### project.godot 要点
- Godot 4.7（features "4.7"），渲染器 gl_compatibility，窗口 1280×720
- Autoload：`HumFrames = res://scripts/hum_frames.gd`、`Mon1Frames = res://scripts/mon1_frames.gd`
- Input map：move_left/right/up/down（WASD + 方向键）、run（Shift）

---

## 5. 森林怪人实现状态（已稳定，冻结）

### 5.1 Mapping（`scripts/mon1_frames.gd`，与 `MON1_FRAME_RULES.md` 一致）

范围 00280–00547（268 个槽位），实际使用 176 帧；其余为预留/空白槽。方向顺序统一 N, NE, E, SE, S, SW, W, NW。

| action | 起始索引 | 步长 | 每方向帧数 | 各方向 source index（n / ne / e / se / s / sw / w / nw） |
| --- | --- | --- | --- | --- |
| idle（循环） | 00280 | 8 | 4 | 280–283 / 288–291 / 296–299 / 304–307 / 312–315 / 320–323 / 328–331 / 336–339 |
| walk（循环） | 00344 | 8 | 6 | 344–349 / 352–357 / 360–365 / 368–373 / 376–381 / 384–389 / 392–397 / 400–405 |
| attack（单次→回 idle） | 00408 | 8 | 6 | 408–413 / 416–421 / 424–429 / 432–437 / 440–445 / 448–453 / 456–461 / 464–469 |
| struck（单次→回 idle） | 00472 | 2 | 2 | 472,473 / 474,475 / 476,477 / 478,479 / 480,481 / 482,483 / 484,485 / 486,487 |
| death（单次→停末帧） | 00488 | 8 | 4 | 488–491 / 496–499 / 504–507 / 512–515 / 520–523 / 528–531 / 536–539 / 544–547（正好到范围末端 00547） |

### 5.2 播放规则（`scripts/forest_stranger.gd`）
- 初始：idle + 方向 S。
- idle/walk 循环；attack、struck 单次，`animation_finished` 后回同方向 idle；death 单次，播完停在同方向最后一帧（`stay_last_frame`）。
- death 状态锁定：不能再触发 idle/walk/attack/struck（测试用 `recover()` 解锁）。
- 切换动作保持当前方向；切方向时切换到对应方向的当前动作。
- placement：`_ready()` 一次性预加载全部帧的 `Mon1\Placements\%05d.txt` 并按绝对索引缓存；`frame_changed` 信号只把 offset 赋给 `SpriteAnchor.position`（AnimatedSprite2D `centered=false`，不用 flip_h）。
- 载入校验：逐 action/direction 打印期望 vs 实际帧数与 source index；不一致时 `push_error` 并写诊断文件到 `res://data/diagnostics/forest_stranger_load_report.txt`。
- `death_behavior="disappear"`（未来守卫用）已在注册表与控制器中实现：死亡事件直接 `queue_free()`，不生成假死亡帧。

> **本节内容已验证通过并冻结。新 Session 不得重新实现、不得重复跑森林怪人验证流程；仅在战斗场场景中作为被测对象使用。**

---

## 6. Git 状态与提交纪律

### 6.1 `git status --short`（当前）
```text
A  scenes/health_bar.tscn
MM scripts/experiments/combat_field_test.gd     # staged=PHASE3；unstaged=PHASE4 AI + PHASE4b 伤害
MM scripts/experiments/monster_collision.gd     # staged=PHASE3；unstaged=PHASE4 AI + PHASE4b 伤害
A  scripts/health_bar.gd
A  tools/mon1_importer.gd
?? CURRENT_COMBAT_HANDOFF.md                     # 本交接文档（untracked）
?? "ter health bars?"        # 未跟踪杂散文件：待检查/删除，禁止提交
```

> **MM 说明**：暂存区里是 PHASE 3（血条 + HP 接口）；工作区在其之上还有 PHASE 4（追击 AI / 攻击动画 / 上方滑入）与 PHASE 4b（停止距离 48、攻击力 2–5、玩家防御），这两部分**尚未 `git add`**。

### 6.2 `git log --oneline -10`
```text
3289a4e (HEAD) Add combat field test with monster spawning and collision
2c86d3b Add forest stranger animation, mapping rules, and test scenes
6f6176b Freeze Hum character baseline v1.0-stable
8187355 Initial MirRPG Godot project scaffold
```

### 6.3 查看改动的命令
- **暂存区 vs HEAD**（PHASE 3 内容，即上面 5 个 staged 文件）：`git diff --cached --stat` / `git diff --cached -- <file>`
```text
 scenes/health_bar.tscn                   |  18 +++++
 scripts/experiments/combat_field_test.gd | 122 +++++++++++++++++++++++++++++--
 scripts/experiments/monster_collision.gd |  22 ++++++
 scripts/health_bar.gd                    |  51 ++++++++++++++++
 tools/mon1_importer.gd                   |  63 ++++++++++++++++++++
 5 files changed, 268 insertions(+), 8 deletions(-)
```
- **工作区 vs 暂存区**（PHASE 4 AI + PHASE 4b 伤害，未 staged）：`git diff --stat` / `git diff -- <file>`
```text
 scripts/experiments/combat_field_test.gd |  61 ++++++--------
 scripts/experiments/monster_collision.gd | 131 +++++++++++++++++++++++++++++--
 2 files changed, 152 insertions(+), 40 deletions(-)
```
- **工作区 vs HEAD**（全部改动）：`git diff HEAD --stat`

### 6.4 staged 的 5 个文件与提交拆分要求

| # | 状态 | 文件 | 主题 |
| --- | --- | --- | --- |
| 1 | A | `scenes/health_bar.tscn` | 血条组件场景（宽 50 × 高 6） |
| 2 | A | `scripts/health_bar.gd` | 血条组件脚本 |
| 3 | M | `scripts/experiments/combat_field_test.gd` | 战斗场 PHASE 3：HP 接口、血条挂载（玩家 Y=-54 / 怪物 Y=-70）、F8/F9/F10 测试按键 |
| 4 | M | `scripts/experiments/monster_collision.gd` | 怪物碰撞体 HP 接口（max_hp=100/hp/take_damage/heal/reset_health/is_dead） |
| 5 | A | `tools/mon1_importer.gd` | Mon1 PNG headless 导入工具 —— **必须单独提交** |

**提交纪律：**
- 文件 1–4（血条 + 战斗场 HP）属于同一主题，可合并为一个「PHASE 3 血条」提交。
- **PHASE 4 AI + PHASE 4b 伤害**（工作区未 staged 部分，仅涉及 combat_field_test.gd / monster_collision.gd）：必须与 PHASE 3 内容**分开提交**。顺序：先 `git commit` 已暂存的 PHASE 3 → 再 `git add` 这两个文件 → 单独提交「PHASE 4/4b」。
- 文件 5 `tools/mon1_importer.gd` **必须拆成独立提交**，不得与血条提交混在一起。
- `"ter health bars?"`（未跟踪杂散文件）：**待检查/删除，任何情况下不得提交**。
- 本交接文档 `CURRENT_COMBAT_HANDOFF.md`：新增后保持 untracked 或按项目惯例处理，不与上述代码提交捆绑。

### 6.5 staged 变更内容摘要

**1) `scripts/health_bar.gd`（新增，51 行）** —— 通用像素风血条组件
- Node2D 根 + Background/Foreground 两个 ColorRect；`set_hp()` 只改 Foreground `size.x` 与颜色（红→绿插值）；几何约定见第 2.1 节。

**2) `scenes/health_bar.tscn`（新增，18 行）** —— bar_width=50、bar_height=6；Background 深色底 (0.13,0.13,0.15)，Foreground 初始满血绿。

**3) `scripts/experiments/combat_field_test.gd`（+122/−8）** —— PHASE 3
- 头顶固定偏移常量：`PLAYER_BAR_Y = -54`、`MONSTER_BAR_Y = -70`（挂载时一次性设置，不逐帧移动）。
- 玩家侧 HP 接口定义在本脚本（**hum_character.gd 不修改**）：`take_damage/heal/reset_health/is_dead` + `max_hp=100`。
- `_build_player_bar()`：血条挂到 Player 物理根节点下，z_index=4。
- `_update_health_bars()`：每帧同步 hp → 只改前景宽度与颜色，不移动条。
- 测试按键：**F8**=玩家受击 10、**F9**=全体存活怪物各 -10、**F10**=全部回满血；原 F9 诊断打印移至 **F12**。

**4) `scripts/experiments/monster_collision.gd`（+22）** —— 加 `max_hp=100 / hp / attack_damage(预留)` + HP API；死亡行为（disappear/stay_last_frame）为未来阶段，本轮不调用。

**5) `tools/mon1_importer.gd`（新增，63 行）** —— headless PNG 导入工具
```powershell
& "Z:\MirRPG\Godot_v4.7.2-stable_win64_console.exe" --path "Z:\MirRPG" --headless --script res://tools/mon1_importer.gd
```

---

## 7. 运行 / 验证命令

> Godot 二进制：`Z:\MirRPG\Godot_v4.7.2-stable_win64_console.exe`（在 `Z:\MirRPG` 下）

| 目的 | 命令 |
| --- | --- |
| **战斗场测试 PHASE 3（当前任务主场景；右键移动；F7 重生怪物 F8/F9/F10 血量 F12 诊断 Esc 退出）** | `& "Z:\MirRPG\Godot_v4.7.2-stable_win64_console.exe" --path "Z:\MirRPG" res://scenes/experiments/combat_field_test.tscn` |
| 森林怪人交互测试（已稳定，仅回归参考） | `& "..." --path "Z:\MirRPG" res://scenes/experiments/forest_stranger_test.tscn` |
| 森林怪人冒烟测试（headless） | `& "..." --path "Z:\MirRPG" --headless res://scenes/experiments/forest_stranger_smoke.tscn` |
| Mon1 索引诊断 / contact sheet | `& "..." --path "Z:\MirRPG" res://scenes/experiments/mon1_diagnostic.tscn`（或 headless） |
| 人物主测试场景（WASD + Shift 跑步，J/K/L/U/I/P/H/Y/R=动作） | `& "..." --path "Z:\MirRPG" res://scenes/test_scene.tscn` |
| 外观画廊（←/→ 切 24 套） | `& "..." --path "Z:\MirRPG" res://scenes/appearance_gallery.tscn` |
| Headless 编辑器校验（解析/场景/资源路径错误） | `& "..." --path "Z:\MirRPG" --headless --editor --quit` |
| Mon1 PNG headless 导入 | `& "..." --path "Z:\MirRPG" --headless --script res://tools/mon1_importer.gd` |

编辑器内操作：F6 打开对应 .tscn → 按 F5（或右上角运行）即可。

---

## 8. 已知问题与 TODO

1. **【当前任务】血条中心对齐未实机确认** —— 见第 2.3、3 节；先测量 `center_error`，再决定是否一次性修正 X。
2. **守卫（00000–00189）未实现** —— `MON1_FRAME_RULES.md` / `mon1_frames.gd` 中已留 TODO：缺 death 动画；未来实现时 idle/walk/attack 正常处理，死亡事件走 `death_behavior="disappear"`（直接隐藏/删除 Sprite），不得用森林怪人 death 顶替、不生成假帧。基础设施（注册表字段 + 控制器 disappear 分支）已就绪，只差 mapping 与场景。
3. **`tools/mon1_importer.gd` 的等待循环是空操作**：`_pending_imports()` 恒返回 0，`while ... and _pending_imports() > 0` 永不执行；实际导入靠 `import_resource()` 排队 + 编辑器 import pass 完成。另有可疑表达式 `waited += get_process_time() if false else 0.01`（恒加 0.01）。功能上可用，但逻辑是死代码，后续清理。**提交时单独成 commit**。
4. **仓库根目录杂散文件 `"ter health bars?"`**（未跟踪，127 字节）：内容只是 4 个文件路径的列表，疑似误粘贴产物，不是项目代码；**待检查/删除，禁止提交**。
5. **PHASE 4 + 4b + 4c 已完成**（见第 9 节）：AI 移动/攻击动画 + 怪物→玩家伤害结算（每次出手随机 2–5，减防御最低 1）+ 暴击硬直（roll 出最大值 → 玩家 hit 0.3s + 免疫窗口）。注意：**「暴击」目前只是 roll==attack_max 的代理判定**，真正的暴击率/暴击系统尚未实现。仍缺：玩家攻击怪物（`attack_damage=25` 预留）、护甲系统、死亡行为（`is_dead()` 时仅停止 AI、原地不动；HP 可掉到 0 但无死亡动画/重生）、怪物受击 struck 接线。
6. **PROJECT_STATUS.md 滞后**：仍只描述 Hum v1.0-stable 基线，未收录 Mon1/森林怪人/PHASE 3 血条工作；本文件（CURRENT_COMBAT_HANDOFF.md）暂代其角色，后续可合并回 PROJECT_STATUS.md。
7. **冻结纪律**（来自 PROJECT_STATUS.md §4 + 第 0 节红线）：Hum 帧规则、八方向映射、Idle/Walk/Run、动作状态机、Placement 缓存、SpriteAnchor Offset、appearance_base、Gallery、森林怪人全套 —— 不得重构，只能经模板接口调用；新增外观走「继承 hum_character.tscn → 存 preset」流程。
8. **素材纪律**：`Z:\MirRPG\Mon1`（及 `Hum`）原始目录禁止修改/移动/重命名；帧结构以两份 FRAME_RULES.md 为唯一事实来源，不得靠扫 PNG 尺寸反推动作。

---

## 9. PHASE 4 AI 实现状态（已完成 + headless 验证）

### 9.1 行为规格

- **追击**：`target != null` 时每物理帧朝玩家当前位置行走，`chase_speed=140 px/s`（慢于玩家 walk 200，玩家可拉开距离）。
- **攻击**：进入停止距离后 `velocity=ZERO` + 面向玩家持续播放 attack（attack 单次播完自动回同方向 idle，下一帧再触发 → 范围内连续攻击直到离开范围）。
- **动画驱动**：只经 ForestStranger 公开 API（`set_direction` / `play_walk` / `play_attack`）；`forest_stranger.gd`、`mon1_frames.gd`、preset .tscn 全部未动。
- **死亡**：`is_dead()` → AI 停止、原地不动（disappear/stay_last_frame 为未来阶段）。

### 9.2 停止距离（关键几何，实测推导）

脚圆在 `(0,+30)` r16（下缘到 origin+46）；玩家 box `Rect2(-24,-32,48,64)`：

| 怪物所在侧 | 物理接触中心距 | 停止距离 |
| --- | --- | --- |
| 上方（面向 s/se/sw，从 N/NE/NW 接近） | **78** = 46+32 | `attack_distance_from_above=26`（需重叠，见下） |
| 下方（s） | 18 | `attack_distance=48`（PHASE 4b：≈半个身位+冗余；原 64） |
| 左右（e/w） | 40 | 48（> 接触距离 40，不重叠、留小间隙） |
| 斜侧（se/sw） | ≈26-40 | 48 |

### 9.3 上方侧重叠滑入机制（本阶段核心难点）

- 停在接触距离 78 处怪物脚底落在人物头颈；要站到小腿/膝盖必须与玩家 box 重叠。
- **不能靠改 mask**：玩家自身 `mask=7` 已含怪物层，碰撞对仍成立 → 改为进入范围后 `set_collision_enabled(false)`（`CollisionShape2D.disabled` set_deferred），离开范围立即恢复。
- **进入阈值 `ATTACK_ENTRY_FROM_ABOVE=84` 必须 > 接触距离 78**：否则怪物先被物理顶住、永远进不了攻击分支，且会持续把玩家推出（headless 实测复现过：玩家被拖行数百 px）。
- 范围内以 `settle_speed=60 px/s` 滑入目标偏移；形状禁用期间不产生任何碰撞。

### 9.4 验证结果（headless 冒烟，逐侧隔离测试）

| 侧 | 停止距离实测 | 状态 | 玩家漂移 |
| --- | --- | --- | --- |
| N / NW（上方侧） | ≈32（滑入中，目标 26±0.5） | attack ✓ | (0,0) |
| E / S / SE | 61.7–62.3 | attack ✓ | (0,0) |

- `combat_field_test.tscn` headless 运行无 SCRIPT ERROR / Parse Error。
- 冒烟测试文件（tmp_ai_smoke.gd/.tscn）验证后已删除，未留在仓库。

### 9.5 PHASE 4b：停止距离调整 + 怪物攻击力 / 玩家防御（2026-10-04，headless 已验证）

**需求**：① 其他侧停止距离 ≈ 玩家半个身位、留一点冗余；② 怪物攻击力每次出手随机 2–5；③ 玩家防御目前 0–1，护甲后期加入。

**实现**（仅战斗场层，冻结文件未动）：
- `monster_collision.gd`：
  - `attack_distance` 默认值 **64 → 48**（≈视觉身高 ~96px/2；> 非上方侧最大接触距离 e/w=40，不重叠、留小间隙）。上方侧保持 26。
  - 新增 `@export var attack_min := 2` / `attack_max := 5`：单次出手随机整数伤害。
  - 新增 `@export var damage_target: Node`：受击对象（默认跟随 target）；combat_field_test 中 HP/defense 接口在**场景根节点**而非 $Player，故生成时设 `body.damage_target = self`。
  - 范围内分支：出手前检测「新攻击周期」（`current_action != "attack"`）→ `_deal_hit_to_target()` **每周期结算一次**；attack 动画播放期间（6 帧 @10fps ≈ 0.6s）不重复结算 → 约 0.6–0.7s 一次出手。
- `combat_field_test.gd`：新增玩家属性 `@export var defense := 0`（目前 0–1，护甲后期加入）；HUD 显示 `def=` 与各怪 `atk=2-5`；`_instantiate_monster()` 注入 `damage_target=self`。
- **伤害公式**：`final = max(1, randi_range(attack_min, attack_max) - defense)`（最低 1）。

**headless 验证结果**：
| 项 | 实测 | 期望 | 状态 |
| --- | --- | --- | --- |
| E 侧停止距离 | 46.3 | ≈48（±物理步长） | ✓ |
| def=0 单次伤害 | 全部 ∈ [2,5] 整数 | [2,5] | ✓ |
| def=1 后单次伤害 | raw-1，最低 1（如 atk=4→3、atk=3→2） | max(1, raw-1) | ✓ |
| 出手频率 | ≈0.6–0.7s/次 | attack 周期 6帧@10fps | ✓ |
| 全场景 5 怪 | HP 100→0 连续掉血，无 SCRIPT ERROR | — | ✓ |

- 冒烟文件 tmp_damage_smoke.gd/.tscn 验证后已删除；两脚本 `--check-only` 通过。

### 9.6 待实机确认 / 后续可调

1. **上方侧最终站位 26px 的视觉效果**（脚底是否正好在小腿/膝盖）——headless 只能验证数值与无顶推，视觉需实机看一眼；不满意直接调 `attack_distance_from_above`（inspector 可改）。
2. **其他侧新停止距离 48px 的视觉效果**——实机看是否「半个身位+一点冗余」合适；不满意直接调 `attack_distance`（inspector 可改）。
3. 攻击动画节奏（attack 单次时长 × 连续触发频率）是否需要间隔。
4. **未来阶段**：玩家攻击怪物（`attack_damage=25` 预留）、护甲系统（defense 目前 0–1）、真正的暴击率/暴击系统（当前「暴击」只是 roll==attack_max 的代理判定）、怪物/玩家死亡行为、怪物受击 struck 接线。

### 9.7 PHASE 4c：玩家受击硬直 stagger（2026-10-04，headless 已验证）

**需求**：怪物攻击发挥最大值时（如 0–5 打出 5）玩家被硬直；硬直期间不能移动、不能攻击，动画播完才能动；硬直后有 ~1–2s 免疫硬直的窗口，保证不会一直硬直致死。

**实现**（仅战斗场层；`hum_character.gd` / `forest_stranger.gd` 冻结未动）：
- `combat_field_test.gd`（玩家侧状态放场景根节点，与 HP/defense 一致）：
  - 新增 `apply_stun() -> bool`：拒绝条件 = 已死 / 正在硬直 / 免疫窗口内；接受 → `_player.play_directional_action("hit")`（hum 公开 API）+ `_stun_immune_until = now + HIT_STUN_DURATION(0.3) + stun_immunity_after(1.5)`。
  - **硬直结束用 `animation_finished` 信号判定**（_ready 中连接 Player/SpriteAnchor/AnimatedSprite2D）：hit 播完即清 `is_stunned`，hum_character 同时自动回 idle —— 不用固定 Timer（符合 HUM_FRAME_RULES §6）。
  - **移动封锁**：`_physics_process` 遇 `is_stunned` 提前返回（不移动、也不播放 walk/run，防止打断 hit 动画）；硬直中右键按/松只记录 held 状态，不清 action_locked、不强切 idle。
  - **攻击禁止**：硬直中 `_unhandled_key_input` 吞掉 J/K/L/U/I/H（`set_input_as_handled()`），hum_character 收不到；F 键测试与 ESC 不受影响。
  - HUD：玩家行显示 `STUNNED` / `stun-immune X.Xs`；新增 **F11 = 手动触发一次硬直**（验证动画 + 免疫窗口）。
- `monster_collision.gd`：`_deal_hit_to_target()` 中 `raw >= attack_max` 视为暴击 → 目标有 `apply_stun()` 方法则调用，是否接受由目标自判；日志区分 `CRIT -> STUN` / `crit (immune)`。

**设计说明**：
- 硬直期间 hum_character 自身 `action_locked=true`（hit 播放时自动置位）也封锁其内部移动状态机 —— 双保险。
- 免疫窗口内暴击仍正常造成伤害，只是不重复硬直 —— 符合「防连续硬直致死」而非无敌。
- 暴击判定目前 = roll 出最大值（20%/次出手）；将来做真暴击率时只需替换 `raw >= attack_max` 条件。

**headless 验证结果**：
| 项 | 实测 | 期望 | 状态 |
| --- | --- | --- | --- |
| 首次硬直接受、action=hit | ✓ | hit 播放 | ✓ |
| 硬直中再次触发被拒 | ✓ | 不重复硬直 | ✓ |
| 动画播完自动解除（信号） | ✓ | 0.3s 后清除 | ✓ |
| 免疫窗口内拒绝（t≈1.0s < 1.8s） | ✓ | 只受伤不硬直 | ✓ |
| 免疫结束后再次接受（t>1.8s） | ✓ | — | ✓ |
| 死亡玩家拒绝硬直 | ✓ | — | ✓ |
| 全场景真实 AI：atk=5 → CRIT -> STUN + -5hp | ✓ | 暴击触发硬直 | ✓ |

- 单元冒烟（tmp_stun_smoke，8/8 PASS）与集成测试（tmp_crit_integration，PASS）文件验证后已删除；两脚本 `--check-only` 通过。

### 9.8 PHASE 4d：玩家死亡（2026-10-04，headless 已验证，黑白效果待实机确认）

**需求**：玩家 hp 到 0 → 播放死亡动画；怪物停止攻击；屏幕慢慢变成黑白。

**实现**（仅战斗场层 + monster_collision AI 守卫；`hum_character.gd` / `forest_stranger.gd` 冻结未动，复用其既有 death/recover API）：
- `combat_field_test.gd`：
  - `take_damage()` 加死亡守卫：已死直接 return（不再结算伤害）；hp 归零 → `_on_player_died()`。
  - `_on_player_died()`：清硬直状态 + `_player.play_directional_action("death")`（hum death = 4帧@6fps≈0.7s，播完停在最后一帧、`dead=true`，hum_character 内部自动封锁移动/动作）+ `_fade_target=1`。
  - **屏幕黑白淡入**：`_build_death_fade_overlay()` 构建 WorldEnvironment（`adjustment_saturation` 1→0，真去饱和）+ CanvasLayer(20)/ColorRect 灰色叠加层（alpha 0→0.4，压暗氛围）；`_update_death_fade(delta)` 每帧向目标缓动，速度 = 1/`death_fade_duration`(默认3s)。
  - **复活路径**：`reset_health()` 时若 `_player.dead` → `recover()`（hum 公开 API，回 idle）+ 回满血 + fade 目标归 0；F7 = 玩家已死则先复活再重生怪物。
  - HUD：fade 进行中显示 `screen : grayscale fade XX%`；提示行更新 F7/F10 说明。
- `monster_collision.gd`：`_physics_process` 在自身 is_dead 检查后新增 —— 目标（damage_target 或 target）有 `is_dead()` 且为真 → return，停止追击/攻击、原地站定（当前动画自然播完）。

**踩坑记录（重要）**：
- **canvas_item shader 里不能用 `screen_texture`**（Godot 4.7 编译报错 `Unknown identifier`）——最初的全屏灰度 shader 方案失败，已删除；改用 WorldEnvironment saturation + 灰色叠加层。
- GDScript 方法名不能用 `assert`（保留字/内建函数），冒烟脚本里改名 `_check`。

**headless 验证结果**：
| 项 | 实测 | 期望 | 状态 |
| --- | --- | --- | --- |
| 怪物先真实攻击掉血（hp=90） | ✓ | 死亡前在战斗 | ✓ |
| 致死伤害 → hp=0、is_dead() | ✓ | — | ✓ |
| death 动画播完 → player.dead=true | ✓ | 停末帧 | ✓ |
| 3s 后无怪物处于 attack 动作 | ✓ | 停止攻击 | ✓ |
| 死亡中 take_damage 被拒（hp 恒 0） | ✓ | — | ✓ |
| fade 值到 1.0、saturation≈0 | ✓ | 黑白淡入完成 | ✓ |
| reset_health 复活：dead=false、满血、fade→0、saturation=1 | ✓ | — | ✓ |

- 冒烟文件 tmp_death_smoke.gd/.tscn（12/12 PASS）验证后已删除；两脚本 `--check-only` 通过。
- **待实机确认**：① WorldEnvironment saturation 调整是否作用于 2D 内容（Godot 4 中环境后期处理应作用于整个 viewport，但本项目首次使用，headless 无法看像素）——若实机发现屏幕只是变暗、颜色仍在，则去饱和未生效，需改用 SubViewport+shader 方案；② 黑白淡入的时长/压暗程度观感（`death_fade_duration`、`DEATH_OVERLAY_MAX_ALPHA` 可调）。
