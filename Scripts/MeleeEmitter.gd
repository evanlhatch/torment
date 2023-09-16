extends GameObjectComponent

@export_group("Emission State")
@export var Emitting : bool = false
@export var AttackAnimationIndex : int = 0

@export_group("Emission Parameters")
@export var EmitSpeed : float = 2.0
@export var MeleeRange : int = 60
@export var CloseupRange : int = 24
@export var MeleeAngle : float = 25
@export var EmitDelay : float = 0.3
@export var EmissionCount : int = 1
@export var MultistrikeDelay : float = 0.12
@export var MultiEmitTimes : int = 1
@export var MultiEmitAngle : float = 0
@export var MultiEmitDelay : float = 1
@export var MultiEmitDamageCategory : Array[String]
@export var HitLocatorPools : Array[String] = ["Enemies", "Breakables"]
@export var ModifierCategories : Array[String] = ["Physical"]
@export var DamageCategories : Array[String] = ["DefaultWeapon"]
@export var EmitSound : AudioFXResource

@export_group("Damage Parameters")
@export var BaseDamage : int = 1
@export var BaseCriticalChance : float = 0.0
@export var BaseCriticalBonus : float = 0.0
@export var MaxHitCount : int = 5
@export var StunBuildupPerEmit : float = 0.0
@export var StunDuration : float = 0.3

@export_group("Internal State")
@export var _weapon_index : int = -1

var _modifiedDamage
var _modifiedRange
var _modifiedAngle
var _modifiedSpeed
var _modifiedCritChance
var _modifiedCritBonus
var _modifiedMaxHits
var _modifiedEmitCount
# only use for the statistics. not very optimized...
func get_modified_values() -> Array:
	return [
		_modifiedDamage,
		_modifiedRange,
		_modifiedAngle,
		_modifiedSpeed,
		_modifiedCritChance,
		_modifiedCritBonus,
		_modifiedMaxHits,
		_modifiedEmitCount
	]
func is_character_base_node() -> bool : return true

signal AttackTriggered(attack_index:int)
signal Emitted(center_offset:Vector2, direction:Vector2)
signal DamageApplied(damageCategories:Array[String], damageAmount:float, applyReturn:Array, targetNode:GameObject, critical:bool)
signal OnHit(nodeHit:GameObject, hitNumber:int)


var _directionProvider : Node

var _emit_overflow : float
var _emitTimer : float
var _localDelayTimerNode : Timer
var _secondaryDelayTimerNodes
var _multiEmitDamageCategories : Array

func _ready():
	initGameObjectComponent()
	_localDelayTimerNode = Timer.new()
	add_child(_localDelayTimerNode)
	_directionProvider = _gameObject.getChildNodeWithMethod("get_aimDirection")

	_modifiedDamage = createModifiedIntValue(BaseDamage, "Damage")
	_modifiedRange = createModifiedIntValue(MeleeRange, "Range")
	_modifiedAngle = createModifiedFloatValue(MeleeAngle, "Area")
	_modifiedSpeed = createModifiedFloatValue(EmitSpeed, "AttackSpeed")
	_modifiedCritChance = createModifiedFloatValue(BaseCriticalChance, "CritChance")
	_modifiedCritBonus = createModifiedFloatValue(BaseCriticalBonus, "CritBonus")
	_modifiedEmitCount = createModifiedFloatValue(EmissionCount, "EmitCount")
	applyModifierCategories()

	if MultiEmitTimes <= 1:
		_multiEmitDamageCategories.append(DamageCategories)
	else:
		for i in range(MultiEmitTimes):
			_multiEmitDamageCategories.append(DamageCategories)
			if MultiEmitDamageCategory.size() > i:
				_multiEmitDamageCategories[i].append(MultiEmitDamageCategory[i])

	# Set _emitTimer to a small duration >0 so it doesn't emit on spawn
	# but reacts quickly when triggered the first tiem
	_emitTimer = 0.1

func applyModifierCategories():
	_modifiedDamage.setModifierCategories(ModifierCategories)
	_modifiedRange.setModifierCategories(ModifierCategories)
	_modifiedAngle.setModifierCategories(ModifierCategories)
	_modifiedSpeed.setModifierCategories(ModifierCategories)
	_modifiedCritChance.setModifierCategories(ModifierCategories)
	_modifiedCritBonus.setModifierCategories(ModifierCategories)
	_modifiedEmitCount.setModifierCategories(ModifierCategories)

