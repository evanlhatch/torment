extends GameObjectComponent


func _ready():
	initGameObjectComponent()
	_gameObject.connectToSignal("Collected", collected)


func collected(byNode:GameObject):
	var collectAllXPNode = byNode.getChildNodeWithMethod("collectAllXP")
	if collectAllXPNode != null:
		collectAllXPNode.collectAllXP()
