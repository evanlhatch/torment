extends GameObjectComponent2D

@export var ShockwaveProbability : float = 0.2
@export var ShockwaveDamageFactor : float = 0.25
@export var ShockwaveRange : int = 28
@export var ShockwaveColor : Color
@export var HitLocatorPools : Array[String]

@export var OnlySpawnOnDamageCategories : Array[String]
@export var ShockwaveDamageCategories : Array[String]

@export_group("internal state")
@export var _weapon_index : int = -1

signal DamageApplied(damageCategories:Array[String], damageAmount:float, applyReturn:Array, targetNode:GameObject, critical:bool)

var _modifiedRange

const MAX_WAVES_PER_FRAME : int = 3
var _wave_buffer

func _enter_tree():
	if _wave_buffer == null: _wave_buffer = []
	initGameObjectComponent()
	if _gameObject:
		_gameObject.connectToSignal("DamageApplied", damageWasApplied)
		_modifiedRange = createModifiedIntValue(ShockwaveRange, "Area")
	else:
		var parent = get_parent()
		if parent and (parent is Item or parent is Ability):
			_weapon_index = parent.WeaponIndex


func _exit_tree():
	_gameObject = null
	_modifiedRange = null
	_positionProvider = null


func damageWasApplied(categories:Array[String], _damageAmount:float, applyReturn:Array, targetNode:GameObject, _isCritical:bool):
	if not OnlySpawnOnDamageCategories.is_empty():
		var atLeastOneCategoryMatches : bool = false
		for damageCat in categories:
			if OnlySpawnOnDamageCategories.has(damageCat):
				atLeastOneCategoryMatches = true
				break
		if not atLeastOneCategoryMatches:
			return

	if randf() <= ShockwaveProbability:
		var damage = floor(float(applyReturn[1]) * ShockwaveDamageFactor)
		if damage < 1.0: return
		var target_positionProvider = targetNode.getChildNodeWithMethod("get_worldPosition")
		if target_positionProvider != null:
			_wave_buffer.append([target_positionProvider.get_worldPosition(), damage, targetNode])


@onready var _propagation_timer : float = 0.0
func _process(delta):
	if _propagation_timer > 0.0:
		_propagation_timer -= delta
		return
	var wave_count = min(len(_wave_buffer), MAX_WAVES_PER_FRAME)
	if wave_count == 0: return
	for i in wave_count:
		var wave = _wave_buffer.pop_back()
		if wave[2] != null and not wave[2].is_queued_for_deletion():
			emit(wave[0], wave[1], wave[2])
		else:
			emit(wave[0], wave[1], null)
	_propagation_timer = 0.05


var _tempHits : Array[GameObject] = []
func emit(emitPosition:Vector2, damage:int, centerObject:GameObject):
	if _gameObject != null:
		_tempHits.clear()
		for locatorPool in HitLocatorPools:
			_tempHits.append_array(Global.World.Locators.get_gameobjects_in_circle(locatorPool, emitPosition, float(_modifiedRange.Value())))
		for hitGO in _tempHits:
			if hitGO == centerObject: continue
			var healthComp = hitGO.getChildNodeWithMethod("applyDamage")
			if not healthComp: continue
			var result = healthComp.applyDamage(damage, _gameObject, false, _weapon_index)
			DamageApplied.emit(ShockwaveDamageCategories, damage, result, hitGO, false)

		Fx.show_cone_wave(
			emitPosition,
			Vector2.RIGHT,
			_modifiedRange.Value(),
			360.0,
			3.0,
			1.0,
			ShockwaveColor,
			Callable(), null, 1.0,
			true)

