extends GameObjectComponent

@export_group("Emission Parameters")
@export var EmitEverySeconds : float = 1
@export var EmitRange : float = 50
@export var LocatorPool : String = "Enemies"
@export var ModifierCategories : Array[String]
@export_enum("None", "Fire Burst", "Flame Strike") var PlayFxOnHit : int

@export_group("Damage Parameters")
@export var DamageCategories : Array[String]
@export var BaseDamage : int
@export var BaseCriticalChance : float = 0.0
@export var BaseCriticalBonus : float = 0.0
@export var NotHitTimeDamageMultiplier : float = -1
@export var NotHitTimeCritChanceMultiplier : float = -1
@export var TimeToNotHitForMaxMultiplier : float = 5

@export_group("Apply Effect")
@export var EffectNode : PackedScene
@export var ApplyChance : float = 1.0
@export var ChanceModifier : String = ""

@export_group("Internal State")
@export var _weapon_index : int

var _emit_overflow : float
var _emit_timer : float
var _last_hit_worldtime : float
var _emitEverySecondsModified : float
var _effectPrototype : EffectBase

var _modifiedAttackSpeed : ModifiedFloatValue
var _modifiedRange : ModifiedFloatValue
var _modifiedDamage : ModifiedIntValue
var _modifiedEffectChance : ModifiedFloatValue
var _modifiedCritChance : ModifiedFloatValue
var _modifiedCritBonus : ModifiedFloatValue
var _modifiedChargeTime : ModifiedFloatValue
var _modifiedDamageMultiplier : ModifiedFloatValue
var _modifiedCritMultiplier : ModifiedFloatValue

signal DamageApplied(categories:Array[String], damageAmount:float, applyReturn:Array, targetNode:GameObject, critical:bool)

# only use for the statistics. not very optimized...
func get_modified_values() -> Array:
	return [
		_modifiedAttackSpeed,
		_modifiedRange,
		_modifiedDamage,
		_modifiedCritChance,
		_modifiedCritBonus,
		_modifiedEffectChance,
		_modifiedChargeTime,
		_modifiedDamageMultiplier,
		_modifiedCritMultiplier
	]

func _enter_tree():
	initGameObjectComponent()
	if _gameObject != null:
		if EffectNode != null:
			_effectPrototype = EffectNode.instantiate()
		_modifiedAttackSpeed = createModifiedFloatValue(1.0 / EmitEverySeconds, "AttackSpeed")
		_modifiedAttackSpeed.connect("ValueUpdated", attackSpeedWasUpdated)
		_modifiedRange = createModifiedFloatValue(EmitRange, "Area")
		_modifiedDamage = createModifiedIntValue(BaseDamage, "Damage")
		_modifiedCritChance = createModifiedFloatValue(BaseCriticalChance, "CritChance")
		_modifiedCritBonus = createModifiedFloatValue(BaseCriticalBonus, "CritBonus")
		_modifiedChargeTime = createModifiedFloatValue(TimeToNotHitForMaxMultiplier, "ChargeTime")
		_modifiedDamageMultiplier = createModifiedFloatValue(NotHitTimeDamageMultiplier, "ChargeMultiplier")
		_modifiedCritMultiplier = createModifiedFloatValue(NotHitTimeCritChanceMultiplier, "ChargeMultiplier")
		if ChanceModifier != "":
			_modifiedEffectChance = createModifiedFloatValue(ApplyChance, ChanceModifier)
		applyModifierCategories()
		attackSpeedWasUpdated(_modifiedAttackSpeed.Value(), _modifiedAttackSpeed.Value())
		_emit_timer = _emitEverySecondsModified
		_last_hit_worldtime = Global.World.current_world_time
		process_mode = Node.PROCESS_MODE_INHERIT
	else:
		process_mode = Node.PROCESS_MODE_DISABLED


func _exit_tree():
	_allModifiedValues.clear()
	_modifiedAttackSpeed = null
	_modifiedRange = null
	_modifiedCritChance = null
	_modifiedCritBonus = null
	_modifiedDamage = null
	_modifiedChargeTime = null
	_modifiedDamageMultiplier = null
	_modifiedCritMultiplier = null


func applyModifierCategories():
	_modifiedAttackSpeed.setModifierCategories(ModifierCategories)
	_modifiedRange.setModifierCategories(ModifierCategories)
	_modifiedDamage.setModifierCategories(ModifierCategories)
	_modifiedCritChance.setModifierCategories(ModifierCategories)
	_modifiedCritBonus.setModifierCategories(ModifierCategories)
	_modifiedChargeTime.setModifierCategories(ModifierCategories)
	_modifiedDamageMultiplier.setModifierCategories(ModifierCategories)
	_modifiedCritMultiplier.setModifierCategories(ModifierCategories)
	if _modifiedEffectChance != null:
		_modifiedEffectChance.setModifierCategories(ModifierCategories)

