extends GameObjectComponent

@export var ProbabilityToApply : float = 1
@export var SpawnAndApplyScene : PackedScene

func _ready():
	initGameObjectComponent()
	_gameObject.connectToSignal("Collected", applyNode)

func applyNode(toNode:GameObject):
	if ProbabilityToApply >= 1 or randf() < ProbabilityToApply:
		var spawnedNode = SpawnAndApplyScene.instantiate()
		toNode.add_child(spawnedNode)
		if spawnedNode.has_method("set_modifierSource"):
			spawnedNode.set_modifierSource(get_parent())
