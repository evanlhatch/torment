extends Node

@export var ElectrifyScene : PackedScene
@export var ElectrifyChance : float = 0.5

var _effectPrototype : EffectBase
var _source : GameObject

func _ready() -> void:
	if _effectPrototype == null:
		_effectPrototype = ElectrifyScene.instantiate()

func _exit_tree():
	if _effectPrototype != null:
		_effectPrototype.queue_free()
		_effectPrototype = null

func AquireAbility(modifiedTarget:Node) -> Array[Node]:
	# we'll get the correct component via the LightningSpawnerIdentifier, that is
	# the safest and quickest way...
	var lightningSpawner = modifiedTarget.getChildNodeWithProperty("LightningSpawnerIdentifier")
	if lightningSpawner == null:
		printerr("ab_LightningStrike_ElectrifyingStrike couldn't find the base LightningSpawner!")
		return []
	_source = modifiedTarget
	lightningSpawner.StunApplied.connect(StunWasApplied)
	return []
	
func StunWasApplied(toNode:GameObject) -> void:
	if randf() < ElectrifyChance:
		toNode.add_effect(_effectPrototype, _source)
