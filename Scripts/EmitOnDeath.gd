extends GameObjectComponent2D

@export_enum("OnKilled", "OnEndOfLife", "Touched") var OnEvent : int = 0
@export var EmitRadius : float = 0
@export var BulletCountPerEmit : int = 1
@export var EmitRotation : float = 0
@export var EmissionFanAngle : float = 0
@export var EmissionFanRandomRange : float = 0
@export var EmissionPosOffset : Vector2
@export var ModifierCategories : Array[String] = ["Projectile"]
@export var InheritModifiersFromPlayer : bool

@export_group("Scaling Modifiers")
@export var FanAngleScalingFactor : float = 0.4

@export_group("Scene References")
@export var EmitScene : PackedScene
@export var BulletGroups : Array[StringName]

@export_group("Internal State")
@export var _weapon_index : int

var _bulletPrototype : GameObject

var _modifiedFanAngle
var _modifiedEmitCount
var _emit_overflow : float

func _ready() -> void:
	initGameObjectComponent()
	if _gameObject != null:
		_bulletPrototype = EmitScene.instantiate()
		_modifiedFanAngle = createModifiedFloatValue(EmissionFanAngle, "Area")
		_modifiedEmitCount = createModifiedFloatValue(BulletCountPerEmit, "EmitCount")
		if InheritModifiersFromPlayer and is_instance_valid(Global.World.Player):
			_bulletPrototype.setInheritModifierFrom(Global.World.Player)
		else:
			_bulletPrototype.setInheritModifierFrom(_gameObject)
		applyModifierCategories()

		var bullet_modifier_nodes : Array = []
		_bulletPrototype.getChildNodesWithMethod("initialize_modifiers", bullet_modifier_nodes)
		for n in bullet_modifier_nodes: n.initialize_modifiers(self)
		for group in BulletGroups: _bulletPrototype.add_to_group(group)

		var weapon_index_getter = _gameObject.getChildNodeWithMethod("get_weapon_index")
		if weapon_index_getter: _weapon_index = weapon_index_getter.get_weapon_index()

		var weapon_index_setter = _bulletPrototype.getChildNodeWithMethod("set_weapon_index")
		if weapon_index_setter != null: weapon_index_setter.set_weapon_index(_weapon_index)

		if OnEvent == 0:
			_gameObject.connectToSignal("Killed", _on_killed)
		elif OnEvent == 1:
			_gameObject.connectToSignal("OnEndOfLife", _on_killed.bind(null))
		elif OnEvent == 2:
			_gameObject.connectToSignal("Touched", _on_killed.bind(null))


func _on_killed(killedBy : Node):
	global_position = get_gameobjectWorldPosition()
	var total_fan_angle = get_totalEmitFanAngle()
	var total_emit_count = get_totalEmitCount()
	_bulletPrototype.set_sourceGameObject(_gameObject)
	reparent(Global.World)
	emit_fan(total_emit_count, total_fan_angle)


func emit_fan(totalEmitCount, totalEmitFanAngle):
	if _bulletPrototype == null: return
	var angle_offset = 0
	var angle_increment = 0
	if totalEmitCount > 1:
		angle_offset = deg_to_rad(-totalEmitFanAngle * 0.5)
		angle_increment = deg_to_rad(totalEmitFanAngle * 0.5) * 2.0 / float(totalEmitCount - 1)

	for bullet_index in range(totalEmitCount):
		var randomAngle = deg_to_rad(randf_range(-EmissionFanRandomRange, EmissionFanRandomRange))
		emit_single_bullet(angle_offset + randomAngle)
		angle_offset += angle_increment
		# stagger the emission by one frame, for performance reasons
		await get_tree().process_frame
	queue_free()


func emit_single_bullet(directionAngleOffset:float):
	if _bulletPrototype == null: return
	var bullet : GameObject = Global.duplicate_gameObject_node(_bulletPrototype)
	Global.attach_toWorld(bullet, false)

	var emitDir = Vector2.UP.rotated(deg_to_rad(EmitRotation) + directionAngleOffset)
	var dirComponent = bullet.getChildNodeWithMethod("set_targetDirection")
	if dirComponent:
		dirComponent.set_targetDirection(emitDir)

	var posComponent = bullet.getChildNodeWithMethod("set_worldPosition")
	if posComponent:
		posComponent.set_worldPosition(
			global_position + EmissionPosOffset + emitDir * EmitRadius)


func applyModifierCategories():
	_modifiedFanAngle.setModifierCategories(ModifierCategories)
	_modifiedEmitCount.setModifierCategories(ModifierCategories)


func get_totalEmitFanAngle() -> float:
	var additionalFanAngle = (_modifiedFanAngle.Value() - EmissionFanAngle) * FanAngleScalingFactor
	return EmissionFanAngle + additionalFanAngle

func get_totalEmitCount() -> int:
	var emit_count = _modifiedEmitCount.Value()
	var emit_rest = emit_count - floor(emit_count)
	if randf() < emit_rest:
		return ceil(emit_count)
	return floor(emit_count)
