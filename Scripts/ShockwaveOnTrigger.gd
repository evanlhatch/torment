extends GameObjectComponent

@export_enum("Distance", "Number of Hits", "Custom Signal") var Trigger : int = 0
@export var CustomSignalName : String
@export var BaseDamage : int = 30
@export var BaseTriggerValue : float = 99.0
@export var Active : bool = true
@export var UseModifier : bool = true
@export var ShockwaveRange : float = 60
@export var ModifierCategories : Array[String] = ["Lightning"]
@export var DamageCategories : Array[String] = ["Lightning"]
@export var HitLocatorPools : Array[String] = ["Enemies", "Breakables"]

@export_group("Applied Effect Settings")
@export var EffectScene : PackedScene
@export var ApplyChance : float = 1.0
@export var ChanceModifier : String = "Electrify"

@export_group("Visual Settings")
@export var ShockwaveTexture : Texture2D
@export var ShockwaveColor : Color = Color.WHITE

@export_group("Audio Settings")
@export var AudioNode : AudioStreamPlayer2D

@export_group("internal state")
@export var _weapon_index : int = -1

var _previousPosition : Vector2
var _traveledDistance : float
var _numHits : int
var _modifiedDamage
var _modifiedSpeed
var _modifiedRange
var _modifiedChance
var _modifiedOnHitChance
var _effectPrototype : EffectBase
var _audioNode
var _lastShockwaveTime : float

signal DamageApplied(damageCategories:Array[String], damageAmount:float, applyReturn:Array, targetNode:GameObject, critical:bool)

func _enter_tree():
	await get_tree().process_frame
	_traveledDistance = 0.0
	initGameObjectComponent()
	if _gameObject == null:
		process_mode = PROCESS_MODE_DISABLED
		return
	match Trigger:
		0: process_mode = PROCESS_MODE_INHERIT
		1:
			process_mode = PROCESS_MODE_DISABLED
			_gameObject.connectToSignal("OnHit", on_hit)
		2:
			process_mode = Node.PROCESS_MODE_DISABLED
			if not CustomSignalName.is_empty():
				_gameObject.connectToSignal(CustomSignalName, trigger)

	var _weapon_index_provider = _gameObject.getChildNodeWithMethod("set_weapon_index")
	if _weapon_index_provider != null: _weapon_index = _weapon_index_provider._weapon_index
	if EffectScene != null : _effectPrototype = EffectScene.instantiate()
	_previousPosition = get_gameobjectWorldPosition()
	_modifiedDamage = createModifiedIntValue(BaseDamage, "Damage")
	_modifiedSpeed = createModifiedFloatValue(1.0 / BaseTriggerValue, "AttackSpeed")
	_modifiedRange = createModifiedFloatValue(ShockwaveRange, "Area")
	_modifiedOnHitChance = createModifiedFloatValue(ApplyChance, "OnHitChance")
	if ChanceModifier != "":
		_modifiedChance = createModifiedFloatValue(ApplyChance, ChanceModifier)
	applyModifierCategories()
	for n in _positionProvider.get_children():
		if n is AudioStreamPlayer2D:
			_audioNode = n
			break

func applyModifierCategories():
	_modifiedDamage.setModifierCategories(ModifierCategories)
	_modifiedSpeed.setModifierCategories(ModifierCategories)
	_modifiedRange.setModifierCategories(ModifierCategories)
	if _modifiedChance != null:
		_modifiedChance.setModifierCategories(ModifierCategories)
	_modifiedOnHitChance.setModifierCategories(ModifierCategories)


func _exit_tree():
	_gameObject = null
	_modifiedSpeed = null
	_modifiedRange = null
	_positionProvider = null


func _process(delta):
	if not Active: return
	var newPos = get_gameobjectWorldPosition()
	var posDelta = _previousPosition.distance_to(newPos)
	_previousPosition = newPos
	_traveledDistance += posDelta
	var totalTriggerDistance = get_totalTriggerDistance()
	if _traveledDistance >= totalTriggerDistance:
		_traveledDistance -= totalTriggerDistance
		trigger()

func on_hit(nodeHit:GameObject, hitNumber:int):
	_numHits += 1
	if _numHits >= BaseTriggerValue:
		_numHits -= BaseTriggerValue
		trigger()

var _tempHits : Array[GameObject] = []
func trigger():
	_lastShockwaveTime = Global.World.current_world_time
	var mySource : GameObject = _gameObject.get_rootSourceGameObject()
	var emitPosition = get_gameobjectWorldPosition()
	_tempHits.clear()
	for locatorPool in HitLocatorPools:
		_tempHits.append_array(Global.World.Locators.get_gameobjects_in_circle(locatorPool, emitPosition, float(get_totalRange())))

	var damage =  get_totalDamage()
	for hitGO in _tempHits:
		var healthComp = hitGO.getChildNodeWithMethod("applyDamage")
		if not healthComp: continue
		var result = healthComp.applyDamage(damage, mySource, false, _weapon_index)
		DamageApplied.emit(DamageCategories, damage, result, hitGO, false)
		if _effectPrototype != null:
			var chance = ApplyChance
			if UseModifier: chance = _modifiedOnHitChance.Value()
			if UseModifier and _modifiedChance != null:
				chance += _modifiedChance.Value() - _modifiedChance.BaseValue()
			while chance > 0:
				# when the probability is over 1, we don't roll the dice!
				if chance < 1 and randf() > chance:
					break
				chance -= 1
				hitGO.add_effect(_effectPrototype, mySource)

	Global.QuestPool.notify_enemies_hit_by_attack(len(_tempHits), _weapon_index)
	if _audioNode != null: _audioNode.play()
	Fx.show_cone_wave(
		emitPosition,
		Vector2.UP,
		get_totalRange(), 360,
		3.0, 1.0, ShockwaveColor, Callable(),
		ShockwaveTexture, 1.0,
		true)


func get_totalTriggerDistance() -> float:
	if not UseModifier: return BaseTriggerValue
	if _modifiedSpeed.Value() == 0: return 99999.0
	return 1.0 / _modifiedSpeed.Value()

func get_totalDamage() -> int:
	if not UseModifier: return BaseDamage
	return _modifiedDamage.Value()

func get_totalRange() -> float:
	if not UseModifier: return ShockwaveRange
	return _modifiedRange.Value()

@export_group("Modifier Info Area")
@export var Icon : Texture2D
@export var Name : String = "ShockwaveOnDistance"
@export_multiline var TooltipText : String = ""

func get_modifierInfoArea_icon() -> Texture2D:
	return Icon

func get_modifierInfoArea_tooltip() -> String:
	return TooltipText

func get_modifierInfoArea_cooldownfactor() -> float:
	match Trigger:
		0:
			var totalTriggerDistance = get_totalTriggerDistance()
			return 1.0 - _traveledDistance / totalTriggerDistance
		1: return _numHits / BaseTriggerValue
	return 1

func get_modifierInfoArea_active() -> bool:
	return Global.World.current_world_time < _lastShockwaveTime + 0.5

func get_modifierInfoArea_name() -> String:
	return Name
