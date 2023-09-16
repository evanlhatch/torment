extends GameObjectComponent

@export var EffectNode : PackedScene
@export var ApplyChance : float = 1.0
@export var ChanceModifier : String = ""
@export var RemoveGameObjectAfterNumApplies : int = -1

@export var ApplyInRadius : float = 0
@export var RadiusLocatorPool : String = "Enemies"
@export var Cooldown : float = 0

@export_group("internal state")
@export var _source : Node

signal Killed(byNode:Node)

var _numTimesApplied : int = 0
var _nextAllowedTime : float = 0

var modifiedChance
var _effectPrototype : EffectBase

func _enter_tree():
	initGameObjectComponent()
	if _gameObject != null:
		_nextAllowedTime = Global.World.current_world_time + Cooldown
		_effectPrototype = EffectNode.instantiate()
		_gameObject.connectToSignal("ReceivedDamage", receivedDamage)
		if ChanceModifier != "":
			modifiedChance = createModifiedFloatValue(ApplyChance, ChanceModifier)

func _exit_tree():
	if _effectPrototype != null:
		_effectPrototype.queue_free()
		_effectPrototype = null

func receivedDamage(amount:int, byNode:Node, weapon_index:int):
	if _nextAllowedTime > Global.World.current_world_time:
		return
	if RemoveGameObjectAfterNumApplies > 0 && _numTimesApplied >= RemoveGameObjectAfterNumApplies:
		return
	if _gameObject == null or _gameObject.is_queued_for_deletion() or byNode == null or byNode.is_queued_for_deletion():
		return
	var chance = ApplyChance
	if modifiedChance != null:
		chance = modifiedChance.Value()
	if chance < 1.0 && randf() >= chance:
		return
	_nextAllowedTime = Global.World.current_world_time + Cooldown
	var mySource : GameObject = _gameObject.get_rootSourceGameObject()
	if ApplyInRadius <= 0:
		var effectNode : Node = byNode.add_effect(_effectPrototype, mySource)
		if effectNode.has_method("damage_was_received"):
			# this can potentionally lead to multiple damage_was_received calls for the same event.
			# the effect node has to handle that itself, when that is a problem...
			effectNode.damage_was_received(amount, byNode, weapon_index)
		_numTimesApplied += 1
		if RemoveGameObjectAfterNumApplies > 0 && _numTimesApplied >= RemoveGameObjectAfterNumApplies:
			Killed.emit(null)
			_gameObject.queue_free()
	else:
		var gameObjectsInCircle : Array = Global.World.Locators.get_gameobjects_in_circle(RadiusLocatorPool, get_gameobjectWorldPosition(), ApplyInRadius)
		for gameObj in gameObjectsInCircle:
			var effectNode : Node = gameObj.add_effect(_effectPrototype, mySource)
			if effectNode.has_method("damage_was_received"):
				# this can potentionally lead to multiple damage_was_received calls for the same event.
				# the effect node has to handle that itself, when that is a problem...
				effectNode.damage_was_received(amount, byNode, weapon_index)
			_numTimesApplied += 1
			if RemoveGameObjectAfterNumApplies > 0 && _numTimesApplied >= RemoveGameObjectAfterNumApplies:
				Killed.emit(null)
				_gameObject.queue_free()
				return

@export_group("Modifier Info Area")
@export var Icon : Texture2D
@export var Name : String = "ApplyEffectOnDamageReceived"
@export_multiline var TooltipText : String = ""

func get_modifierInfoArea_icon() -> Texture2D:
	return Icon

func get_modifierInfoArea_cooldownfactor() -> float:
	if Cooldown <= 0:
		return 0
	var remainingTime : float = _nextAllowedTime - Global.World.current_world_time
	if remainingTime < 0: return 0
	return remainingTime / Cooldown

func get_modifierInfoArea_active() -> bool:
	return _nextAllowedTime <= Global.World.current_world_time

func get_modifierInfoArea_name() -> String:
	return Name
