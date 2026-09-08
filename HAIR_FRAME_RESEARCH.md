# Hair Frame Research（Hair 帧研究）— 重置版

> 本文档于 2026-09-08 依据用户实机观察结果重置。
> 身体帧结构唯一事实来源仍为 `HUM_FRAME_RULES.md`；本文档只记录 Hair 层的研究状态。

## 1. 当前状态声明（NOT IMPLEMENTED / 未实施）

**当前 Hair 实现状态：NOT IMPLEMENTED / 未实施。**

此前 Hair 覆盖实验没有显示任何 Hair，**未通过实机验证**。
此前生成的 `hair_movement_test` 实现（`scripts/experiments/hair_movement_test.gd`、
`scenes/experiments/hair_movement_test.tscn`）**不得视为有效基线**，不得在其基础上继续开发。

## 2. 撤销的结论（FAILED）

以下结论未经实机确认，现全部撤销：

- ~~HairAnchor结构已经正确~~ — 撤销
- ~~Hair Placement已经正确应用~~ — 撤销
- ~~Hair Idle已完成~~ — 撤销
- ~~Hair Walk已完成~~ — 撤销
- ~~Hair Run已完成~~ — 撤销

此前 `hair_movement_test` 的结果标记为 **FAILED**（已尝试但没有显示），不得写成完成。
旧版本文档中的帧表、Placement 实测值与节点结构记录均绑定未经验证的假设
（基址 1800 + 600 索引结构推测），不再作为有效参照，必须从最小测试重新推导。

## 3. 候选资源组（CANDIDATE，用户观察）

已由用户观察到的候选资源组：

| 中性名称 | 索引范围 | 最后有效图片（通常到） |
|---|---|---|
| Hair Group A | 1200–1799 | 1795 |
| Hair Group B | 1800–2399 | 2395 |
| Hair Group C | 3000–3599 | 3595 |

- 2400–2999 为零散资源，暂时不使用。
- 每个完整 Hair 组理论上占 **600 个索引槽**，理论有效帧数 **416 张**（依据 Hum 600 索引结构推测，CANDIDATE）。

## 4. 当前不能确定的事项（必须通过最小测试逐一解决）

目前不能确定：

- 哪个 Hair 组对应哪种身体类型
- 哪个 Hair 组对应哪种头部类别
- Hair Placement 坐标系如何与 Body 组合
- Hair 是否应作为角色子节点或实验根节点跟随
- Hair 的正确图层结构
- 1200、1800、3000 哪一个应作为第一测试基址

**禁止将“男头”“女头”写成确定事实。** 暂时只使用中性名称：

- Hair Group A = 1200
- Hair Group B = 1800
- Hair Group C = 3000

## 5. 下一次实验协议（必须重新从最小测试开始）

下一次 Hair 实验必须重新从最小测试开始，按以下顺序：

1. 独立实验场景
2. 只显示一张 Hair PNG
3. 第一张测试图使用实际存在的文件
4. 不播放动画
5. 确认 HairSprite 可见
6. 确认坐标系和 Placement
7. 确认图层在 Body 上方
8. 单张静态图通过后才增加 Idle N
9. Idle N 通过后才增加八方向
10. 不得一次性实现 Idle、Walk 和 Run

## 6. 状态汇总

| 项目 | 状态 |
|---|---|
| Hair Group A（1200–1799）资源存在 | FILE-LEVEL VERIFIED（416/416 有效 PNG + 416/416 Placement 全部存在，磁盘实测；视觉确认待实机） |
| Hair Group B（1800–2399）资源存在 | CANDIDATE（用户观察到的候选组，帧结构未验证） |
| Hair Group C（3000–3599）资源存在 | CANDIDATE（用户观察到的候选组，帧结构未验证） |
| 600 索引槽 / 416 张有效帧的组结构 | FILE-LEVEL VERIFIED for Group A（按标准 416 有效 local_index 逐一检查全部命中；视觉确认待实机） |
| hair_movement_test 实现 | FAILED（实机没有显示任何 Hair） |
| Hair Idle / Walk / Run 实现 | NOT IMPLEMENTED |
| Hair 组与身体类型 / 头部类别对应关系 | NOT IMPLEMENTED（不能确定） |
| Placement 坐标系与 Body 组合方式 | NOT IMPLEMENTED（不能确定） |
| 节点结构与图层结构 | NOT IMPLEMENTED（不能确定） |
| 第一测试基址选择（1200 / 1800 / 3000） | NOT IMPLEMENTED（不能确定） |
| 单张静态 Hair 显示管线（加载 / Placement / 图层顺序） | VERIFIED at engine level（headless + Godot 像素解码确认；01800 按 (21,-49) 绘制在身体上层头部区域，无遮挡；用户实机未见可识别头发 → 原因是图片内容本身为碎片，见 7.4） |
| `res://Hair/` 目录资产内容 | NEW FINDING：全部 1268 个 PNG < 700B，最大仅 20×22px；**不存在完整发型图**（见 7.4） |

