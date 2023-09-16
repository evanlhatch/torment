extends GameObjectComponent

@export var BaseProbabilityToApply : float = 1
@export var SpawnAndApplyScene : PackedScene

func _ready():
	initGameObjectComponent()
	_gameObject.connectToSignal("OnHit", applyNode)

func applyNode(toNode:GameObject, hitNumber:int):
	var prob : float = BaseProbabilityToApply
	while prob > 0:
		# when the probability is over 1, we don't roll the dice!
		if prob < 1 and randf() > prob:
			return
		prob -= 1
		
		var spawnedNode = SpawnAndApplyScene.instantiate()
		toNode.add_child(spawnedNode)
		if spawnedNode.has_method("set_modifierSource"):
			spawnedNode.set_modifierSource(get_parent())
