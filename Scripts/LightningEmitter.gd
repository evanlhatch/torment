extends GameObjectComponent

@export_group("Emission State")
@export var Emitting : bool = false
@export var OnlyAllowManualEmission : bool = false

@export_group("Emission Parameters")
@export var EmitSpeed : float = 1.0
@export var EmitCount : int = 1
@export var LightningCountPerEmit : int = 3
@export var EmitRadius : float = 0
@export var EmissionPosOffset : Vector2
@export var EmitRangeInitial : float = 180
@export var EmitRangeChain : float = 120
@export var EmitDelay : float = 0.25
@export var ChainDelay : float = 0.2
@export var HitAngleInitial : float = 20.0
@export var HitAngleChain : float = 90.0
@export var HitLocatorPools : Array[String] = ["Enemies", "Breakables"]
@export var ModifierCategories : Array[String] = ["Projectile"]
@export var DamageCategories : Array[String] = ["Lightning"]
@export var EmitPositionNode : Node2D

@export_group("Damage Patameters")
@export var BaseDamage : int = 80
@export var DamageMultPerHit : float = 0.7
@export var Blockable : bool = true
@export var CritChance : float
@export var CritBonus : float

@export_group("Scene References")
@export var LightningArcScene : PackedScene

@export_group("Internal State")
@export var _weapon_index : int = -1
@export var UseModifier : bool = true
@export var EmitAttackTriggered : bool = true


signal AttackTriggered(attack_index:int)
signal DamageApplied(categories:Array[String], damageAmount:float, applyReturn:Array, targetNode:GameObject, critical:bool)

var _emitTimer : float
var _directionProvider : Node
var _emit_overflow : float
var _modifiedSpeed
var _modifiedEmitCount
var _modifiedDamage
var _modifiedCriticalHitChance
var _modifiedCriticalHitBonus
var _modifiedMaxHits
var _audio_default_pitch : float
var _aim_direction : Vector2 = Vector2.RIGHT

var _delayTimer : Timer
@onready var _multistrikeAngle : float = deg_to_rad(0.0)

# only use for the statistics. not very optimized...
func get_modified_values() -> Array:
	return [
		_modifiedDamage,
		#_modifiedRange,
		#_modifiedArea,
		_modifiedSpeed,
		_modifiedCriticalHitChance,
		_modifiedCriticalHitBonus,
		_modifiedMaxHits,
		_modifiedEmitCount
	]
func is_character_base_node() -> bool : return UseModifier


func get_totalCritChance() -> float:
	if UseModifier: return _modifiedCriticalHitChance.Value()
	return CritChance

func get_totalCritBonus() -> float:
	if UseModifier: return _modifiedCriticalHitBonus.Value()
	return CritBonus

func get_totalCritDamage() -> int:
		var damage = get_totalDamage()
		if UseModifier: return damage + get_totalCritBonus() * damage
		return damage + CritBonus * damage

func get_totalDamage() -> int:
	if UseModifier: return _modifiedDamage.Value()
	return BaseDamage

func get_totalHitTargets() -> int:
	if UseModifier: return _modifiedMaxHits.Value()
	return LightningCountPerEmit

func get_totalEmitCount() -> int:
	if not UseModifier: return EmitCount
	_emit_overflow += _modifiedEmitCount.Value()
	var emit_count = floor(_emit_overflow)
	_emit_overflow -= emit_count
	return emit_count

func get_totalAttackSpeed() -> float:
	if UseModifier: return _modifiedSpeed.Value()
	return EmitSpeed

func get_attackSpeedFactor() -> float:
	return get_totalAttackSpeed() / EmitSpeed

func _ready():
	initGameObjectComponent()
	if not _gameObject:
		process_mode = PROCESS_MODE_DISABLED
		return
	if not OnlyAllowManualEmission:
		process_mode = PROCESS_MODE_INHERIT
	else:
		process_mode = PROCESS_MODE_DISABLED
	_directionProvider = _gameObject.getChildNodeWithMethod("get_aimDirection")
	_modifiedSpeed = createModifiedFloatValue(EmitSpeed, "AttackSpeed")
	_modifiedEmitCount = createModifiedFloatValue(EmitCount, "EmitCount")
	_modifiedDamage = createModifiedIntValue(BaseDamage, "Damage")
	_modifiedCriticalHitChance = createModifiedFloatValue(CritChance, "CritChance")
	_modifiedCriticalHitBonus = createModifiedFloatValue(CritBonus, "CritBonus")
	_modifiedMaxHits = createModifiedIntValue(LightningCountPerEmit, "Force")
	applyModifierCategories()
	_emitTimer = 1.0 / get_totalAttackSpeed()
	_delayTimer = Timer.new(); add_child(_delayTimer)
	if EmitPositionNode == null:
		# when there is no specified node, we'll just add a new child to the mover
		var mover = _gameObject.getChildNodeWithMethod("get_worldPosition")
		EmitPositionNode = Node2D.new()
		mover.add_child(EmitPositionNode)

func applyModifierCategories():
	_modifiedSpeed.setModifierCategories(ModifierCategories)
	_modifiedEmitCount.setModifierCategories(ModifierCategories)
	_modifiedDamage.setModifierCategories(ModifierCategories)
	_modifiedCriticalHitChance.setModifierCategories(ModifierCategories)
	_modifiedCriticalHitBonus.setModifierCategories(ModifierCategories)
	_modifiedMaxHits.setModifierCategories(ModifierCategories)

func transformCategories(onlyWithDamageCategory:String, addModifierCategories:Array[String], removeModifierCategories:Array[String], addDamageCategories:Array[String], removeDamageCategories:Array[String]):
	if not DamageCategories.has(onlyWithDamageCategory):
		return
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

