extends GameObjectComponent

@export_enum("OnDamage", "OnHit", "CollisionStarted") var EmitOnSignal : int = 0
@export var ChanceToEmit : float = 1
@export var TargetNeedsEffects : Array[String]

## Will only be evaluated when EmitOnSignal is "OnDamage"!
@export 
var OnlyForDamageCategories : Array[String] = ["Magic"]

var _childLightningEmitter : Node

func _ready():
	initGameObjectComponent()
	if _gameObject == null:
		return
	
	_childLightningEmitter = get_child(0)
	
	if EmitOnSignal == 0:
		_gameObject.connectToSignal("DamageApplied", damageWasApplied)
	elif EmitOnSignal == 1:
		_gameObject.connectToSignal("OnHit", checkAndEmit)
	elif EmitOnSignal == 2:
		_gameObject.connectToSignal("CollisionStarted", checkAndEmit)

func damageWasApplied(damageCategories:Array[String], damageAmount:float, applyReturn:Array, targetNode:GameObject, critical:bool):
	if not OnlyForDamageCategories.is_empty():
		var atLeastOneCategoryMatches : bool = false
		for damageCat in damageCategories:
			if OnlyForDamageCategories.has(damageCat):
				atLeastOneCategoryMatches = true
				break
		if not atLeastOneCategoryMatches:
			return
	checkAndEmit(targetNode)

func checkAndEmit(node:GameObject):
	# chance check is cheaper, let's do that first:
	if ChanceToEmit < 1 and randf() > ChanceToEmit:
		return
	
	for neededEffect in TargetNeedsEffects:
		if node.find_effect(neededEffect) == null:
			return
	
	var positionProvider : Node = node.getChildNodeWithMethod("get_worldPosition")
	if positionProvider == null:
		return
	
	# don't want to hit the object from which the emission originates!
	_childLightningEmitter._hit_objects.append(node)
	_childLightningEmitter.EmitPositionNode = positionProvider
	_childLightningEmitter.emit_lightning(false)
