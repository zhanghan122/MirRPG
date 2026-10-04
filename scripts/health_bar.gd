extends Node2D
## health_bar.gd — 通用像素风血条（PHASE 3）。
##
## - 结构：Node2D 根 + Background/Foreground 两个 ColorRect（不用 ProgressBar，避免主题样式干扰）。
##   前景按 hp 百分比从左侧缩放；背景为深色底。
## - 颜色：前景随血量在红(低)→绿(满)之间插值，便于 F8/F9 测试时肉眼判断。
## - 位置：本组件负责"条本身"的几何——Background/Foreground 本地位置固定 Vector2(-width/2, 0)，
##   条以根节点原点为中心水平居中 x∈[-width/2, +width/2]；挂载方只需一次性设置
##   HealthBar.position = Vector2(0, y)（玩家 y=-54、怪物 y=-70），之后不再逐帧移动。
## - mouse_filter = IGNORE：不拦截右键移动等输入。

@export var bar_width := 50.0
@export var bar_height := 6.0

const COLOR_EMPTY := Color(0.75, 0.12, 0.1)   # 低血量（红）
const COLOR_FULL := Color(0.18, 0.85, 0.25)   # 满血（绿）

var _bg: ColorRect
var _fg: ColorRect


func _ready() -> void:
	_bg = $Background
	_fg = $Foreground
	_apply_size()


## 设置当前血量：前景宽度按百分比缩放，颜色红→绿插值。
func set_hp(current_hp: float, max_hp: float) -> void:
	var pct := 0.0 if max_hp <= 0.0 else clampf(current_hp / max_hp, 0.0, 1.0)
	_fg.size.x = bar_width * pct
	_fg.color = COLOR_EMPTY.lerp(COLOR_FULL, pct)


## 运行时调整条尺寸（怪物比玩家大，可挂上后加宽）。
func set_bar_size(width: float, height: float) -> void:
	bar_width = width
	bar_height = height
	if _bg != null and _fg != null:
		_apply_size()


func _apply_size() -> void:
	# Background/Foreground 本地位置固定 Vector2(-width/2, 0)：条以根节点原点为中心水平居中，
	# x∈[-width/2, +width/2]。扣血时 Foreground 左边固定在 -width/2、只缩短右边（set_hp 只改 size.x）。
	# 挂载方只需一次性设置 HealthBar.position = Vector2(0, y)，本组件内无第二处 X 偏移。
	var pos := Vector2(-bar_width * 0.5, 0.0)
	_bg.position = pos
	_bg.size = Vector2(bar_width, bar_height)
	_fg.position = pos
	_fg.size = Vector2(bar_width, bar_height)
