extends GameObjectComponent2D

# this has to be of type StunEffect!
@export var StunEffectNode : PackedScene
@export_enum("NormalAndCrit", "NormalOnly", "CritOnly") var StunOnNormalOrCrit : int = 0
@export var BaseDamage : int = 40
@export var BaseCriticalChance : float = 0.0
@export var BaseCriticalBonus : float = 0.0
@export var EmitInterval : float = 2.0
@export var EmissionCount : int = 2
@export var ImpactSelectionRadius : float = 600
@export var ImpactSelectionLocatorPool : String = "Enemies"
@export var ModifierCategories : Array[String] = ["Projectile"]
@export var DamageCategories : Array[String] = ["Lightning"]

@export_group("Stun AoE Parameters")
@export var SplashRange : float = 64.0
@export var SplashEffectColor : Color = Color.WHITE
@export var HitLocatorPools : Array[String] = ["Enemies", "Breakables"]

@export_group("internal state")
@export var _weapon_index : int = -1

signal DamageApplied(damageCategories:Array[String], damageAmount:float, applyReturn:Array, targetNode:GameObject, critical:bool)
signal StunApplied(toNode:GameObject)

# this is only to identify this node via gameObject.getChildNodeWithProperty!
var LightningSpawnerIdentifier

var _effectPrototype : EffectBase
var _modifiedDamage
var _modifiedCritChance
var _modifiedCritBonus
var _modifiedRange
var _modifiedSpeed
var _modifiedEmitCount
var _modifiedStunBuildup
var _modifiedStunDuration

var _emit_overflow : float
var _emit_timer : float

func _enter_tree():
	initGameObjectComponent()
	if _gameObject:
		_emit_timer = 0.0
		visible = true
		_modifiedDamage = createModifiedIntValue(BaseDamage, "Damage")
		_modifiedCritChance = createModifiedFloatValue(BaseCriticalChance, "CritChance")
		_modifiedCritBonus = createModifiedFloatValue(BaseCriticalBonus, "CritBonus")
		_modifiedRange = createModifiedFloatValue(SplashRange, "Area")
		_modifiedSpeed = createModifiedFloatValue(1.0 / EmitInterval, "AttackSpeed")
		_modifiedEmitCount = createModifiedFloatValue(EmissionCount, "EmitCount")
		_effectPrototype = StunEffectNode.instantiate()
		_modifiedStunBuildup = createModifiedFloatValue(_effectPrototype.StunBuildup, "StunBuildup")
		_modifiedStunDuration = createModifiedFloatValue(_effectPrototype.StunDuration, "StunDuration")
		applyModifierCategories()

		if Global.is_world_ready():
			if not Global.World.is_connected("PlayerDied", _on_player_died):
				Global.World.connect("PlayerDied", _on_player_died)
		else:
			Global.connect("WorldReady", _on_world_ready)

	else:
		visible = false
		var parent = get_parent()
		if parent and parent.has_method("get_weapon_index"):
			_weapon_index = parent.get_weapon_index()

func applyModifierCategories():
	_modifiedDamage.setModifierCategories(ModifierCategories)
	_modifiedCritChance.setModifierCategories(ModifierCategories)
	_modifiedCritBonus.setModifierCategories(ModifierCategories)
	_modifiedSpeed.setModifierCategories(ModifierCategories)
	_modifiedRange.setModifierCategories(ModifierCategories)
	_modifiedEmitCount.setModifierCategories(ModifierCategories)
	_modifiedStunBuildup.setModifierCategories(ModifierCategories)
	_modifiedStunDuration.setModifierCategories(ModifierCategories)

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


func _exit_tree():
	if _effectPrototype != null:
		_effectPrototype.queue_free()
		_effectPrototype = null
	_gameObject = null
	_positionProvider = null
	_modifiedDamage = null
	_modifiedCritChance = null
	_modifiedCritBonus = null
	_modifiedRange = null
	_modifiedSpeed = null
	_modifiedEmitCount = null
	visible = false

func _on_world_ready():
	if _gameObject and not Global.World.is_connected("PlayerDied", _on_player_died):
		Global.World.connect("PlayerDied", _on_player_died)

func _on_player_died():
	_gameObject = null


