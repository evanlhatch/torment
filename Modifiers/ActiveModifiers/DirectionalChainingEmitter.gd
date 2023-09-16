extends GameObjectComponent

@export_group("Emission Parameters")
@export var EmitEverySeconds : float = 1
@export var EmitTimeOffset : float = 0
@export var EmitRadius : float = 0
@export var BulletCountPerEmit : float = 2
@export var BulletCountModifier : float = 0.5
@export var EmitRotation : float = 90
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

var _emit_timer : float
var _modifiedAttackSpeed
var _modifiedEmitCount
var _modifiedArea

# only use for the statistics. not very optimized...
func get_modified_values() -> Array:
	var allMods : Array = [
		_modifiedAttackSpeed,
		_modifiedArea,
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
	else:
		_directionProvider = _gameObject.getChildNodeWithMethod("get_aimDirection")
		_bulletPrototype = EmitScene.instantiate()
		_bulletPrototype.setInheritModifierFrom(_gameObject)
		var weapon_index_setter = _bulletPrototype.getChildNodeWithMethod("set_weapon_index")
		if weapon_index_setter != null: weapon_index_setter.set_weapon_index(_weapon_index)

		var bullet_modifier_nodes : Array = []
		_bulletPrototype.getChildNodesWithMethod("initialize_modifiers", bullet_modifier_nodes)
		for n in bullet_modifier_nodes: n.initialize_modifiers(self)
			
		_modifiedAttackSpeed = createModifiedFloatValue(1.0 / EmitEverySeconds, "AttackSpeed")
		_modifiedEmitCount = createModifiedFloatValue(BulletCountPerEmit, "EmitCount")
		_modifiedArea = createModifiedFloatValue(EmissionFanRandomRange, "Area")
		_modifiedAttackSpeed.connect("ValueUpdated", attackSpeedWasUpdated)
		_modifiedEmitCount.connect("ValueUpdated", bulletCountWasUpdated)
		applyModifierCategories()
		attackSpeedWasUpdated(_modifiedAttackSpeed.Value(), _modifiedAttackSpeed.Value())
		bulletCountWasUpdated(_modifiedEmitCount.Value(), _modifiedEmitCount.Value())
		_emit_timer = EmitEverySeconds - EmitTimeOffset * EmitEverySeconds
		for group in BulletGroups:
			_bulletPrototype.add_to_group(group)


func _exit_tree():
	_allModifiedValues.clear()
	_modifiedEmitCount = null
	_modifiedArea = null
	_modifiedAttackSpeed = null
	if _bulletPrototype != null:
		_bulletPrototype.queue_free()
		_bulletPrototype = null

func applyModifierCategories():
	_modifiedAttackSpeed.setModifierCategories(ModifierCategories)
	_modifiedEmitCount.setModifierCategories(ModifierCategories)
	_modifiedArea.setModifierCategories(ModifierCategories)

func attackSpeedWasUpdated(_oldValue:float, newValue:float):
	_emit_timer *= ((1.0 / newValue) / get_totalEmitCount()) / EmitEverySeconds
	EmitEverySeconds = (1.0 / newValue) / get_totalEmitCount()

func bulletCountWasUpdated(_oldValue:float, newValue:float):
	_emit_timer *= ((1.0 / _modifiedAttackSpeed.Value()) / get_totalEmitCount()) / EmitEverySeconds
	EmitEverySeconds = (1.0 / _modifiedAttackSpeed.Value()) / get_totalEmitCount()

func _process(delta):
	_emit_timer -= delta
	while _emit_timer <= 0:
		emit_with_passed_time(_emit_timer)
		_emit_timer += EmitEverySeconds
	
func emit_with_passed_time(passedTime : float) -> void:
	if _directionProvider == null or _bulletPrototype == null:
		return
	var bullet : GameObject = Global.duplicate_gameObject_node(_bulletPrototype)
	bullet.set_sourceGameObject(_gameObject)
	Global.attach_toWorld(bullet, false)
	
	var randomAngle = deg_to_rad(randf_range(-get_totalRandomAngle(), get_totalRandomAngle()))
	var emitDir = Vector2.UP.rotated(randomAngle + deg_to_rad(EmitRotation));
	var dirComponent = bullet.getChildNodeWithMethod("set_targetDirection")
	if dirComponent:
		dirComponent.set_targetDirection(emitDir)
	
	var posComponent = bullet.getChildNodeWithMethod("set_worldPosition")
	if posComponent:
		posComponent.set_worldPosition(
			get_gameobjectWorldPosition() + EmissionPosOffset + emitDir)
	
	var motionComponent = bullet.getChildNodeWithMethod("calculateMotion")
	if motionComponent:
		var motion = motionComponent.calculateMotion(passedTime)
		motionComponent.global_position += motion


func get_cooldown_factor() -> float:
	return 1.0 - _emit_timer / (EmitEverySeconds / get_totalEmitCount())
func get_totalEmitCount() -> float: return _modifiedEmitCount.Value() * BulletCountModifier
func get_totalRandomAngle() -> float: return _modifiedArea.Value()
