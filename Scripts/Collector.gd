extends GameObjectComponent2D

@export var BasePickupRange : float = 36.0

signal CollectableCollected(collectable:GameObject)

var _modifiedPickupRange
var _modifiedXPGain
var _collectPools : Array[String] = ["Collectable", "XPCollectable"]

# only use for the statistics. not very optimized...
func get_modified_values() -> Array:
	return [
		_modifiedPickupRange,
		_modifiedXPGain
	]
func is_character_base_node() -> bool : return true

func _ready():
	initGameObjectComponent()
	_modifiedPickupRange = createModifiedFloatValue(BasePickupRange, "PickupRange")
	# the modified XP gain is only for the stats overview! the world
	# uses the XpGain modifier internally when xp was collected.
	_modifiedXPGain = createModifiedFloatValue(1.0, "XpGain")

func _process(delta):
	for pool in _collectPools:
		var hits = Global.World.Locators.get_gameobjects_in_circle(
				pool, global_position, _modifiedPickupRange.Value())
		for hitGO in hits:
			var collectProvider = hitGO.getChildNodeWithMethod("collect")
			if collectProvider:
				if collectProvider.has_signal("Collected"):
					collectProvider.Collected.connect(collectableWasCollected.bind(hitGO))
				collectProvider.collect(self)

func get_total_pickup_range() -> float:
	return _modifiedPickupRange.Value()

func collectableWasCollected(_collector:GameObject, collectedGO:GameObject):
	CollectableCollected.emit(collectedGO)

func collectAllXP():
	Global.World.Collectables.trigger_collect_for_all_in_pool("XPCollectable", self)
