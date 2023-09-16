extends GameObjectComponent

@export var Bonfire : Node2D
@export var TargetPosition : Node2D
@export var DoReturnFlag : bool
@export var UnlockKey : String
@export var ArrivalPosition : Node2D
@export var SteeringRayCast : RayCast2D

var targetDirectionSetter
var positionProvider
var facingSetter

var dirRotation : float

func _ready():
	initGameObjectComponent()
	targetDirectionSetter = _gameObject.getChildNodeWithMethod("set_targetDirection")
	positionProvider = _gameObject.getChildNodeWithMethod("get_worldPosition")
	facingSetter = _gameObject.getChildNodeWithMethod("set_facingDirection")
	if facingSetter != null:
		facingSetter.set_facingDirection(
			(Bonfire.global_position - positionProvider.get_worldPosition()).normalized())
	var quest_gate = _gameObject.getChildNodeWithSignal("FirstTimeUnlock")
	if quest_gate: quest_gate.connect("FirstTimeUnlock", first_time_unlock)

func return_to_bonfire(doReturn:bool):
	DoReturnFlag = doReturn
	targetDirectionSetter.set_targetWorldPos(Vector2.ZERO)

func _process(delta):
	if DoReturnFlag:
		var targetPos : Vector2 = TargetPosition.global_position
		var myPos : Vector2 = positionProvider.get_worldPosition()

		SteeringRayCast.target_position = (targetPos - myPos).normalized() * 48.0
		if SteeringRayCast.is_colliding():
			var tangent = SteeringRayCast.get_collision_normal().rotated(PI * 0.5)
			if tangent.dot(SteeringRayCast.target_position) < 0.0:
				dirRotation = clamp(dirRotation + delta * 5.0, -PI * 0.5, PI * 0.5) # turn right
			else:
				dirRotation = clamp(dirRotation - delta * 5.0, -PI * 0.5, PI * 0.5) # turn left
		else:
			if dirRotation > 0.0:
				dirRotation = clamp(dirRotation - delta * 5.0, 0.0, PI * 0.5)
			elif dirRotation < 0.0:
				dirRotation = clamp(dirRotation + delta * 5.0, -PI * 0.5, 0.0 )

		var dir = (targetPos - myPos).normalized().rotated(dirRotation)
		targetDirectionSetter.set_targetDirection(dir)
		if myPos.distance_to(targetPos) < 8.0:
			targetDirectionSetter.set_targetDirection(Vector2.ZERO)
			facingSetter.set_facingDirection(
				(Bonfire.global_position - positionProvider.get_worldPosition()).normalized())
			return_to_bonfire(false)
			# snap position to pixel so characters don't float around when camera moves.
			positionProvider.set_worldPosition(Vector2(
				roundi(myPos.x), roundi(myPos.y)))

func first_time_unlock(quest_node:Node):
	positionProvider.global_position = ArrivalPosition.global_position
	return_to_bonfire(true)