func attackSpeedWasUpdated(_oldValue:float, newValue:float):
	_emitEverySecondsModified = 1.0 / newValue

func _process(delta):
	_emit_timer -= delta
	if _emit_timer <= 0:
		if hitClosestTarget():
			_emit_timer = _emitEverySecondsModified
		else:
			# we didn't hit anything, so check again next frame
			_emit_timer = 0

func hitClosestTarget() -> bool:
	var hits := Global.World.Locators.get_gameobjects_in_circle(
		LocatorPool, get_gameobjectWorldPosition(), _modifiedRange.Value())

	var closest_distance_sq : float = 99999999
	var closest_gameobject : GameObject
	var closest_worldposition: Vector2
	for hitGO in hits:
		var otherPositionProvider = hitGO.getChildNodeWithMethod("get_worldPosition")
		if otherPositionProvider == null:
			continue
		var otherPosition : Vector2 = otherPositionProvider.get_worldPosition()
		var dirToOtherPosition : Vector2 = otherPosition - get_gameobjectWorldPosition()
		var distToOtherPositionSq = dirToOtherPosition.length_squared()
		if distToOtherPositionSq < closest_distance_sq:
			closest_gameobject = hitGO
			closest_distance_sq = distToOtherPositionSq
			closest_worldposition = otherPosition
	if closest_gameobject != null:
		var healthComp = closest_gameobject.getChildNodeWithMethod("applyDamage")
		if not healthComp:
			return false

		var mySource : GameObject = _gameObject.get_rootSourceGameObject()

		var dmg := _modifiedDamage.Value()
		var critchance := _modifiedCritChance.Value()

		var notHitTime : float = clamp(Global.World.current_world_time - _last_hit_worldtime -_emitEverySecondsModified, 0, _modifiedChargeTime.Value())
		if _modifiedCritMultiplier.Value() > 0:
			var notHitFactor : float = remap(notHitTime, 0, _modifiedChargeTime.Value(), 0, _modifiedCritMultiplier.Value())
			critchance *= notHitFactor

		var critical := false
		if _modifiedCritBonus.Value() > 0:
			var numCrits : int = floori(critchance)
			var remainingChance : float = critchance - numCrits
			if randf() <= remainingChance:
				numCrits += 1
			critical = numCrits > 0
			dmg += roundi((dmg * _modifiedCritBonus.Value()) * numCrits)

		if _modifiedDamageMultiplier.Value() > 0:
			var notHitFactor : float = remap(notHitTime, 0, _modifiedChargeTime.Value(), 0, _modifiedDamageMultiplier.Value())
			dmg += ceili(dmg * notHitFactor)

		if dmg > 0:
			var damageReturn = healthComp.applyDamage(dmg, mySource, critical, _weapon_index)
			if mySource != null and is_instance_valid(mySource):
				mySource.injectEmitSignal("DamageApplied", [DamageCategories, dmg, damageReturn, closest_gameobject, critical])
				if mySource != _gameObject:
					DamageApplied.emit(DamageCategories, dmg, damageReturn, closest_gameobject, critical)

		if _effectPrototype != null and not closest_gameobject.is_queued_for_deletion():
			var chance : float = ApplyChance
			if _modifiedEffectChance != null:
				chance = _modifiedEffectChance.Value()

			while chance > 0:
				# when the probability is over 1, we don't roll the dice!
				if chance < 1 and randf() > chance:
					break
				chance -= 1
				closest_gameobject.add_effect(_effectPrototype, mySource)

		_last_hit_worldtime = Global.World.current_world_time

		match PlayFxOnHit:
			1: Fx.show_fireburst(closest_worldposition)
			2: Fx.show_flamestrike(closest_worldposition)
		return true

	return false

func get_cooldown_factor() -> float:
	return clamp(Global.World.current_world_time - _last_hit_worldtime -_emitEverySecondsModified, 0, _modifiedChargeTime.Value()) / _modifiedChargeTime.Value()
	#return 1.0 - _emit_timer / _emitEverySecondsModified

func get_totalCritChance() -> float: return _modifiedCritChance.Value()
func get_totalCritBonus() -> float: return _modifiedCritBonus.Value()
