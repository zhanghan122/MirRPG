extends CharacterBody2D

# MonsterCollision: 怪物动画场景（ForestStranger 等）的物理包装体。
# 怪物根节点保持为纯动画场景，本身体只负责碰撞与未来 move_and_slide() 追踪。
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

var _shape_node: CollisionShape2D


func _ready() -> void:
	_shape_node = get_node_or_null("FeetShape") as CollisionShape2D


# 预留接口：未来死亡处理（disappear / stay_last_frame）后关闭碰撞用，本轮不调用。
func set_collision_enabled(enabled: bool) -> void:
	if _shape_node != null:
		_shape_node.set_deferred("disabled", not enabled)


# 返回子怪物动画节点（ForestStranger）。
func get_monster() -> Node2D:
	for child in get_children():
		if not (child is CollisionShape2D):
			return child as Node2D
	return null
