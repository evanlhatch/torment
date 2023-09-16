extends GameObjectComponent

@export var DamagePercentageOfStrike : float = 0.1
#desc radius in pixels!
@export var ExplosionRadius : float = 40
@export var DamageCategories : Array[String] = ["Fire"]
@export var PushForce : float = 150
var _lightningSpawner : Node

signal DamageApplied(damageCategories:Array[String], damageAmount:float, applyReturn:Array, targetNode:GameObject, critical:bool)

func _ready() -> void:
	initGameObjectComponent()
	if _gameObject == null:
		return
	_lightningSpawner = _gameObject.getChildNodeWithProperty("LightningSpawnerIdentifier")
	if _lightningSpawner == null:
		printerr("ab_LightningStrike_ExplosiveStrike couldn't find the base LightningSpawner!")
		return
	# the original spawner should only stun on normal damage:
	_lightningSpawner.StunOnNormalOrCrit = 1
	# and we snatch the critical damage for ourselves
	_lightningSpawner.DamageApplied.connect(DamageWasApplied)

func DamageWasApplied(damageCategories:Array[String], damageAmount:float, applyReturn:Array, targetNode:GameObject, critical:bool):
	if not critical:
		return
	
	var hitPositionProvider = targetNode.getChildNodeWithMethod("get_worldPosition")
	if not hitPositionProvider:
		return
	
	var pos = hitPositionProvider.get_worldPosition()
	
	var damage : int = _lightningSpawner._modifiedDamage.Value() * DamagePercentageOfStrike
		
	_lightningSpawner._tempHits.clear()
	var mySource : GameObject = _gameObject.get_rootSourceGameObject()
	for locatorPool in _lightningSpawner.HitLocatorPools:
		_lightningSpawner._tempHits.append_array(Global.World.Locators.get_gameobjects_in_circle(locatorPool, pos, ExplosionRadius))
	for hitGO in _lightningSpawner._tempHits:
		var healthComp = hitGO.getChildNodeWithMethod("applyDamage")
		if not healthComp: continue
		var damageReturn = healthComp.applyDamage(damage, _gameObject, false, _lightningSpawner._weapon_index)
		DamageApplied.emit(DamageCategories, damage, damageReturn, hitGO, false)
	
	if PushForce > 0:
		Forces.RadialBlast(pos, ExplosionRadius, PushForce, Forces.Falloff.Quadratic, _lightningSpawner.HitLocatorPools)
	
	Fx.show_explosion(pos)
