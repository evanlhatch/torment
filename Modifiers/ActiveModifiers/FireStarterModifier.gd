extends GameObjectComponent

@export var SpawnBullet : PackedScene
@export var OnlyWithDamageCategories : Array[String] = ["DefaultWeapon"]
@export var BulletDamageFromBurnDamageMultiplier : float = 1
@export var EmitRadius : float = 16
@export var MinBullets : int = 1
@export var MaxBullets : int = 3

@export var Name : String
func get_modifier_name() -> String:
	return Name

var _damageModifier : Modifier

# we forward the damage of our bullets to our gameobject with this signal
signal DamageApplied(damageCategories:Array[String], damageAmount:float, applyReturn:Array, targetNode:GameObject, critical:bool)

func _ready():
	initGameObjectComponent()
	if _gameObject != null:
		_gameObject.connectToSignal("DamageApplied", damageWasApplied)
		_damageModifier = Modifier.create("Damage", _gameObject)
		_damageModifier.setName(Name)


func damageWasApplied(categories:Array[String], _damageAmount:float, applyReturn:Array, targetNode:GameObject, _isCritical:bool):
	if not OnlyWithDamageCategories.is_empty():
		var atLeastOneCategoryMatches : bool = false
		for damageCat in categories:
			if OnlyWithDamageCategories.has(damageCat):
				atLeastOneCategoryMatches = true
				break
		if not atLeastOneCategoryMatches:
			return

	var burnEffect = targetNode.find_effect("BURN")
	if burnEffect == null:
		return
	
	var targetPositionProvider : Node = targetNode.getChildNodeWithMethod("get_worldPosition")
	if targetPositionProvider == null:
		return
	
	var spawnCenter : Vector2 = targetPositionProvider.get_worldPosition()
	var bulletDamage : int = ceili(BulletDamageFromBurnDamageMultiplier * burnEffect.BurnDamage)

	var numBullets : int = randi_range(MinBullets, MaxBullets)
	var emitAngleRange : float = 2.0 * PI / numBullets
	for i in range(numBullets):
		var bullet : GameObject = SpawnBullet.instantiate()
		Global.attach_toWorld(bullet, false)
		
		var damageNode : Node = bullet.getChildNodeWithProperty("DamageAmount")
		if damageNode == null:
			printerr("FireStarterModifier expected a node with DamageAmount in the bullet, so that it can set the damage!")
		else:
			damageNode.DamageAmount = bulletDamage
		bullet.connectToSignal("ExternalDamageApplied", bulletDamageWasApplied)
		bullet.connectToSignal("DamageApplied", bulletDamageWasApplied)
		
		var emitDir = Vector2.from_angle(randf_range(i*emitAngleRange, (i+1)*emitAngleRange))
		var dirComponent = bullet.getChildNodeWithMethod("set_targetDirection")
		if dirComponent:
			dirComponent.set_targetDirection(emitDir)
		
		var posComponent = bullet.getChildNodeWithMethod("set_worldPosition")
		if posComponent:
			posComponent.set_worldPosition(
				spawnCenter + emitDir * EmitRadius)

func bulletDamageWasApplied(damageCategories:Array[String], damageAmount:float, applyReturn:Array, targetNode:GameObject, isCritical:bool):
	DamageApplied.emit(damageCategories, damageAmount, applyReturn, targetNode, isCritical)
