extends GameObjectComponent

@export var HuntressNode : GameObject
@export var MaxDistance : float = 16.0
@export var FollowOffset : Vector2 = Vector2(12, -12)
@export var SteeringRayCast : RayCast2D

var _following : bool
var _lastNonZeroVelocity : Vector2

var velocityProvider : Node
var targetDirectionSetter : Node
var huntress_positionProvider : Node
var huntress_character_selection : Node
var return_to_pos_behaviour : Node

var dirRotation : float


func _ready() -> void:
	initGameObjectComponent()
	velocityProvider = _gameObject.getChildNodeWithMethod("get_targetVelocity")
	targetDirectionSetter = _gameObject.getChildNodeWithMethod("set_targetDirection")
	huntress_positionProvider = HuntressNode.getChildNodeWithMethod("get_worldPosition")
	huntress_character_selection = HuntressNode.getChildNodeWithSignal("PlayerControlChanged")
	if is_instance_valid(HuntressNode):
		huntress_character_selection.PlayerControlChanged.connect(_on_huntress_selected)
	return_to_pos_behaviour = _gameObject.getChildNodeWithMethod("return_to_bonfire")


func _on_huntress_selected(is_selected:bool):
	_following = is_selected
	return_to_pos_behaviour.return_to_bonfire(not is_selected)


func _process(delta: float) -> void:
	if _following:
		var targetPos : Vector2 = huntress_positionProvider.get_worldPosition() + FollowOffset
		var myPos : Vector2 = get_gameobjectWorldPosition()

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
		if myPos.distance_to(targetPos) < MaxDistance:
			targetDirectionSetter.set_targetDirection(Vector2.ZERO)


func get_facingDirection() -> Vector2:
	if velocityProvider:
		var targetVel : Vector2 = velocityProvider.get_targetVelocity()
		if targetVel.length() > 0.1:
			_lastNonZeroVelocity = targetVel
			return targetVel
	return _lastNonZeroVelocity


func set_facingDirection(newFacing : Vector2):
	_lastNonZeroVelocity = newFacing
