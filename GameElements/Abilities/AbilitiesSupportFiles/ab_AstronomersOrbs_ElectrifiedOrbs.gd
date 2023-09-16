extends GameObjectComponent

@export var BaseAbilityWeaponIndex : int = 1001
@export var DamageMultiplierOnBaseOrbDamage : float = 0.5
@export var DamageCategories : Array[String] = ["Lightning"]
@export var ElectrifyChance : float = 0.1
@export var ElectrifyMultiplierBySpeed : float = 0.5
@export var ElectrifyEffectNode : PackedScene

var _baseAbilityModifiedDamage
var _baseAbilityModifiedSpeed
var _currentLightningDamage : int
var _currentElectrifyChance : float
var _effectPrototype : EffectBase

signal DamageApplied(damageCategories:Array[String], damageAmount:float, applyReturn:Array, targetNode:GameObject, critical:bool)

func _ready() -> void:
	initGameObjectComponent()
	if _gameObject == null:
		return
	var baseOrbsAbility : Ability = Global.World.AbilityPool.find_ability_with_weapon_index(BaseAbilityWeaponIndex)
	if baseOrbsAbility == null:
		printerr("ab_AstronomersOrbs_ElectrifiedOrbs could not find base Astronomers Ability!")
		return
	for bestMod in baseOrbsAbility.bestowed_modifiers:
		if bestMod.has_method("update_sphere_configuration"):
			# this is the original orbs node! we'll connect ourselves to the modifiedDamage and modifiedSpeed
			_baseAbilityModifiedDamage = bestMod._modifiedDamage
			_baseAbilityModifiedDamage.connect("ValueUpdated", calculateNewLightningDamage)
			_baseAbilityModifiedSpeed = bestMod._modifiedSpeed
			_baseAbilityModifiedSpeed.connect("ValueUpdated", calculateElectrifyChance)
			break
		
	_gameObject.connectToSignal("AstronomersOrbTouched", OrbTouched)
	calculateNewLightningDamage(0,0)
	calculateElectrifyChance(0,0)
	_effectPrototype = ElectrifyEffectNode.instantiate()

func calculateNewLightningDamage(_prev:int, _curr:int):
	_currentLightningDamage = _baseAbilityModifiedDamage.Value() * DamageMultiplierOnBaseOrbDamage * (_baseAbilityModifiedSpeed.Value() / _baseAbilityModifiedSpeed.BaseValue()) 

func calculateElectrifyChance(_prev:int, _curr:int):
	_currentElectrifyChance = ElectrifyChance + ElectrifyChance * ElectrifyMultiplierBySpeed * ((_baseAbilityModifiedSpeed.Value() / _baseAbilityModifiedSpeed.BaseValue())-1)

func OrbTouched(target:GameObject):
	var health_component = target.getChildNodeWithMethod("applyDamage")
	if health_component:
		var damageReturn = health_component.applyDamage(_currentLightningDamage, _gameObject, false, BaseAbilityWeaponIndex)
		DamageApplied.emit(DamageCategories, _currentLightningDamage, damageReturn, target, false)
	var electrifyChance = _currentElectrifyChance
	while electrifyChance > 1.0:
		var mySource : GameObject = _gameObject.get_rootSourceGameObject()
		target.add_effect(_effectPrototype, mySource)
		electrifyChance -= 1.0
	if randf() < electrifyChance:
		var mySource : GameObject = _gameObject.get_rootSourceGameObject()
		target.add_effect(_effectPrototype, mySource)
