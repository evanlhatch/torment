extends GameObjectComponent

@export var FlameStrikeDamageCategory : String = "FlameStrike"
@export var FlameStrikeDamageMultiplier : float = 0.2
@export var AddDamageMultiplierFromBurnStacks : float = 0.2
@export var MinPushForce : float = 100
@export var MaxPushForce : float = 200
@export var MinRadius : float = 80
@export var MaxRadius : float = 160
@export var HitLocatorPools : Array[String] = ["Enemies"]
## NOTE: do NOT use the category from FlameStrikeDamageCategory here!
@export var DamageCategories : Array[String] = ["Fire"]

@export_group("Internal State")
@export var _weapon_index : int

signal DamageApplied(categories:Array[String], damageAmount:float, applyReturn:Array, targetNode:GameObject, critical:bool)

func _ready():
	initGameObjectComponent()
	if _gameObject == null:
		return
	_gameObject.connectToSignal("DamageApplied", damageWasApplied)


func damageWasApplied(categories:Array[String], damageAmount:float, applyReturn:Array, targetNode:GameObject, critical:bool):
	if not FlameStrikeDamageCategory in categories:
		return
	if targetNode == null or not is_instance_valid(targetNode):
		return

	var burnEffectOnTarget : Node = targetNode.find_effect("BURN")
	if burnEffectOnTarget == null:
		return

	var positionProvider = targetNode.getChildNodeWithMethod("get_worldPosition")
	if positionProvider == null:
		return
	var position : Vector2 = positionProvider.get_worldPosition()

	var numBurnStacks : int = burnEffectOnTarget._num_stacks
	var damageMultiplierFromBurnStacks : float = (numBurnStacks / 20.0) * AddDamageMultiplierFromBurnStacks
	var explosionDamage : int = ceili(damageAmount * (FlameStrikeDamageMultiplier + damageMultiplierFromBurnStacks))

	var radius : float = remap(numBurnStacks, 0.0, 20.0, MinRadius, MaxRadius)
	var pushForce : float = remap(numBurnStacks, 0.0, 20.0, MinPushForce, MaxPushForce)

	var hit_objects : Array = Forces.RadialBlast(position, radius, pushForce, Forces.Falloff.Linear, HitLocatorPools)

	var mySource : Node = _gameObject.get_rootSourceGameObject()

	for hitObj in hit_objects:
		var healthComponent = hitObj.getChildNodeWithMethod("applyDamage")
		if healthComponent == null:
			continue
		var damageReturn = healthComponent.applyDamage(explosionDamage, mySource, false, _weapon_index)
		DamageApplied.emit(DamageCategories, explosionDamage, damageReturn, hitObj, false)

	if not targetNode.is_queued_for_deletion():
		burnEffectOnTarget.queue_free()

	Fx.show_cone_wave(
		position,
		Vector2.RIGHT,
		radius * 0.6,
		360,
		3.0,
		1.0,
		Color.ORANGE_RED,
		Callable(), null, 1.0,
		true)

