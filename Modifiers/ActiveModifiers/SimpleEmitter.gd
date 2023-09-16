extends GameObjectComponent

@export_group("Emission Parameters")
@export var EmitEverySeconds : float = 1
@export var EmitRadius : float = 0
@export var BulletCountPerEmit : int = 1
@export var EmissionFanAngle : float = 0
@export var EmissionAngleOffsetToAimDirection : float = 0
@export var EmissionFanRandomRange : float = 0
@export var EmissionPosOffset : Vector2
@export var ModifierCategories : Array[String] = ["Projectile"]

@export_group("Scene References")
@export var EmitScene : PackedScene
@export var BulletGroups : Array[StringName]

@export_group("Scaling Modifiers")
@export var FanAngleScalingFactor : float = 0.4

@export_group("Internal State")
@export var _weapon_index : int

var _directionProvider : Node
var _bulletPrototype : GameObject
var _emitEverySecondsModified : float

var _emit_overflow : float
var _emit_timer : float
var _modifiedAttackSpeed
var _modifiedFanAngle
var _modifiedEmitCount

# only use for the statistics. not very optimized...
func get_modified_values() -> Array:
	var allMods : Array = [
		_modifiedAttackSpeed,
		_modifiedFanAngle,
		_modifiedEmitCount
	]
	if _bulletPrototype != null:
		var bulletModNodes : Array = []
		_bulletPrototype.getChildNodesWithMethod("get_modified_values", bulletModNodes)
		for bulletModNode in bulletModNodes:
			allMods.append_array(bulletModNode.get_modified_values())
	return allMods

func _enter_tree():
	initGameObjectComponent()
	if _gameObject == null:
		var parent = get_parent()
		if parent and parent.has_method("get_weapon_index"):
			_weapon_index = parent.get_weapon_index()
		process_mode = Node.PROCESS_MODE_DISABLED
	else:
		process_mode = Node.PROCESS_MODE_INHERIT
		_directionProvider = _gameObject.getChildNodeWithMethod("get_aimDirection")
		_bulletPrototype = EmitScene.instantiate()
		_bulletPrototype.setInheritModifierFrom(_gameObject)
		var weapon_index_setter = _bulletPrototype.getChildNodeWithMethod("set_weapon_index")
		if weapon_index_setter != null: weapon_index_setter.set_weapon_index(_weapon_index)

		var bullet_modifier_nodes : Array = []
		_bulletPrototype.getChildNodesWithMethod("initialize_modifiers", bullet_modifier_nodes)
		for n in bullet_modifier_nodes: n.initialize_modifiers(self)

		_modifiedAttackSpeed = createModifiedFloatValue(1.0 / EmitEverySeconds, "AttackSpeed")
		_modifiedAttackSpeed.connect("ValueUpdated", attackSpeedWasUpdated)
		_modifiedFanAngle = createModifiedFloatValue(EmissionFanAngle, "Area")
		_modifiedEmitCount = createModifiedFloatValue(BulletCountPerEmit, "EmitCount")
		applyModifierCategories()
		attackSpeedWasUpdated(_modifiedAttackSpeed.Value(), _modifiedAttackSpeed.Value())
		_emit_timer = _emitEverySecondsModified
		for group in BulletGroups:
			_bulletPrototype.add_to_group(group)


func _exit_tree():
	_allModifiedValues.clear()
	_modifiedAttackSpeed = null
	_modifiedFanAngle = null
	_modifiedEmitCount = null
	if _bulletPrototype != null:
		_bulletPrototype.queue_free()
		_bulletPrototype = null

func applyModifierCategories():
	_modifiedAttackSpeed.setModifierCategories(ModifierCategories)
	_modifiedFanAngle.setModifierCategories(ModifierCategories)
	_modifiedEmitCount.setModifierCategories(ModifierCategories)

func attackSpeedWasUpdated(_oldValue:float, newValue:float):
	_emitEverySecondsModified = 1.0 / newValue

func _process(delta):
	_emit_timer -= delta
	while _emit_timer <= 0:
		emit_fan(abs(_emit_timer))
		_emit_timer += _emitEverySecondsModified

func emit_fan(passedTime : float):
	if _directionProvider == null or _bulletPrototype == null:
		return
	var angle_offset = 0
	var angle_increment = 0
	var emitCount = get_totalEmitCount()
	if emitCount > 1:
		var fanAngle = get_totalEmitFanAngle()
		angle_offset = deg_to_rad(-fanAngle * 0.5)
		angle_increment = deg_to_rad(fanAngle * 0.5) * 2.0 / float(emitCount - 1)

	for bullet_count in range(emitCount):
		var randomAngle = deg_to_rad(randf_range(-EmissionFanRandomRange, EmissionFanRandomRange))
		emit_with_passed_time(passedTime, angle_offset + randomAngle)
		angle_offset += angle_increment
		# stagger the emission by one frame, for performance reasons
		await get_tree().process_frame


func emit_with_passed_time(passedTime : float, directionAngleOffset : float) -> void:
	if _directionProvider == null or _bulletPrototype == null:
		return
	var bullet : GameObject = Global.duplicate_gameObject_node(_bulletPrototype)
	bullet.set_sourceGameObject(_gameObject)
	Global.attach_toWorld(bullet, false)

	var emitDir = Vector2.RIGHT.rotated(EmissionAngleOffsetToAimDirection)
	var dirComponent = bullet.getChildNodeWithMethod("set_targetDirection")
	if dirComponent:
		emitDir = _directionProvider.get_aimDirection().rotated(directionAngleOffset + EmissionAngleOffsetToAimDirection)
		dirComponent.set_targetDirection(emitDir)

	var posComponent = bullet.getChildNodeWithMethod("set_worldPosition")
	if posComponent:
		posComponent.set_worldPosition(
			get_gameobjectWorldPosition() + EmissionPosOffset + emitDir * EmitRadius)

	var motionComponent = bullet.getChildNodeWithMethod("calculateMotion")
	if motionComponent:
		var motion = motionComponent.calculateMotion(passedTime)
		motionComponent.global_position += motion


func get_cooldown_factor() -> float:
	return 1.0 - _emit_timer / _emitEverySecondsModified
func get_totalEmitFanAngle() -> float:
	var additionalFanAngle = (_modifiedFanAngle.Value() - EmissionFanAngle) * FanAngleScalingFactor
	return EmissionFanAngle + additionalFanAngle
func get_totalEmitCount() -> int:
	_emit_overflow += _modifiedEmitCount.Value()
	var emit_count = floor(_emit_overflow)
	_emit_overflow -= emit_count
	return emit_count
