extends GameObjectComponent

@export_group("Emission State")
@export var Emitting : bool = false

@export_group("Emission Parameters")
@export var EmitSpeed : float = 1.0
@export var BulletCountPerEmit : float = 1
@export var EmitRadius : float = 0
@export var EmissionFanAngle : float = 0
@export var EmissionFanRandomRange : float = 0
@export var EmissionPosOffset : Vector2
@export var EmitDelay : float = 0.3
## if true, bullets will emitted consecutively over EmitSpeed
@export var BulletChaining : bool = false
@export var ModifierCategories : Array[String] = ["Physical"]
@export var DamageCategories : Array[String] = ["DefaultWeapon"]
@export var InheritVelocityFactor : float = 0.0

@export_group("Sound Settings")
@export var AudioSource : Node

@export_group("Scene References")
@export var BaseBullet : PackedScene
@export var BulletGroups : Array[StringName]

@export_group("scaling modifiers")
@export var FanAngleScalingFactor : float = 0.4

@export_group("Internal State")
@export var _weapon_index : int = -1

signal BulletEmitted(bullet:GameObject)
signal AttackTriggered(attack_index:int)

var _parentVelocityProvider : Node
var _directionProvider : Node
var _bulletPrototype : GameObject
var _audio_default_pitch : float

var _emit_overflow : float
var _modifiedSpeed
var _modifiedFanAngle : ModifiedFloatValue
var _modifiedEmitCount : ModifiedFloatValue

# only use for the statistics. not very optimized...
func get_modified_values() -> Array:
	var allMods : Array = [
		_modifiedSpeed,
		_modifiedFanAngle,
		_modifiedEmitCount
	]
	if _bulletPrototype != null:
		var bulletModNodes : Array = []
		_bulletPrototype.getChildNodesWithMethod("get_modified_values", bulletModNodes)
		for bulletModNode in bulletModNodes:
			allMods.append_array(bulletModNode.get_modified_values())
	return allMods
func is_character_base_node() -> bool : return true

var _emitTimer : float

func _ready():
	initGameObjectComponent()
	_directionProvider = _gameObject.getChildNodeWithMethod("get_aimDirection")
	_parentVelocityProvider = _gameObject.getChildNodeWithMethod("get_velocity")
	_bulletPrototype = BaseBullet.instantiate()
	_bulletPrototype.setInheritModifierFrom(_gameObject)
	var weapon_index_setter = _bulletPrototype.getChildNodeWithMethod("set_weapon_index")
	if weapon_index_setter != null: weapon_index_setter.set_weapon_index(_weapon_index)

	var bullet_modifier_nodes : Array = []
	_bulletPrototype.getChildNodesWithMethod("initialize_modifiers", bullet_modifier_nodes)
	for n in bullet_modifier_nodes: n.initialize_modifiers(self)

	for group in BulletGroups:
		_bulletPrototype.add_to_group(group)

	_modifiedSpeed = createModifiedFloatValue(EmitSpeed, "AttackSpeed")
	_modifiedFanAngle = createModifiedFloatValue(EmissionFanAngle, "Area")
	_modifiedEmitCount = createModifiedFloatValue(BulletCountPerEmit, "EmitCount")
	applyModifierCategories()
	_emitTimer = 1.0 / get_totalAttackSpeed()
	if AudioSource != null:
		_audio_default_pitch = AudioSource.pitch_scale


func _exit_tree():
	if _bulletPrototype != null:
		_bulletPrototype.queue_free()
		_bulletPrototype = null

func applyModifierCategories():
	_modifiedSpeed.setModifierCategories(ModifierCategories)
	_modifiedFanAngle.setModifierCategories(ModifierCategories)
	_modifiedEmitCount.setModifierCategories(ModifierCategories)

func transformCategories(onlyWithDamageCategory:String, addModifierCategories:Array[String], removeModifierCategories:Array[String], addDamageCategories:Array[String], removeDamageCategories:Array[String]):
	if not DamageCategories.has(onlyWithDamageCategory):
		return

	var bulletTransformComps : Array = []
	_bulletPrototype.getChildNodesWithMethod("transformCategories", bulletTransformComps)
	for bulletTransformComp in bulletTransformComps:
		bulletTransformComp.transformCategories(onlyWithDamageCategory, addModifierCategories, removeModifierCategories, addDamageCategories, removeDamageCategories)

	for addMod in addModifierCategories:
		if not ModifierCategories.has(addMod):
			ModifierCategories.append(addMod)
	for remMod in removeModifierCategories:
		ModifierCategories.erase(remMod)
	for addCat in addDamageCategories:
		if not DamageCategories.has(addCat):
			DamageCategories.append(addCat)
	for remMod in removeDamageCategories:
		DamageCategories.erase(remMod)
	applyModifierCategories()

func set_emitting(emit:bool, reset_timer:bool = false) -> void:
	Emitting = emit
	if reset_timer:
		_emitTimer = 0

