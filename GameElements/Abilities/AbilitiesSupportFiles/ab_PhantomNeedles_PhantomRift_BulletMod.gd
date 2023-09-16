extends GameObjectComponent

@export var ModifierValue : float = 0.1
@export var Radius : float = 50
@export var LocatorPools : Array[String] = ["Enemies", "Breakables"]
@export var DamageCategories : Array[String] = ["magic"]
@export var EffectColor : Color = Color.MEDIUM_PURPLE

@export var _weapon_index : int

signal DamageApplied(categories:Array[String], damageAmount:float, applyReturn:Array, targetNode:GameObject, critical:bool)

func set_weapon_index(weapon_index:int):
	_weapon_index = weapon_index

func _ready() -> void:
	initGameObjectComponent()
	if _gameObject == null:
		return
	_gameObject.connectToSignal("OnEndOfLife", bulletEndOfLifeReached)

func bulletEndOfLifeReached() -> void:
	var bulletComp := _gameObject.getChildNodeWithProperty("_numberOfHits")
	if bulletComp == null:
		printerr("ab_PhantomNeedles_PhantomRift_BulletMod needs a bullet component to work properly!")
		return
	var applyDamageOnHitComp := _gameObject.getChildNodeWithProperty("_modifiedDamage")
	if applyDamageOnHitComp == null:
		printerr("ab_PhantomNeedles_PhantomRift_BulletMod needs a ApplyDamageOnHit component to work properly!")
		return
	var remainingHits : int = bulletComp._modifiedNumberOfHits.Value() - bulletComp._numberOfHits
	if remainingHits <= 0:
		return

	var damage : int = applyDamageOnHitComp._modifiedDamage.Value()
	var critBonus : float = applyDamageOnHitComp._modifiedCriticalHitBonus.Value()
	var emitCount : int = _gameObject.calculateModifiedValue("EmitCount", 1, [])
	var totalDamage : int = (remainingHits * damage * (1+critBonus) * ModifierValue)
	var myPosition : Vector2 = get_gameobjectWorldPosition()
	for locatorPool in LocatorPools:
		var hitObjs := Global.World.Locators.get_gameobjects_in_circle(locatorPool, myPosition, Radius)
		for hitObj in hitObjs:
			if hitObj == null or hitObj.is_queued_for_deletion():
				continue
			var healthComponent = hitObj.getChildNodeWithMethod("applyDamage")
			if healthComponent == null:
				continue
			var mySource : GameObject = _gameObject.get_rootSourceGameObject()
			var damageReturn = healthComponent.applyDamage(totalDamage, mySource, false, _weapon_index)
			if mySource != null and is_instance_valid(mySource):
				mySource.injectEmitSignal("DamageApplied", [DamageCategories, totalDamage, damageReturn, hitObj, false])
				if mySource != _gameObject:
					DamageApplied.emit(DamageCategories, totalDamage, damageReturn, hitObj, false)
	Fx.show_cone_wave(
		myPosition,
		Vector2.RIGHT,
		Radius,
		360, 3.0, 0.7,
		EffectColor,
		Callable(), null, 1.0,
		true)
