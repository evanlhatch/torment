extends GameObjectComponent

@export var EffectScenes : Array[PackedScene]
@export_enum("PickRandom", "AllOrNothing", "RollChanceForAll") var EffectSelection : int = 0
@export var TargetEffectList : Array[String]
@export var ChancePerStack : float = 0.02
@export var OnlyForCriticalHits : bool = false
@export var OnlyForDamageCategories : Array[String] = ["DefaultWeapon"]

var _effectPrototypes : Array[Node]
var _lastTotalChance : float = 0

func _ready():
	initGameObjectComponent()
	if _gameObject == null:
		return
	for EffectScene in EffectScenes:
		_effectPrototypes.append(EffectScene.instantiate())
	_gameObject.connectToSignal("DamageApplied", damageWasApplied)


func damageWasApplied(damageCategories:Array[String], damageAmount:float, applyReturn:Array, targetNode:GameObject, critical:bool):
	if OnlyForCriticalHits and not critical:
		return

	if not OnlyForDamageCategories.is_empty():
		var atLeastOneCategoryMatches : bool = false
		for damageCat in damageCategories:
			if OnlyForDamageCategories.has(damageCat):
				atLeastOneCategoryMatches = true
				break
		if not atLeastOneCategoryMatches:
			return

	var numStacks := getTargetEffectStacks(targetNode)
	setTotalChance(numStacks)
	applyEffects(targetNode)


func getTargetEffectStacks(targetNode:GameObject) -> int:
	var numStacks : int = 0
	for effectName in TargetEffectList:
		var effectNode : Node = targetNode.find_effect(effectName)
		if effectNode != null and effectNode._num_stacks != null:
			numStacks += effectNode._num_stacks
	return numStacks


func applyEffects(targetNode:GameObject):
	match EffectSelection:
		0:
			if getChanceResult():
				targetNode.add_effect(_effectPrototypes.pick_random(), _gameObject)
		1:
			if getChanceResult():
				for effect in _effectPrototypes:
					targetNode.add_effect(effect, _gameObject)
		2:
			for effect in _effectPrototypes:
				if getChanceResult():
					targetNode.add_effect(effect, _gameObject)


func getChanceResult() -> bool:
	return randf() < _lastTotalChance

func setTotalChance(numStack:int):
	_lastTotalChance = ChancePerStack * numStack
