extends GameObjectComponent

@export var RaiseSkeletonScene:PackedScene
@export var MinWaitTime:float = 5.0
@export var MaxWaitTime:float = 10.0
@export var SkeletonAmount:int = 8

var gameObject : GameObject
var positionProvider : Node
var _delay_timer : Timer
var _wait_time : float
var targetFacingSetter : Node

func _ready():
	initGameObjectComponent()
	gameObject = Global.get_gameObject_in_parents(self)
	positionProvider = gameObject.getChildNodeWithMethod("get_worldPosition")
	targetFacingSetter = gameObject.getChildNodeWithMethod("set_facingDirection")
	_delay_timer = Timer.new()
	add_child(_delay_timer)
	_wait_time = randf_range(MinWaitTime, MaxWaitTime)


func _process(delta):
	_wait_time -= delta
	if _wait_time < 0:
		_wait_time = randf_range(MinWaitTime, MaxWaitTime)
		var attackDir = targetFacingSetter.get_facingDirection()
		raise_skeletons(attackDir)



func raise_skeletons(direction:Vector2):
	var dir = direction * (30.0 + float(SkeletonAmount) * 10.0) 
	for i in SkeletonAmount:
		var skeleton_raising = RaiseSkeletonScene.instantiate()
		Global.attach_toWorld(skeleton_raising)
		skeleton_raising.raise(positionProvider.get_worldPosition() + dir, -dir)
		dir = dir.rotated(2 * PI / float(SkeletonAmount))
		_delay_timer.start(0.075); await _delay_timer.timeout