func set_emitting(emitting:bool, reset_timer:bool = false) -> void:
	if OnlyAllowManualEmission:
		return
	Emitting = emitting
	if reset_timer:
		_emitTimer = 0

func _process(delta):
	if _directionProvider != null:
		_aim_direction = _directionProvider.get_aimDirection()
	EmitPositionNode.global_position = (
		get_gameobjectWorldPosition() + EmissionPosOffset + _aim_direction * EmitRadius)
	if Emitting:
		_emitTimer -= delta
	else:
		_emitTimer -= delta
		if _emitTimer < 0: _emitTimer = 0
		return
	while _emitTimer <= 0:
		_emitTimer += 1.0 / get_totalAttackSpeed()
		if EmitAttackTriggered:
			AttackTriggered.emit(0)
		emit()



func emit(crit_guarantee:bool = false):
	if OnlyAllowManualEmission:
		return
	_delayTimer.start(EmitDelay / get_attackSpeedFactor())
	await _delayTimer.timeout
	var emitCount = get_totalEmitCount()
	_aim_direction = _aim_direction.rotated((emitCount-1)*_multistrikeAngle)
	for c in emitCount:
		emit_lightning(crit_guarantee)
		_aim_direction = _aim_direction.rotated(-2*_multistrikeAngle)

var _hit_candidates : Array[GameObject]
var _hit_objects : Array[GameObject]
func emit_lightning(crit_guarantee:bool):
	if _hit_candidates == null: _hit_candidates = []
	if _hit_objects == null: _hit_objects = []

	var emit_dir : Vector2 = _aim_direction
	var emit_position_node = EmitPositionNode
	var emit_position_last_valid = EmitPositionNode.global_position
	var hit_angle = deg_to_rad(HitAngleInitial)
	var emit_range = EmitRangeInitial
	for hitNumber in get_totalHitTargets():
		_hit_candidates.clear()
		var cast_position = emit_position_last_valid
		if is_instance_valid(emit_position_node) and not emit_position_node.is_queued_for_deletion():
				cast_position = emit_position_node.global_position
		for locator_pool in HitLocatorPools:
			_hit_candidates.append_array(Global.World.Locators.get_gameobjects_in_circle(
				locator_pool, cast_position, emit_range))

		var hit_object_pos_provider : Node = null
		var hit_object : Node = null
		var hit_pos : Vector2 = Vector2.ZERO
		var shortest_distance : float = emit_range * emit_range
		for candidate in _hit_candidates:
			if _hit_objects.has(candidate):
				continue
			if not is_instance_valid(candidate) or candidate.is_queued_for_deletion():
				continue
			var candidate_pos_provider = candidate.getChildNodeWithMethod("get_worldPosition")
			if candidate_pos_provider == null:
				continue
			hit_pos = candidate_pos_provider.get_worldPosition()
			var sq_dist = cast_position.distance_squared_to(hit_pos)
			if abs(emit_dir.angle_to(hit_pos - cast_position)) > hit_angle:
				continue
			if sq_dist > shortest_distance:
				continue
			shortest_distance = sq_dist
			hit_object_pos_provider = candidate_pos_provider
			hit_object = candidate
			_hit_objects.append(hit_object)

		if hit_object_pos_provider != null:
			spawn_lightning_arc_hit(
				emit_position_node,
				hit_object_pos_provider,
				cast_position)
			emit_dir = (hit_object_pos_provider.global_position - cast_position).normalized()
			emit_position_node = hit_object_pos_provider
			emit_position_last_valid = emit_position_node.global_position
			hit_angle = deg_to_rad(HitAngleChain)
			emit_range = EmitRangeChain
			var hit_object_health = hit_object.getChildNodeWithMethod("applyDamage")
			if hit_object_health != null:
				deal_damage(hit_object_health, hitNumber, crit_guarantee)
		elif hitNumber == 0:
			spawn_lightning_arc_miss()
			break
		_delayTimer.start(ChainDelay); await _delayTimer.timeout
		if not is_instance_valid(emit_position_node):
			emit_position_node = null
	# clear the hit_objects at the end, so that something triggering
	# the lightning manually can pre-filter
	_hit_objects.clear()

func deal_damage(target_health_component:Node, hitNumber:int, crit_guarantee:bool):
	var damage : int = get_totalDamage()
	var critical := false
	if get_totalHitTargets() > 0:
		var numCrits : int = floori(get_totalCritChance())
		var remainingChance : float = get_totalCritChance() - numCrits
		if crit_guarantee or randf() <= remainingChance:
			numCrits += 1
		critical = numCrits > 0
		damage += get_totalCritDamage() * numCrits

	if hitNumber > 0 && DamageMultPerHit != 1:
		var hitMultDamage : float = float(damage) * pow(DamageMultPerHit, hitNumber)
		damage = floori(hitMultDamage)

	var my_damage_source : GameObject = _gameObject.get_rootSourceGameObject()

	var damage_return = target_health_component.applyDamage(
				damage,
				my_damage_source,
				critical or crit_guarantee,
				_weapon_index,
				not Blockable)
	DamageApplied.emit(DamageCategories, damage, damage_return, target_health_component._gameObject, critical or crit_guarantee)

func spawn_lightning_arc_hit(emit_node:Node, hit_object:Node, alternative_start_pos:Vector2):
	var arc = LightningArcScene.instantiate()
	Global.attach_toWorld(arc)
	arc.play_effect(emit_node, hit_object, alternative_start_pos)

func spawn_lightning_arc_miss():
	var arc = LightningArcScene.instantiate()
	Global.attach_toWorld(arc)
	arc.play_effect(EmitPositionNode, null, Vector2.ZERO,
		EmitPositionNode.global_position + _aim_direction * EmitRangeInitial)
