extends GameObjectComponent

@export_group("Emission State")
@export var Emitting : bool = false

@export_group("Emission Parameters")
@export var EmitSpeed : float = 1.0
@export var BulletCountPerEmit : int = 1
@export var EmissionPosOffset : Vector2
@export var RandomTargetOffset : float
@export var EmitDelay : float = 0.3
@export var ModifierCategories : Array[String] = ["Physical"]
@export var DamageCategories : Array[String] = ["DefaultWeapon"]
@export var InheritVelocityFactor : float = 0.0
@export var TargetPlayer : bool = false
@export var AttackAnimationIndex : int = 0

@export_group("Sound Settings")
@export var AudioSource : Node

@export_group("Scene References")
@export var BaseBullet : PackedScene
@export var BulletGroups : Array[StringName]

@export_group("Internal State")
@export var _weapon_index : int = -1

signal BulletEmitted(bullet:GameObject)
signal AttackTriggered(attack_index:int)

var _parentVelocityProvider : Node
var _bulletPrototype : GameObject
var _audio_default_pitch : float
var _throwTarget : Node

var _modifiedSpeed : ModifiedFloatValue
var _modifiedEmitCount : ModifiedFloatValue

# only use for the statistics. not very optimized...
func get_modified_values() -> Array:
	var allMods : Array = [
		_modifiedSpeed,
		_modifiedEmitCount
	]
	if _bulletPrototype != null:
		var bulletModNodes : Array = []
		_bulletPrototype.getChildNodesWithMethod("get_modified_values", bulletModNodes)
		for bulletModNode in bulletModNodes:
			allMods.append_array(bulletModNode.get_modified_values())
	return allMods
func is_character_base_node() -> bool : return true

var _emit_overflow : float
var _emitTimer : float

func _ready():
	initGameObjectComponent()
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
	_modifiedSpeed.ValueUpdated.connect(attackSpeedWasChanged)
	_modifiedEmitCount = createModifiedFloatValue(BulletCountPerEmit, "EmitCount")
	applyModifierCategories()
	_emitTimer = 1.0 / get_totalAttackSpeed()
	if AudioSource != null:
		_audio_default_pitch = AudioSource.pitch_scale

	if TargetPlayer:
		set_throw_target(Global.World.Player)


func _exit_tree():
	if _bulletPrototype != null:
		_bulletPrototype.queue_free()
		_bulletPrototype = null

func applyModifierCategories():
	_modifiedSpeed.setModifierCategories(ModifierCategories)
	_modifiedEmitCount.setModifierCategories(ModifierCategories)

func attackSpeedWasChanged(oldValue:float, newValue:float):
	if newValue == 0:
		# this is something like a stun. so the emit timer has
		# to be very large (so it doesn't trigger). but we also
		# want to preserve the current value (so that repeated
		# stunning doesn't result in no attacks at all)
		_emitTimer = (_emitTimer + 100) * 100000
	elif oldValue == 0:
		# coming out of a stun, try to reconstruct the emit timer
		_emitTimer = (_emitTimer / 100000) - 100
		# safeguard against strange values:
		if _emitTimer < 0: _emitTimer = 0
		elif _emitTimer > 1.0 / newValue: _emitTimer = 1.0 / newValue
	else:
		# we can apply the proportional change to the
		# currently running time (but: attackSpeed is
		# inverse of time!)
		_emitTimer *= oldValue / newValue

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


func set_throw_target(target:Node):
	_throwTarget = target


func _process(delta):
	if Emitting:
		_emitTimer -= delta
	else:
		_emitTimer -= delta
		if _emitTimer < 0: _emitTimer = 0
		return
	while _emitTimer <= 0:
		AttackTriggered.emit(AttackAnimationIndex)
		emit_all_bullets()
		_emitTimer += 1.0 / get_totalAttackSpeed()


func get_attackSpeedFactor() -> float:
	return get_totalAttackSpeed() / EmitSpeed
func get_totalAttackSpeed() -> float: return _modifiedSpeed.Value()
func get_totalEmitCount() -> int:
	_emit_overflow += _modifiedEmitCount.Value()
	var emit_count = floor(_emit_overflow)
	_emit_overflow -= emit_count
	return emit_count


func emit_immediate(crit_guarantee:bool = false) -> void:
	play_sound()
	emit_all_bullets(crit_guarantee)

func emit_all_bullets(_crit_guarantee:bool = false):
	if _bulletPrototype == null:
		return
	var emitTimeOffset = abs(_emitTimer)
	var emitCount = get_totalEmitCount()
	# delay for the animation start
	await get_tree().create_timer(EmitDelay / get_attackSpeedFactor()).timeout
	if _modifiedSpeed.Value() == 0:
		# we were probably stunned while throwing...
		# cancel the throw! (otherwise the bullet will be stunned as well)
		return
	for bullet_index in range(emitCount):
		emit_bullet(emitTimeOffset)


func emit_bullet(passedTime : float) -> void:
	if _gameObject == null or _gameObject.is_queued_for_deletion():
		return
	if not is_instance_valid(_throwTarget) or _throwTarget == null or _throwTarget.is_queued_for_deletion():
		return

	play_sound()
	var bullet : GameObject = Global.duplicate_gameObject_node(_bulletPrototype)
	bullet.set_sourceGameObject(_gameObject)
	Global.attach_toWorld(bullet, false)

	var additionalMotion = Vector2.ZERO
	var motionComponent = bullet.getChildNodeWithMethod("calculateMotion")
	if motionComponent:
		if InheritVelocityFactor > 0.0 and motionComponent.has_method("set_velocity_offset"):
			motionComponent.set_velocity_offset(_parentVelocityProvider.get_velocity() * InheritVelocityFactor)
		additionalMotion = motionComponent.calculateMotion(passedTime)

	var ballisticComponent = bullet.getChildNodeWithMethod("start_ballistic_motion")
	var targetPosComponent = _throwTarget.getChildNodeWithMethod("get_worldPosition")
	if ballisticComponent != null and targetPosComponent != null:
		ballisticComponent.start_ballistic_motion(
			get_gameobjectWorldPosition() + EmissionPosOffset + additionalMotion,
			targetPosComponent.get_worldPosition() +
			Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * RandomTargetOffset)

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
