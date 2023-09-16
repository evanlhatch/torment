extends Resource
class_name XPGemPool
@export var GemPool: Array[XPGemPoolItem] = []

func get_biggest_smaller_than_target(target_amount: float) -> XPGemPoolItem:
	var biggest_smaller_than_target: XPGemPoolItem = null
	for gem_pool_item in GemPool:
		if gem_pool_item.GemValue <= target_amount:
			if biggest_smaller_than_target == null:
				biggest_smaller_than_target = gem_pool_item
			elif gem_pool_item.GemValue > biggest_smaller_than_target.GemValue:
				biggest_smaller_than_target = gem_pool_item
	return biggest_smaller_than_target