状态图例：CONFIRMED = 用户已经实机验证；CANDIDATE = 根据600索引结构推测但尚未验证；FAILED = 已经尝试但没有显示或结果错误；NOT IMPLEMENTED = 尚未实施；IN PROGRESS = 已创建、等待实机观察；FILE-LEVEL VERIFIED = 磁盘文件存在性已逐一实测，视觉/内容确认仍待实机。

## 7. 单张静态图测试（hair_single_frame_test）— 2026-09-08

按第 5 节协议从最小测试重新开始，不复用 `hair_movement_test`。本轮**完全禁止动画**。

### 7.1 资源检查（开始前实测）

| 文件 | 存在性 |
|---|---|
| `res://Hair/01800.png` | EXISTS（已确认） |
| `res://Hair/Placements/01800.txt` | EXISTS（已确认，第一行 X=21，第二行 Y=-49） |

### 7.2 实现内容

- 新文件：`scenes/experiments/hair_single_frame_test.tscn`、`scripts/experiments/hair_single_frame_test.gd`。
- 节点结构（HairAnchor 在实例化场景内部，作为 CharacterBody2D 的子节点、SpriteAnchor 的兄弟节点；未修改 `hum_character.tscn`）：

```text
HairSingleFrameTest (Node2D)
└── StableHumCharacter (instance: scenes/hum_character.tscn)
    ├── SpriteAnchor (Node2D)          ← Body Placement 唯一目标（冻结逻辑，不动）
    │   └── AnimatedSprite2D           ← BodySprite
    └── HairAnchor (Node2D)            ← 与 SpriteAnchor 同一角色逻辑原点
        └── HairSprite (Sprite2D)      ← res://Hair/01800.png, centered=false
```

- HairSprite：`centered=false`、`position=ZERO`、`offset=ZERO`、`flip_h=false`、`visible=true`、`modulate=WHITE`、`scale=ONE`；`z_index = BodySprite.z_index + 1`（运行时读取身体 z_index 后设置）。
- Placement：启动时一次性读取 `res://Hair/Placements/01800.txt`（第一行 X，第二行 Y），只应用一次到 `HairAnchor.position`。不叠加 / 不减去 Body Placement，不改 SpriteAnchor，不做 PNG 尺寸居中或人工补偿，运行期不再读盘。
- 无任何 Hair 动画、无 F5、无基址切换、无 Weapon 同步；人物保持默认 Idle（由冻结的 hum_character.gd 自行驱动）。
- 启动诊断打印：`HAIR SINGLE FRAME TEST` + png_exists / placement_exists / HairSprite.texture(.path) / visible / modulate / scale / HairAnchor.position / HairAnchor.global_position / HairSprite.global_position / HairAnchor 父节点路径 / BodySprite.global_position / BodySprite.z_index / HairSprite.z_index。节点路径错误时打印明确 ERROR，不静默 return。

### 7.3 验证状态

- headless 短检查（`--quit-after 10`）：已执行，无 Parse / Script / 资源路径错误。
- 用户实机反馈：**没有看到头发**，并询问是否为图层遮挡。

### 7.4 诊断结果（2026-09-08，像素级验证）

**图层问题已排除：**

- `HairSprite.z_index=1` > `BodySprite.z_index=0`，头发在身体上层；无其他 CanvasLayer 遮挡（DebugLabel 隐藏）。
- Godot 自身解码确认：`texture_size=(8,32)`、不透明像素 ~147/256（与独立像素分析一致），纹理加载成功。
- 按 Placement (21,-49) 合成预览：01800.png 落在身体帧头部区域（身体局部坐标 x:12..19, y:-2..30）。该处身体为浅色/肤色，Hair 为深藏青色 → 理论上应显示为一小块深色标记（zoom 1.5 下约 12×48 屏幕像素），不是完全不可见。

**关键发现：`res://Hair/` 目录中不存在完整发型图。**

- 全部 **1268** 个 Hair PNG 均 **< 700 字节**。
- 最大文件 = `01473.png`，527 字节，仅 **20×22 px**。
- 测试目标 `01800.png` = 8×32 px 深藏青色碎片（顶部小块 + 下方细条），不是可识别的发型。
- 抽查的组边界文件（01795 / 02395 / 03595）同样都是 ~400 字节小碎片。

**推论：**

- 单张静态显示管线本身工作正常（加载 → Placement → 图层顺序均正确）。
- 第 3 节"Group A/B/C 为完整 Hair 组（600 索引 / 416 有效帧）"的 CANDIDATE 假设**与文件内容不符**：这些编号范围内只有小碎片，没有头部尺寸的发型图。碎片的用途未知（可能是部件、配件或错误提取）。
- 在找到真正包含完整发型的资源之前，继续在本目录内换编号测试意义有限。

### 7.5 待用户确认的问题

