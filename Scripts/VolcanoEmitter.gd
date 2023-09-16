extends GameObjectComponent2D

enum SpreadType {
	RANDOM,
	PER_PHASE,
	PER_ATTACK
}

@export var EmitSound : AudioFXResource

@export_group("Emission Parameters")
@export var Projectile : PackedScene
@export var MinRange : float = 80
@export var MaxRange : float = 200
@export var AttacksPerPhase : int = 4
@export var ProjectilesPerAttack : float = 3
@export var Spread : SpreadType = SpreadType.RANDOM
@export var EmitSpeed : float = -1.0
@export var MinPhaseInterval : float = 2.5
@export var MaxPhaseInterval : float = 4.0
@export var EmitPhaseDelay : float = 0.25
@export var EmissionOffset : Vector2 = Vector2.ZERO

@export_group("Initialization Parameters")
@export var TriggerAttackAnimation : bool = true
@export var AttachToPositionProvider : bool = false
@export var ModifierCategories : Array[String] = ["Fire"]
@export var DamageCategories : Array[String] = ["MeteorStrike"]
@export var BulletGroups : Array[StringName]

@export_group("Internal State")
@export var _weapon_index : int

signal AttackTriggered(attack_index:int)
var _emitting:bool = false
var _initialized:bool = false
var _emitEverySeconds:float
var _velocityProvider:Node

var _emit_overflow : float
var _emitTimer : Timer
var _bulletPrototype : GameObject
var _modifiedAttackSpeed
var _modifiedEmitCount
var _modifiedRange

# only use for the statistics. not very optimized...
func get_modified_values() -> Array:
	var allMods : Array = [
		_modifiedAttackSpeed,
		_modifiedRange,
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
	if _gameObject != null:
		var parent = get_parent()
		if parent and parent.has_method("get_weapon_index"):
			_weapon_index = parent.get_weapon_index()
		if AttachToPositionProvider:
			var posProvider = _gameObject.getChildNodeWithMethod("get_worldPosition")
			if posProvider != null:
				await get_tree().process_frame
				reparent(posProvider)
			position = EmissionOffset
		_velocityProvider = _gameObject.getChildNodeWithMethod("get_velocity")
		initialize()
		emit_coroutine()

func initialize():
	if not _initialized:
		_initialized = true
		_emitTimer = Timer.new()
		add_child(_emitTimer)
		_bulletPrototype = Projectile.instantiate()
		_bulletPrototype.setInheritModifierFrom(_gameObject)
		for group in BulletGroups:
			_bulletPrototype.add_to_group(group)
		var weapon_index_setter = _bulletPrototype.getChildNodeWithMethod("set_weapon_index")
		if weapon_index_setter != null: weapon_index_setter.set_weapon_index(_weapon_index)

		var bullet_modifier_nodes : Array = []
		_bulletPrototype.getChildNodesWithMethod("initialize_modifiers", bullet_modifier_nodes)
		for n in bullet_modifier_nodes: n.initialize_modifiers(self)

		_modifiedAttackSpeed = createModifiedFloatValue(EmitSpeed, "AttackSpeed")
		_modifiedAttackSpeed.connect("ValueUpdated", attackSpeedWasUpdated)
		_emitEverySeconds = 1.0 / _modifiedAttackSpeed.Value()
		_modifiedEmitCount = createModifiedFloatValue(ProjectilesPerAttack, "EmitCount")
		_modifiedRange = ModifiedFloatValue.new()
		_modifiedRange.initAsMultiplicativeOnly("Range", _gameObject, Callable())
		applyModifierCategories()


func applyModifierCategories():
	_modifiedAttackSpeed.setModifierCategories(ModifierCategories)
	_modifiedEmitCount.setModifierCategories(ModifierCategories)
	_modifiedRange.setModifierCategories(ModifierCategories)


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

func _exit_tree():
	_allModifiedValues.clear()
	_modifiedAttackSpeed = null
	_modifiedEmitCount = null
	_modifiedRange = null
	_emitting = false
	if _bulletPrototype != null:
		_bulletPrototype.queue_free()
		_bulletPrototype = null


func emit_coroutine():
	if _emitting: return
	_emitting = true
	while _emitting:
		var emit_rotation_offset = randf_range(-PI, PI)
		for i in AttacksPerPhase:
			if TriggerAttackAnimation:
				AttackTriggered.emit(0)
			if EmitPhaseDelay > 0: await get_tree().create_timer(EmitPhaseDelay, false).timeout
			if EmitSound != null: FxAudioPlayer.play_sound_2D(EmitSound, global_position, false, false, 0)
			_emit_overflow += _modifiedEmitCount.Value()
			var emitTarget = floor(_emit_overflow)
			_emit_overflow -= emitTarget
			match(Spread):
				SpreadType.RANDOM:
					for j in emitTarget: fire_projectile(0, 1, 0)
				SpreadType.PER_PHASE:
					for j in emitTarget: fire_projectile(float(i), float(AttacksPerPhase), emit_rotation_offset)
				SpreadType.PER_ATTACK:
					for j in emitTarget: fire_projectile(float(j), float(emitTarget), emit_rotation_offset)
			if EmitPhaseDelay > 0: await get_tree().create_timer(EmitPhaseDelay, false).timeout
		_emitTimer.start(get_emit_interval()); await _emitTimer.timeout


func fire_projectile(current_projectile: float, max_projectiles: float, emit_rotation_offset: float):
	var rotation_step : float = 1.0 / max_projectiles
	var random_direction : float = randf_range(rotation_step * current_projectile, rotation_step * (current_projectile + 1.0)) * 2 * PI - PI
	var targetDist : float = get_random_range()
	var targetDir : Vector2 = (Vector2.ONE * targetDist).rotated(random_direction + emit_rotation_offset)

	var projectile : GameObject = Global.duplicate_gameObject_node(_bulletPrototype)
	Global.attach_toWorld(projectile, false)
	if projectile.has_method("set_sourceGameObject"):
		projectile.set_sourceGameObject(_gameObject)
	elif projectile.has_method("set_externalSource"):
		projectile.set_externalSource(_gameObject)

	var travelDuration : float = -1
	if _velocityProvider != null:
		var projectileSpeedProvider : Node = projectile.getChildNodeWithMethod("get_speed")
		if projectileSpeedProvider != null:
			travelDuration = targetDist / projectileSpeedProvider.get_speed()
			var offsetFromOurVelocity : Vector2 = travelDuration * _velocityProvider.get_velocity()
			targetDir += offsetFromOurVelocity
	var p = projectile.getChildNodeWithMethod("start_ballistic_motion")
	var pos = global_position
	p.start_ballistic_motion(pos, pos + targetDir, travelDuration)


func get_emit_interval() -> float:
	if EmitSpeed > 0.0:
		return 1.0 / _modifiedAttackSpeed.Value()
	return randf_range(MinPhaseInterval, MaxPhaseInterval)

func attackSpeedWasUpdated(_oldValue:float, newValue:float):
	_emitEverySeconds = 1.0 / newValue

func get_cooldown_factor() -> float:
	return 1.0 - _emitTimer.time_left / _emitEverySeconds

func get_random_range() -> float:
	return randf_range(MinRange * _modifiedRange.Value(), MaxRange * _modifiedRange.Value())