func _process(delta):
	if _gameObject == null: return

	if _positionProvider:
		global_position = _positionProvider.get_worldPosition()

	if _emit_timer <= 0.0:
		emit()
		_emit_timer += get_totalEmitInterval()
	_emit_timer -= delta

func emit():
	var hits = Global.World.Locators.get_gameobjects_in_circle(
		ImpactSelectionLocatorPool, global_position, ImpactSelectionRadius)

	var candidateCount = len(hits)
	if candidateCount > 0:
		for h in get_totalEmitCount():
			var hit = pick_random_safely(hits)
			while not is_instance_valid(hit):
				hits.erase(hit)
				candidateCount -= 1
				if candidateCount <= 0: return
				hit = pick_random_safely(hits)
			hits.erase(hit)
			candidateCount -= 1
			var critical:bool = false
			var healthComponent = hit.getChildNodeWithMethod("applyDamage")
			if healthComponent:
				if healthComponent.has_method("is_invincible") and healthComponent.is_invincible():
					continue
				critical = randf() <= get_totalCritChance()
				var damage = 0
				if critical:
					damage = get_totalCritDamage()
				else:
					damage = get_totalDamage()
				var damageReturn = healthComponent.applyDamage(damage, _gameObject, critical, _weapon_index)
				DamageApplied.emit(DamageCategories, damage, damageReturn, hit, critical)

			var shouldApplyStun : bool = StunOnNormalOrCrit == 0 or	(StunOnNormalOrCrit == 1 and not critical) or (StunOnNormalOrCrit == 2 and critical)
			if shouldApplyStun:
				var hitPosition = hit.getChildNodeWithMethod("get_worldPosition")
				if hitPosition:
					var pos = hitPosition.get_worldPosition()
					Fx.show_lightning(pos)
					emit_stun(pos)
			if candidateCount <= 0:
				break
			await get_tree().create_timer(0.1, false).timeout

func pick_random_safely(array:Array):
	var pick = null
	var array_length = len(array)
	while array_length > 0 and (pick == null or pick.is_queued_for_deletion()):
		var random_index:int = randi_range(0, array_length - 1)
		pick = array[random_index]
		if pick == null or pick.is_queued_for_deletion():
			array.remove_at(random_index)
			array_length = len(array)
	if is_instance_valid(pick): return pick
	return null


var _tempHits : Array[GameObject] = []
func emit_stun(emitPosition:Vector2):
	var stun_range : float = _modifiedRange.Value()
	_effectPrototype.StunBuildup = _modifiedStunBuildup.Value()
	_effectPrototype.StunDuration = _modifiedStunDuration.Value()
	if _gameObject:
		_tempHits.clear()
		var mySource : GameObject = _gameObject.get_rootSourceGameObject()
		for locatorPool in HitLocatorPools:
			_tempHits.append_array(Global.World.Locators.get_gameobjects_in_circle(locatorPool, emitPosition, stun_range))
		for hitGO in _tempHits:
			var healthComp = hitGO.getChildNodeWithMethod("applyDamage")
			if not healthComp: continue
			hitGO.add_effect(_effectPrototype, mySource)
			StunApplied.emit(hitGO)

	Fx.show_cone_wave(
			emitPosition,
			Vector2.RIGHT,
			stun_range,
			360.0,
			3.0,
			1.0,
			SplashEffectColor,
			Callable(), null, 1.0,
			true)

func get_totalDamage() -> int: return _modifiedDamage.Value()
func get_totalCritChance() -> float: return _modifiedCritChance.Value()
func get_totalCritBonus() -> float: return _modifiedCritBonus.Value()
func get_totalEmitInterval() -> float: return 1.0 / _modifiedSpeed.Value()
func get_totalEmitCount() -> int:
	_emit_overflow += _modifiedEmitCount.Value()
	var emit_count = floor(_emit_overflow)
	_emit_overflow -= emit_count
	return emit_count

func get_totalCritDamage() -> int:
	var totalDamage = get_totalDamage()
	return totalDamage + int(ceil(totalDamage * get_totalCritBonus()))

func get_cooldown_factor() -> float:
	return 1.0 - _emit_timer / get_totalEmitInterval()
