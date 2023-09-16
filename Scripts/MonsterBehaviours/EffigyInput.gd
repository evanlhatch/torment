extends GameObjectComponent

@export var SetPlayerAsTargetOnSpawn : bool = true
@export var FreezeAngle : float = 45.0
@export var BlockChanceBonusWhenNotMoving : float = 2.0
@export var SpriteAnimationMove : Node
@export var SpriteAnimationStop : Node
@export var MovementForce : float = 300
@export var StopForce : float = 3000

var directionSetter : Node
var facingSetter : Node
var input_direction : Vector2

signal input_dir_changed(dir_vector:Vector2)

var _stopped : bool
var _targetPosProvider : Node
var _targetFacingProvider : Node
var _healthComponent : Node

func _ready():
	initGameObjectComponent()
	directionSetter = _gameObject.getChildNodeWithMethod("set_targetDirection")
	facingSetter = _gameObject.getChildNodeWithMethod("set_facingDirection")
	_healthComponent = _gameObject.getChildNodeWithMethod("setInvincibleForTime")
	if (SetPlayerAsTargetOnSpawn and Global.World.Player != null and
		not Global.World.Player.is_queued_for_deletion()):
		set_target(Global.World.Player)


func _process(delta):
#ifdef PROFILING
#	updateImpShieldInput(delta)
#
#func updateImpShieldInput(delta):
#endif
	var newInputDir : Vector2 = Vector2.ZERO
	
	if is_targetProvider_valid() and _targetFacingProvider:
		var targetDir = _targetPosProvider.get_worldPosition() - get_gameobjectWorldPosition()
		var targetFacing = _targetFacingProvider.get_facingDirection()
		if abs(rad_to_deg(targetFacing.angle_to(-targetDir))) >= FreezeAngle:
			var targetPos = _targetPosProvider.get_worldPosition()
			newInputDir = (targetPos - get_gameobjectWorldPosition()).normalized()
			facingSetter.set_facingDirection(get_aimDirection())
			SpriteAnimationMove.visible = true
			SpriteAnimationStop.visible = false
		else:
			SpriteAnimationMove.visible = false
			SpriteAnimationStop.visible = true
		updateModifier()

	if newInputDir != input_direction:
		input_direction = newInputDir
		emit_signal("input_dir_changed", input_direction)
		directionSetter.set_targetDirection(input_direction)
		if not _stopped:
			facingSetter.set_facingDirection(get_aimDirection())


func set_target(targetNode : Node):
	_targetPosProvider = targetNode.getChildNodeWithMethod("get_worldPosition")
	_targetFacingProvider = targetNode.getChildNodeWithMethod("get_facingDirection")


func get_inputWalkDir() -> Vector2:
	return input_direction

func get_aimDirection() -> Vector2:
	if is_targetProvider_valid():
		var targetPos = _targetPosProvider.get_worldPosition()
		return (targetPos - get_gameobjectWorldPosition()).normalized()
	return input_direction.normalized()

func is_targetProvider_valid():
	return _targetPosProvider != null and not _targetPosProvider.is_queued_for_deletion()

func updateModifier():
	if _stopped and SpriteAnimationMove.visible:
		_positionProvider.movementForce = MovementForce
		_healthComponent.setInvincibleForTime(1800)
		_stopped = false
	elif not _stopped and SpriteAnimationStop.visible:
		_positionProvider.movementForce = StopForce
		_healthComponent.setInvincibleForTime(-1)
		_stopped = true
