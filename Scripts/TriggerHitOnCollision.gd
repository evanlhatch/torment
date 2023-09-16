extends GameObjectComponent

signal OnHit(nodeHit:GameObject, hitNumber:int)

var _numberOfHits : int = 0

# Called when the node enters the scene tree for the first time.
func _ready():
	initGameObjectComponent()
	_gameObject.connectToSignal("CollisionStarted", collisionWithNode)

func collisionWithNode(node:Node):
	node = Global.get_gameObject_in_parents(node)
	if not node:
		return;
	emit_signal("OnHit", node, _numberOfHits)
	_numberOfHits += 1
