extends GameObjectComponent

@export var EscapeDirection : Vector2 = Vector2(0.71, 0.71) 
@export var Lifetime : float = 20.0

var targetDirectionSetter : Node
var targetFacingSetter : Node

func _ready():
	initGameObjectComponent()
	targetDirectionSetter = _gameObject.getChildNodeWithMethod("set_targetDirection")
	targetDirectionSetter.set_targetDirection(EscapeDirection)
	targetFacingSetter = _gameObject.getChildNodeWithMethod("set_facingDirection")
	targetFacingSetter.set_facingDirection(EscapeDirection)
	await get_tree().create_timer(Lifetime, false).timeout
	if _gameObject != null and not _gameObject.is_queued_for_deletion():
		_gameObject.queue_free()