func _process(delta):
	if Emitting:
		_emitTimer -= delta
	else:
		_emitTimer -= delta
		if _emitTimer < 0: _emitTimer = 0
		return
	while _emitTimer <= 0:
		emit_signal("AttackTriggered", 0)
		if BulletChaining:
			emit_chain()
		else:
			emit_fan()
		_emitTimer += 1.0 / get_totalAttackSpeed()


func get_attackSpeedFactor() -> float:
	return get_totalAttackSpeed() / EmitSpeed
func get_totalAttackSpeed() -> float: return _modifiedSpeed.Value()
func get_totalEmitFanAngle() -> float:
	var additionalFanAngle = (_modifiedFanAngle.Value() - EmissionFanAngle) * FanAngleScalingFactor
	return EmissionFanAngle + additionalFanAngle

func get_totalEmitCount() -> int:
	_emit_overflow += _modifiedEmitCount.Value()
	var emit_count = floor(_emit_overflow)
	_emit_overflow -= emit_count
	return emit_count


func emit_immediate(crit_guarantee:bool = false) -> void:
	play_sound()
	if BulletChaining:
		emit_chain(crit_guarantee)
	else:
		emit_fan(crit_guarantee)

func emit_chain(_crit_guarantee:bool = false):
	if _directionProvider == null or _bulletPrototype == null:
		return
	# the _emitTimer only contains the time offset for the first
	# bullet of the chain and only at this current point in time!
	var emitTimeOffset = abs(_emitTimer)
	var chain_time = 0
	var emitCount = get_totalEmitCount()
	if emitCount > 1:
		chain_time = 1.0 / get_totalAttackSpeed() / emitCount

	# the first delay is for the animation
	await get_tree().create_timer(EmitDelay / get_attackSpeedFactor()).timeout

	for bullet_index in range(emitCount):
		var randomAngle = deg_to_rad(randf_range(-EmissionFanRandomRange, EmissionFanRandomRange))
		emit_bullet(emitTimeOffset, randomAngle)
		if chain_time > 0 and bullet_index < emitCount:
			if emitTimeOffset < chain_time:
				await get_tree().create_timer(chain_time - emitTimeOffset).timeout
				emitTimeOffset = 0
			else:
				emitTimeOffset -= chain_time


func emit_fan(_crit_guarantee:bool = false):
	if _directionProvider == null or _bulletPrototype == null:
		return
	var emitTimeOffset = abs(_emitTimer)
	var angle_offset = 0
	var angle_increment = 0
	var emitCount = get_totalEmitCount()
	if emitCount > 1:
		var fanAngle = get_totalEmitFanAngle()
		angle_offset = deg_to_rad(-fanAngle * 0.5)
		angle_increment = deg_to_rad(fanAngle * 0.5) * 2.0 / float(emitCount - 1)

	await get_tree().create_timer(EmitDelay / get_attackSpeedFactor()).timeout

	for bullet_count in range(emitCount):
		var randomAngle = deg_to_rad(randf_range(-EmissionFanRandomRange, EmissionFanRandomRange))
		emit_bullet(emitTimeOffset, angle_offset + randomAngle)
		angle_offset += angle_increment
	# TODO: implement crit guarantee on bullets!


func emit_bullet(passedTime : float, directionAngleOffset : float) -> void:
	if _gameObject == null or _gameObject.is_queued_for_deletion():
		return

	play_sound()
	var bullet : GameObject = Global.duplicate_gameObject_node(_bulletPrototype)
	bullet.set_sourceGameObject(_gameObject)
	Global.attach_toWorld(bullet, false)

	var emitDir = Vector2.RIGHT
	var dirComponent = bullet.getChildNodeWithMethod("set_targetDirection")
	if dirComponent:
		emitDir = _directionProvider.get_aimDirection().rotated(directionAngleOffset)
		dirComponent.set_targetDirection(emitDir)

	var additionalMotion = Vector2.ZERO
	var motionComponent = bullet.getChildNodeWithMethod("calculateMotion")
	if motionComponent:
		if InheritVelocityFactor > 0.0 and motionComponent.has_method("set_velocity_offset"):
			motionComponent.set_velocity_offset(_parentVelocityProvider.get_velocity() * InheritVelocityFactor)
		additionalMotion = motionComponent.calculateMotion(passedTime)

	var posComponent = bullet.getChildNodeWithMethod("set_worldPosition")
	if posComponent:
		posComponent.set_worldPosition(
			get_gameobjectWorldPosition() + EmissionPosOffset + emitDir * EmitRadius + additionalMotion)

	emit_signal("BulletEmitted", bullet)
	if Global.World:
		Global.World.emit_signal("BulletSpawnedEvent", bullet, get_parent())


func get_totalCritDamage() -> int:
	var totalCritDamageProvider = _bulletPrototype.getChildNodeWithMethod("get_totalCritDamage")
	if totalCritDamageProvider:
		return int(ceil(totalCritDamageProvider.get_totalCritDamage() - 0.001))
	return 0

func play_sound():
	if AudioSource != null:
		AudioSource.pitch_scale = _audio_default_pitch + randf_range(-0.1, 0.1)
		if AudioSource.has_method("play_variation"):
			AudioSource.play_variation()
		else:
			AudioSource.play()
