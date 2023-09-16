extends GameObjectComponent

@export var BaseTriggerDistance : float = 40.0
@export var BaseSpread : float = 0.0
@export var SpawnedScene : PackedScene
@export var Active : bool = true
@export var UseModifier : bool = true
@export var ResetDistanceTraveledOnTrigger : bool

@export_group("Animation Trail Parameters")
@export var UsedForAnimationFrameTrail : bool = false
@export var ReferenceSprite : AnimatedSprite2D

@export_group("internal state")
@export var _weapon_index : int = -1

var _modifiedSpeed

var _previousPosition : Vector2
var _traveledDistance : float
var _timeSinceLastTrigger : float

var _prototypeSpawn : Node


func _enter_tree():
	_traveledDistance = 0.0
	initGameObjectComponent()
	# wait one frame in case position has been set from the outside
	await get_tree().process_frame
	if _gameObject:
		if _positionProvider:
			_previousPosition = _positionProvider.get_worldPosition()
			if _prototypeSpawn == null:
				_prototypeSpawn = SpawnedScene.instantiate()
				if "_weapon_index" in _prototypeSpawn:
					_prototypeSpawn._weapon_index = _weapon_index
				if _prototypeSpawn.has_method("setInheritModifierFrom"):
					_prototypeSpawn.setInheritModifierFrom(_gameObject)

		_modifiedSpeed = createModifiedFloatValue(1.0 / BaseTriggerDistance, "AttackSpeed")
	else:
		var parent = get_parent()
		if parent and parent is Item:
			_weapon_index = parent.WeaponIndex

func _exit_tree():
	if _prototypeSpawn != null:
		_prototypeSpawn.queue_free()
		_prototypeSpawn = null
	_gameObject = null
	_modifiedSpeed = null
	_positionProvider = null

func _process(delta):
	if not Active: return
	_timeSinceLastTrigger += delta
	if _positionProvider and _prototypeSpawn:
		var newPos = _positionProvider.get_worldPosition()
		var posDelta = _previousPosition.distance_to(newPos)
		_previousPosition = newPos
		_traveledDistance += posDelta
		var totalTriggerDistance = get_totalTriggerDistance()
		if _traveledDistance >= totalTriggerDistance:
			if ResetDistanceTraveledOnTrigger: _traveledDistance = 0
			else: _traveledDistance -= totalTriggerDistance
			trigger()

func set_active(active:bool):
	Active = active
	_previousPosition = _positionProvider.get_worldPosition()
	_traveledDistance = 0.0

func trigger():
	var spawnedObject = null
	_timeSinceLastTrigger = 0

	if UsedForAnimationFrameTrail:
		spawnedObject = _prototypeSpawn.duplicate()
	else:
		spawnedObject = Global.duplicate_gameObject_node(_prototypeSpawn)
		if spawnedObject.has_method("set_sourceGameObject"):
			spawnedObject.set_sourceGameObject(_gameObject)
		elif spawnedObject.has_method("set_externalSource"):
			spawnedObject.set_externalSource(_gameObject)
	spawnedObject.global_position = _previousPosition + Vector2(0, BaseSpread).rotated(randf() * 2 * PI)
	Global.attach_toWorld(spawnedObject)

	if spawnedObject.has_method("start"):
		spawnedObject.start(_gameObject)
	if UsedForAnimationFrameTrail and ReferenceSprite != null:
		spawnedObject.set_animation_frame(ReferenceSprite.animation, ReferenceSprite.frame)


func get_totalTriggerDistance() -> float:
	if not UseModifier: return BaseTriggerDistance
	if _modifiedSpeed.Value() == 0: return 99999.0
	return 1.0 / _modifiedSpeed.Value()

@export_group("Modifier Info Area")
@export var Icon : Texture2D
@export var Name : String = "ShockwaveOnDistance"
@export_multiline var TooltipText : String = ""

func get_modifierInfoArea_icon() -> Texture2D:
	return Icon

func get_modifierInfoArea_cooldownfactor() -> float:
	var totalTriggerDistance = get_totalTriggerDistance()
	return 1.0 - _traveledDistance / totalTriggerDistance

func get_modifierInfoArea_active() -> bool:
	return _timeSinceLastTrigger < 0.5

func get_modifierInfoArea_name() -> String:
	return Name
