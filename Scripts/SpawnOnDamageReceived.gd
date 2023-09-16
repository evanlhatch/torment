extends GameObjectComponent

@export var SpawnScene : PackedScene
@export var MinSpawnDistance : float = 27
@export var MaxSpawnDistance : float = 54
@export var SpawnAmount : int = 3
@export var Cooldown : float = 5

# we forward the damage of our spawns to our gameobject with this signal
signal DamageApplied(damageCategories:Array[String], damageAmount:float, applyReturn:Array, targetNode:GameObject, critical:bool)

var _remainingCooldown : float = 0
var _timeSinceLastSpawn : float = 999
var _weapon_index : int = -1

# Called when the node enters the scene tree for the first time.
func _ready():
	initGameObjectComponent()
	if _gameObject != null:
		_gameObject.connectToSignal("ReceivedDamage", damageWasReceived)


func damageWasReceived(_amount:int, _byNode:Node, _wi:int):
	if _remainingCooldown > 0:
		return
	
	_remainingCooldown = Cooldown
	_timeSinceLastSpawn = 0

	var spawnCenter := get_gameobjectWorldPosition()
	var emitAngleRange : float = 2.0 * PI / SpawnAmount
	for i in range(SpawnAmount):
		var spawned : GameObject = SpawnScene.instantiate()
		spawned.set_sourceGameObject(_gameObject)
		spawned.setInheritModifierFrom(_gameObject)
		if _weapon_index != -1:
			for spawnChild in spawned.get_children():
				if "_weapon_index" in spawnChild:
					spawnChild._weapon_index = _weapon_index
		Global.attach_toWorld(spawned, false)
		
		spawned.connectToSignal("ExternalDamageApplied", bulletDamageWasApplied)
		spawned.connectToSignal("DamageApplied", bulletDamageWasApplied)
		
		var emitDir = Vector2.from_angle(randf_range(i*emitAngleRange, (i+1)*emitAngleRange))
		
		var posComponent = spawned.getChildNodeWithMethod("set_worldPosition")
		if posComponent:
			posComponent.set_worldPosition(
				spawnCenter + emitDir * randf_range(MinSpawnDistance, MaxSpawnDistance))


func bulletDamageWasApplied(damageCategories:Array[String], damageAmount:float, applyReturn:Array, targetNode:GameObject, isCritical:bool):
	DamageApplied.emit(damageCategories, damageAmount, applyReturn, targetNode, isCritical)


func _process(delta):
	_remainingCooldown -= delta
	_timeSinceLastSpawn += delta

@export_group("Modifier Info Area")
@export var Icon : Texture2D
@export var Name : String = "SpawnOnDamageReceived"
@export_multiline var TooltipText : String = ""

func get_modifierInfoArea_icon() -> Texture2D:
	return Icon

func get_modifierInfoArea_cooldownfactor() -> float:
	if _remainingCooldown <= 0: return 0
	return _remainingCooldown / Cooldown

func get_modifierInfoArea_active() -> bool:
	return _timeSinceLastSpawn < 0.5

func get_modifierInfoArea_valuestr() -> String:
	if _timeSinceLastSpawn < 0.0:
		return str(SpawnAmount)
	return ""

func get_modifierInfoArea_tooltip() -> String:
	return TooltipText

func get_modifierInfoArea_name() -> String:
	return Name
	