1. 实机时人物脸部/头顶是否看到一小块深色标记？（若有 = 01800 已正确绘制，只是内容太小）
2. `Hair/` 这批 PNG 的来源是什么？是否有其他来源包含真正的发型图（原始客户端数据 / 另一批提取文件）？
3. 用户是否在图片查看器中见过任何"像完整发型"的 Hair 编号？如有请提供具体编号。

## 8. 完整 Mapping 测试（hair_full_mapping_test，Group A = 1200）— 2026-09-08

本轮按用户指令对 **Hair Group A（hair_base=1200，占用 1200–1799）** 实现完整 600 索引动作同步。
独立实验场景，不复用、不修改旧 `hair_movement_test` / `hair_single_frame_test`。

### 8.1 文件验证（构建前磁盘实测）

只检查标准有效 local_index 对应的文件（空槽不计为缺失帧），范围 01200–01795：

| 项目 | 结果 |
|---|---|
| 应有有效 PNG 数量 | **416** |
| 实际存在 PNG 数量 | **416** |
| 缺失的 absolute_index 列表（PNG） | **无** |
| Placement 应有 / 实际 | **416 / 416** |
| Placement 缺失列表 | **无** |

结论：Group A 文件名完整符合标准 416 有效帧结构（idle 32 / walk 48 / run 48 / pose 8 / J 48 / K 48 / L 64 / U 48 / I 16 / H 24 / Y 32）。
注意：第 7.4 节的像素分析结论仍然成立——本批 PNG 均为 <700B 小碎片（最大约 20×22px），实机能否形成可识别发型待用户观察。

### 8.2 实现内容

- 新文件：`scripts/experiments/hair_full_mapping_test.gd`、`scenes/experiments/hair_full_mapping_test.tscn`。
- 节点结构（HairAnchor 在实例化场景内部，作为 CharacterBody2D 的子节点、SpriteAnchor 的兄弟节点；未修改 `hum_character.tscn`）：

```text
HairFullMappingTest (Node2D)
├── StableHumCharacter (instance: scenes/hum_character.tscn, appearance_id=0)
│   ├── SpriteAnchor (Node2D)          ← Body Placement 唯一目标（冻结逻辑，不动）
│   │   └── AnimatedSprite2D           ← BodySprite
│   └── HairAnchor (Node2D)            ← 与 SpriteAnchor 同一角色逻辑原点，跟随身体移动
│       └── HairSprite (Sprite2D)      ← centered=false, position/offset=ZERO, flip_h=false
└── HudCanvasLayer (CanvasLayer)
    └── HudLabel (Label)               ← Hair HUD（独立于身体 F1 DebugLabel）
```

- Mapping 逻辑：每帧只读 `BodySprite.animation` / `BodySprite.frame`；从动画名 `<action>_<direction>` 解析动作与方向；`local_index = HumFrames.HUM_ACTIONS[action]["frames"][direction][body_frame]`（直接使用 hum_frames.gd 数组，不重建方向规则、不用 flip_h）；`hair_absolute_index = 1200 + local_index`。
- PNG：`res://Hair/%05d.png % hair_absolute_index`；Placement：`res://Hair/Placements/%05d.txt % hair_absolute_index`（同一 absolute_index）。
- Placement / Texture 均在 `_ready` 一次性预加载并缓存（键 = hair_absolute_index），运行期只查缓存，禁止每帧读盘。
- Hair Placement 只应用一次到 `HairAnchor.position`：不叠加/不减 Body Placement、不改 SpriteAnchor、不做 PNG 尺寸居中或人工补偿、不改 `HairSprite.position`。
- 缺图处理：PNG 缺失时 `HairSprite.texture = null`、`visible = false`；下一帧存在时自动恢复显示（缓存查表天然支持）。
- 图层：运行时设置 `HairSprite.z_index = BodySprite.z_index + 1`，头发固定显示在身体之上。
- Hair 层不控制身体：不调用 `play()`、不改 frame / 方向 / 速度 / action_locked / dead；R 复活后身体回 Idle，Hair 自动跟随对应方向 Idle。
- F5 = 显示/隐藏 Hair 层（`hair_enabled` → `HairAnchor.visible`）。
- HUD 字段：hair_enabled / hair_base / body_animation / body_frame / current_action / current_direction / local_index / hair_absolute_index / hair_png_exists / hair_placement_exists / hair_placement / HairAnchor.position / HairSprite.visible / HairSprite.z_index。

### 8.3 验证状态

- headless 短检查（`--quit-after 10`）：已执行，无 Parse / Script / 资源路径错误（见本轮运行记录）。
- 用户实机测试：**待进行**（IN PROGRESS）。

### 8.4 范围声明

本次只处理 Group A（1200–1799）。不处理 Hair 1800 组、3000 组、2400–2999 零散文件；不涉及 Weapon / 背包 / 换装 / 正式 Hum 集成 / 24 套身体预设修改。

