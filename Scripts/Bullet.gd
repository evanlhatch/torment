extends GameObjectComponent

@export var endLifeWhenStopped : bool = true
## lifeTime is ignored when <= 0
@export var lifeTime : float = 1
@export var destroyWhenLifeEnded = false
@export var endLifeAfterNumberOfHits : int = 1
@export var endLifeAfterDistance : float = 0
@export var endLifeAfterDistanceModifier : String = "Range"
@export var endLifeWhenBlocked : bool = true
@export var ModifierCategories : Array[String] = ["Projectile"]
@export var IsCharacterBaseNode : bool = false
@export var DelayEndOfLifeByOneFrame : bool = false
@export var UseModifiedArea : bool = true

@export_group("Curved Movement Parameters")
@export var MovementCurvatureAngle : float = 0.0
@export var MovementCurvatureDistance : float = 0.0


signal OnHit(nodeHit:GameObject, hitNumber:int)
signal OnEndOfLife

var _remainingLifeTime : float
var _numberOfHits : int
var _distanceTraveled : float

var _modifiedNumberOfHits
var _modifiedSize
var _modifiedMovementSpeed
var _modifiedLifetime
var _modifiedMaxDistance
# only use for the statistics. not very optimized...
func get_modified_values() -> Array:
	return [
		_modifiedNumberOfHits,
		_modifiedSize
	]
func is_character_base_node() -> bool : return IsCharacterBaseNode

var _directionSetter : Node
var _speedProvider : Node
var _targetPositionProvider : Node

func _ready():
	_distanceTraveled = 0
	_numberOfHits = 0
	initGameObjectComponent()
	if endLifeWhenStopped:
		_gameObject.connectToSignal("MovementStopped", endLife)
	_gameObject.connectToSignal("CollisionStarted", collisionWithNode)
	_directionSetter = _gameObject.getChildNodeWithMethod("set_targetDirection")
	_speedProvider = _gameObject.getChildNodeWithMethod("get_movement_speed")

	initialize_modifiers(self)
	_modifiedSize.connect("ValueUpdated", sizeWasUpdated)
	_remainingLifeTime = _modifiedLifetime.Value()

	sizeWasUpdated(_modifiedSize.Value(), _modifiedSize.Value())
	if endLifeWhenBlocked:
		_gameObject.connectToSignal("DamageApplied", _on_hit_damage_applied)

func initialize_modifiers(referenceParent):
	_modifiedNumberOfHits = referenceParent.createModifiedIntValue(endLifeAfterNumberOfHits, "Force")
	_modifiedSize = referenceParent.createModifiedFloatValue(1, "Area")
	_modifiedLifetime = referenceParent.createModifiedFloatValue(lifeTime, "Force")
	_modifiedMaxDistance = referenceParent.createModifiedFloatValue(endLifeAfterDistance, endLifeAfterDistanceModifier)
	if _speedProvider != null:
		_modifiedMovementSpeed = referenceParent.createModifiedFloatValue(_speedProvider.get_movement_speed(), "Range")
	applyModifierCategories()

func applyModifierCategories():
	_modifiedNumberOfHits.setModifierCategories(ModifierCategories)
	_modifiedMaxDistance.setModifierCategories(ModifierCategories)
	if _modifiedMovementSpeed != null:
		_modifiedMovementSpeed.setModifierCategories(ModifierCategories)
		_speedProvider.set_movement_speed(_modifiedMovementSpeed.Value())
		if _speedProvider.has_method("set_acceleration"):
			_speedProvider.set_acceleration(_speedProvider.acceleration * (_modifiedMovementSpeed.Value() / _modifiedMovementSpeed.BaseValue()))
	_modifiedSize.setModifierCategories(ModifierCategories)

func _exit_tree():
	_allModifiedValues.clear()
	_modifiedNumberOfHits = null
	_modifiedSize = null
	_modifiedMovementSpeed = null
	_modifiedLifetime = null
	_modifiedMaxDistance = null

func transformCategories(onlyWithDamageCategory:String, addModifierCategories:Array[String], removeModifierCategories:Array[String], addDamageCategories:Array[String], removeDamageCategories:Array[String]):
	# we ignore the onlyWithDamageCategory here, since this component
	# doesn't have DamageCategories. the BulletEmitter will filter the
	# DamageCategory, though, so we should be fine here.
	for addMod in addModifierCategories:
		if not ModifierCategories.has(addMod):
			ModifierCategories.append(addMod)
	for remMod in removeModifierCategories:
		ModifierCategories.erase(remMod)
	applyModifierCategories()

func sizeWasUpdated(_sizeBefore:float, newSize:float):
	if UseModifiedArea:
		_gameObject.scale = Vector2.ONE * newSize

func collisionWithNode(node:Node):
	if _numberOfHits < _modifiedNumberOfHits.Value():
		node = Global.get_gameObject_in_parents(node)
		if node == null or node.is_queued_for_deletion():
			# collision doesn't seem relevant!
			return
		emit_signal("OnHit", node, _numberOfHits)
		_numberOfHits += 1
		if _numberOfHits == _modifiedNumberOfHits.Value():
			endLife()

func endLife():
	if DelayEndOfLifeByOneFrame:
		await get_tree().process_frame
	emit_signal("OnEndOfLife")
	if destroyWhenLifeEnded:
		get_parent().queue_free()

func set_homing_target(targetPositionProvider:Node):
	_targetPositionProvider = targetPositionProvider

func _process(delta):
#ifdef PROFILING
#	updateBullet(delta)
#
#func updateBullet(delta):
#endif
	if _remainingLifeTime > 0:
		_remainingLifeTime -= delta
		if _remainingLifeTime <= 0:
			endLife()

	if _directionSetter and MovementCurvatureAngle > 0.0 and MovementCurvatureDistance > 0.0:
		var dir = _directionSetter.get_targetDirection()
		_directionSetter.set_targetDirection(dir.rotated(
			deg_to_rad(MovementCurvatureAngle) / (MovementCurvatureDistance * delta)))

	if _directionSetter != null and _targetPositionProvider != null:
		_directionSetter.set_targetDirection(
			(_targetPositionProvider.get_worldPosition() - get_gameobjectWorldPosition()).normalized())

	if get_maximum_distance() > 0:
		if _speedProvider != null and _speedProvider.has_method("get_current_speed"):
			_distanceTraveled += _speedProvider.get_current_speed() * delta
			if _distanceTraveled >= get_maximum_distance():
				endLife()

func get_maximum_distance() -> float:
	if endLifeAfterDistance <= 0:
		return 0
	return _modifiedMaxDistance.Value()

func _on_hit_damage_applied(damageCategories:Array[String], _damageAmount:float, applyReturn:Array, _targetNode:GameObject, _isCritical:bool):
	if applyReturn[0] == Global.ApplyDamageResult.Blocked:
		_numberOfHits = Global.MAX_VALUE
		_gameObject.queue_free()
