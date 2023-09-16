extends GameObjectComponent

@export_group("Emission State")
@export var Emitting : bool = false

@export_group("Emission Parameters")
@export var EmitSpeed : float = 2.0
@export var MeleeRange : int = 60
@export var CloseupRange : int = 24
@export var MeleeArea : float = 25
@export var EmitDelay : float = 0.3
@export var EmissionCount : int = 1
@export var MultistrikeDelay : float = 0.12
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
var _modifiedArea
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
		_modifiedArea,
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


var _directionProvider : Node

var _emit_overflow : float
var _emitTimer : float
var _localDelayTimerNode : Timer
var _secondaryDelayTimerNodes

func _ready():
	initGameObjectComponent()
	_localDelayTimerNode = Timer.new()
	add_child(_localDelayTimerNode)
	_directionProvider = _gameObject.getChildNodeWithMethod("get_aimDirection")

	_modifiedDamage = createModifiedIntValue(BaseDamage, "Damage")
	_modifiedRange = createModifiedIntValue(MeleeRange, "Range")
	_modifiedArea = createModifiedFloatValue(MeleeArea, "Area")
	_modifiedSpeed = createModifiedFloatValue(EmitSpeed, "AttackSpeed")
	_modifiedCritChance = createModifiedFloatValue(BaseCriticalChance, "CritChance")
	_modifiedCritBonus = createModifiedFloatValue(BaseCriticalBonus, "CritBonus")
	_modifiedEmitCount = createModifiedFloatValue(EmissionCount, "EmitCount")
	applyModifierCategories()

	_emitTimer = 1.0 / _modifiedSpeed.Value()

func applyModifierCategories():
	_modifiedDamage.setModifierCategories(ModifierCategories)
	_modifiedRange.setModifierCategories(ModifierCategories)
	_modifiedArea.setModifierCategories(ModifierCategories)
	_modifiedSpeed.setModifierCategories(ModifierCategories)
	_modifiedCritChance.setModifierCategories(ModifierCategories)
	_modifiedCritBonus.setModifierCategories(ModifierCategories)
	_modifiedEmitCount.setModifierCategories(ModifierCategories)

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
		emit_with_delay_timer(_localDelayTimerNode)
		_emitTimer += 1.0 / get_totalAttackSpeed()


func emit_immediate(crit_guarantee:bool = false) -> void:
	if _secondaryDelayTimerNodes == null:
		initialize_secondary_delay_timers()
	var timer = null
	for t in _secondaryDelayTimerNodes:
		if t.is_stopped(): timer = t; break
	if timer: emit_with_delay_timer(timer, crit_guarantee)

var _tempHitsArray : Array[GameObject] = []
func emit_with_delay_timer(delayTimer:Timer, crit_guarantee:bool = false) -> void:
	AttackTriggered.emit(0)
	var waitTime = (EmitDelay / get_attackSpeedFactor()) * 0.5
	delayTimer.start(waitTime); await delayTimer.timeout
	play_sound()
	delayTimer.start(waitTime); await delayTimer.timeout
	var total_attacks = get_totalEmitCount()
	for count in total_attacks:
		if _directionProvider:
			var emitDir = _directionProvider.get_aimDirection()
			var emitPosition = get_gameobjectWorldPosition()
			var center_offset = get_center_offset().rotated(emitDir.angle())
			emitPosition += center_offset
			Emitted.emit(center_offset, emitDir)
			_tempHitsArray.clear()
			for hitPoolName in HitLocatorPools:
				_tempHitsArray.append_array(Global.World.Locators.get_gameobjects_in_circle(hitPoolName, emitPosition, get_totalRange()))
			_tempHitsArray.sort_custom(distance_sort)

			Global.QuestPool.notify_enemies_hit_by_attack(_tempHitsArray.size(), _weapon_index)
			for hitGO in _tempHitsArray:
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
					mySource.injectEmitSignal("DamageApplied", [DamageCategories, dmg, applyDamageReturn, hitGO, critical])
					if mySource != _gameObject:
						DamageApplied.emit(DamageCategories, dmg, applyDamageReturn, hitGO, critical)

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
func get_totalRange() -> float: return _modifiedArea.Value()
func get_totalAngle() -> float: return 360.0
func get_center_offset() -> Vector2: return Vector2(_modifiedRange.Value(), 0)
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
	return _modifiedDamage.Value() + int(ceil(_modifiedDamage.Value() * _modifiedCritBonus.Value()))
