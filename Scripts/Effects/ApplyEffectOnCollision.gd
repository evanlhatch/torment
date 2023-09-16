extends GameObjectComponent

@export var EffectNode : PackedScene
@export var ApplyChance : float = 1.0
@export var ChanceModifier : String = ""
@export var RemoveGameObjectAfterNumApplies : int = -1
@export var ModifierCategories : Array[String] = ["Physical"]

signal Killed(byNode:Node)

var _numTimesApplied : int = 0

var _modifiedChance
var _modifiedOnHitChance
var _effectPrototype : EffectBase

func _enter_tree():
	initGameObjectComponent()
	if _gameObject != null:
		_effectPrototype = EffectNode.instantiate()
		_gameObject.connectToSignal("CollisionStarted", collisionWithNode)
		_modifiedOnHitChance = createModifiedFloatValue(ApplyChance, "OnHitChance")
		if ChanceModifier != "":
			_modifiedChance = createModifiedFloatValue(ApplyChance, ChanceModifier)
		applyModifierCategories()

func _exit_tree():
	if _effectPrototype != null:
		_effectPrototype.queue_free()
		_effectPrototype = null

func applyModifierCategories():
	if _modifiedChance != null:
		_modifiedChance.setModifierCategories(ModifierCategories)
	_modifiedOnHitChance.setModifierCategories(ModifierCategories)

func collisionWithNode(node:Node):
	if RemoveGameObjectAfterNumApplies > 0 && _numTimesApplied >= RemoveGameObjectAfterNumApplies:
		return
	if _gameObject == null or _gameObject.is_queued_for_deletion():
		return
	var chance = _modifiedOnHitChance.Value()
	if _modifiedChance != null:
		chance += _modifiedChance.Value() - _modifiedChance.BaseValue()
	if chance < 1.0 && randf() >= chance:
		return
	var mySource : GameObject = _gameObject.get_rootSourceGameObject()
	node.add_effect(_effectPrototype, mySource)
	_numTimesApplied += 1
	if RemoveGameObjectAfterNumApplies > 0 && _numTimesApplied >= RemoveGameObjectAfterNumApplies:
		Killed.emit(null)
		if _gameObject != null and not _gameObject.is_queued_for_deletion():
			_gameObject.queue_free()

