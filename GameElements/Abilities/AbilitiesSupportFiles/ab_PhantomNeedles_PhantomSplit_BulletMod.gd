extends GameObjectComponent

@export var _wasSplit : bool = false

var _splitAngle : float = deg_to_rad(45)
var _speedMult : float = 0.7

func _ready() -> void:
	if _wasSplit:
		return

	initGameObjectComponent()
	if _gameObject == null:
		return

	_gameObject.connectToSignal("DamageApplied", BulletDamageApplied)

func BulletDamageApplied(categories:Array[String], damageAmount:float, applyReturn:Array, targetNode:GameObject, critical:bool):
	if not critical or _wasSplit:
		return
	# prepare for cloning!
	_wasSplit = true
	_gameObject.disconnectFromSignal("DamageApplied", BulletDamageApplied)
	var originalNeedle_raybasedMover: Node = _gameObject.getChildNodeWithMethod("get_targetDirection")
	originalNeedle_raybasedMover._currentSpeed *= _speedMult
	originalNeedle_raybasedMover._currentAcceleration *= _speedMult
	var originalDirection : Vector2        = originalNeedle_raybasedMover.get_targetDirection()
	originalNeedle_raybasedMover.set_targetDirection(originalDirection.rotated(-_splitAngle))
	var originalNeedle_bullet: Node = _gameObject.getChildNodeWithProperty("_remainingLifeTime")

	var secondNeedle: GameObject = Global.duplicate_gameObject_node(_gameObject)
	secondNeedle.setInheritModifierFrom(_gameObject.getInheritModifierFrom())
	secondNeedle.set_sourceGameObject(_gameObject.get_rootSourceGameObject())
	Global.attach_toWorld(secondNeedle, false)
	var secondNeedle_raybasedMover : Node = secondNeedle.getChildNodeWithMethod("set_targetDirection")
	secondNeedle_raybasedMover.set_targetDirection(originalDirection.rotated(_splitAngle))

	# we need to copy some variables, as well! this is, of course, highly implementation dependent,
	# but we should know which mover is used and that a bullet script is there, at this point.
	var secondNeedle_bulletNode : Node = secondNeedle.getChildNodeWithProperty("_remainingLifeTime")
	secondNeedle_bulletNode._remainingLifeTime = originalNeedle_bullet._remainingLifeTime
	secondNeedle_bulletNode._numberOfHits = originalNeedle_bullet._numberOfHits
	secondNeedle_raybasedMover._currentSpeed = originalNeedle_raybasedMover._currentSpeed
	secondNeedle_raybasedMover._currentAcceleration = originalNeedle_raybasedMover._currentAcceleration
	secondNeedle_raybasedMover._velocity_offset = originalNeedle_raybasedMover._velocity_offset
	secondNeedle_raybasedMover._allTimeHitObjects = originalNeedle_raybasedMover._allTimeHitObjects