func transformCategories(onlyWithDamageCategory:String, addModifierCategories:Array[String], removeModifierCategories:Array[String], addDamageCategories:Array[String], removeDamageCategories:Array[String]):
	for damageCategories in _multiEmitDamageCategories:
		if not damageCategories.has(onlyWithDamageCategory):
			continue

		for addMod in addModifierCategories:
			if not ModifierCategories.has(addMod):
				ModifierCategories.append(addMod)
		for remMod in removeModifierCategories:
			ModifierCategories.erase(remMod)

		for addCat in addDamageCategories:
			if not damageCategories.has(addCat):
				damageCategories.append(addCat)
		for remMod in removeDamageCategories:
			damageCategories.erase(remMod)

	applyModifierCategories()

func set_emitting(emit:bool) -> void:
	Emitting = emit


func _process(delta):
	if Emitting:
		_emitTimer -= delta
	else:
		_emitTimer -= delta
		if _emitTimer < 0: _emitTimer = 0
		return
	while _emitTimer <= 0:
		if MultiEmitTimes <= 1:
			emit_with_delay_timer(_localDelayTimerNode)
		else:
			multi_emit_coroutine()
		_emitTimer += 1.0 / get_totalAttackSpeed()

func multi_emit_coroutine():
	if _secondaryDelayTimerNodes == null:
		initialize_secondary_delay_timers()
	var angleOffsetPerEmit : float = MultiEmitAngle / (MultiEmitTimes-1)
	var startAngle : float = -MultiEmitAngle / 2.0
	for emitIndex in MultiEmitTimes:
		var timer = null
		for t in _secondaryDelayTimerNodes:
			if t.is_stopped(): timer = t; break
		if timer: emit_with_delay_timer(timer, false, startAngle + angleOffsetPerEmit * emitIndex, emitIndex)
		await get_tree().create_timer(MultiEmitDelay / get_totalAttackSpeed()).timeout

func emit_immediate(crit_guarantee:bool = false) -> void:
	if _secondaryDelayTimerNodes == null:
		initialize_secondary_delay_timers()
	var timer = null
	for t in _secondaryDelayTimerNodes:
		if t.is_stopped(): timer = t; break
	if timer: emit_with_delay_timer(timer, crit_guarantee)

var _tempHitsArray : Array[Locator] = []
func emit_with_delay_timer(delayTimer:Timer, crit_guarantee:bool = false, angle_offset:float = 0, use_damage_category_index:int = 0) -> void:
	AttackTriggered.emit(AttackAnimationIndex)
	var waitTime = (EmitDelay / get_attackSpeedFactor()) * 0.5
	delayTimer.start(waitTime); await delayTimer.timeout
	play_sound()
	delayTimer.start(waitTime); await delayTimer.timeout
	var total_attacks = get_totalEmitCount()
	var hit_number : int = 0
	for count in total_attacks:
		if _directionProvider:
			var emitDir : Vector2 = _directionProvider.get_aimDirection()
			if angle_offset != 0: emitDir = emitDir.rotated(deg_to_rad(angle_offset))
			Emitted.emit(Vector2.ZERO, emitDir)
			var emitPosition = get_gameobjectWorldPosition()
			_tempHitsArray.clear()
			for hitPoolName in HitLocatorPools:
				_tempHitsArray.append_array(Global.World.Locators.get_locators_in_circle(hitPoolName, emitPosition, get_totalRange()))
			var hitGameObjects = []
			for hitLocator in _tempHitsArray:
				var hitGameObject: GameObject = Global.get_gameObject_in_parents(hitLocator)
				if hitGameObject == null:
					continue
				var hitPositionProvider = hitGameObject.getChildNodeWithMethod("get_worldPosition")
				if not hitPositionProvider:
					continue
				var hitPosition : Vector2 = hitPositionProvider.get_worldPosition()
				var hitDir : Vector2 = (hitPosition - emitPosition).normalized()

				# the simplest check: is it up close?
				var distSquared : float = emitPosition.distance_squared_to(hitPosition)
				if distSquared < CloseupRange*CloseupRange:
					hitGameObjects.append(hitGameObject)
					continue
				# is the position in the hit cone?
				var angleToPosition : float = abs(rad_to_deg(hitDir.angle_to(emitDir)))
				if angleToPosition < get_totalAngle() * 0.5:
					hitGameObjects.append(hitGameObject)
					continue
				# is the circle of the locator in the hit cone?
				# this is the angle of the isosceles triangle composed of
				# the locator radius (as c) and the distance (as a and b). formula of the angle:
				# γ = arccos( ( 2 * a² - c² ) / (2a²) )
				var locatorCircleDiameterSquared : float = hitLocator.Radius * 2.0
				locatorCircleDiameterSquared *= locatorCircleDiameterSquared
				var angleOfLocatorRadius : float = acos(
					(2 * distSquared - locatorCircleDiameterSquared) /
					(2 * distSquared))
				if angleOfLocatorRadius != NAN:
					# divided by 2, because we only want the circle and not the diameter
					angleOfLocatorRadius = rad_to_deg(angleOfLocatorRadius) / 2
					if (angleToPosition - angleOfLocatorRadius) < get_totalAngle() * 0.5:
						hitGameObjects.append(hitGameObject)
						continue


			hitGameObjects.sort_custom(distance_sort)
			Global.QuestPool.notify_enemies_hit_by_attack(len(hitGameObjects), _weapon_index)

			for hitGO in hitGameObjects:
				var healthComp = hitGO.getChildNodeWithMethod("applyDamage")
				if not healthComp:
					continue # we can't do damage :(

				var dmg := get_totalDamage()
				var critical := false
				if _modifiedCritBonus.Value() > 0:
					var numCrits : int = floori(_modifiedCritChance.Value())
					var remainingChance : float = _modifiedCritChance.Value() - numCrits
					if crit_guarantee or randf() <= remainingChance:
						numCrits += 1
					critical = numCrits > 0
					dmg += (dmg * _modifiedCritBonus.Value()) * numCrits

				var mySource : GameObject = _gameObject.get_rootSourceGameObject()
				var applyDamageReturn = healthComp.applyDamage(dmg, mySource, critical, _weapon_index)
				if mySource != null and is_instance_valid(mySource):
					mySource.injectEmitSignal("DamageApplied", [_multiEmitDamageCategories[use_damage_category_index], dmg, applyDamageReturn, hitGO, critical])
					if mySource != _gameObject:
						DamageApplied.emit(_multiEmitDamageCategories[use_damage_category_index], dmg, applyDamageReturn, hitGO, critical)
				OnHit.emit(hitGO, hit_number)
				hit_number += 1

			if count < total_attacks - 1:
				delayTimer.start(MultistrikeDelay / get_attackSpeedFactor())
				await delayTimer.timeout


func play_sound():
	if EmitSound != null:
		FxAudioPlayer.play_sound_2D(EmitSound, get_gameobjectWorldPosition(), false, false, 0)

func initialize_secondary_delay_timers():
	_secondaryDelayTimerNodes = [
		Timer.new(),
		Timer.new(),
		Timer.new()
	]
	for t in _secondaryDelayTimerNodes:
		add_child(t)
		t.one_shot = true
		t.stop()

func get_totalDamage() -> int: return _modifiedDamage.Value()
func get_totalRange() -> float: return _modifiedRange.Value()
func get_totalAngle() -> float: return _modifiedAngle.Value()
func get_totalAttackSpeed() -> float: return _modifiedSpeed.Value()
func get_totalCritChance() -> float: return _modifiedCritChance.Value()
func get_totalCritBonus() -> float: return _modifiedCritBonus.Value()
func get_totalEmitCount() -> int:
	_emit_overflow += _modifiedEmitCount.Value()
	var emit_count = floor(_emit_overflow)
	_emit_overflow -= emit_count
	return emit_count

func get_attackSpeedFactor() -> float:
	return _modifiedSpeed.Value() / EmitSpeed

func get_totalCritDamage() -> int:
	return _modifiedDamage.Value() + ceili(_modifiedDamage.Value() * _modifiedCritBonus.Value())
