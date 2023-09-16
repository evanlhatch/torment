extends GameObjectComponent

@export var ShadowPatchScene : PackedScene
@export var SpawnInterval : float = 5.0
@export var DelayPerSpawn : float = 0.2
@export var SpawnCount : float = 2
@export var MinRange : float = 70.0
@export var MaxRange : float = 140.0

@export_group("Modifier Settings")
@export var UseMultihitModifier : bool = false
@export var UseAttackSpeedModifier : bool = false
@export var ModifierCategories : Array[String] = ["Magic"]

@export_group("internal state")
@export var _weapon_index : int = -1

signal DamageApplied(damageCategories:Array[String], damageAmount:float, applyReturn:Array, targetNode:GameObject, critical:bool)


var _emit_overflow : float
var _spawn_timer : float

var _bulletPrototype : GameObject
@onready var shadow_patches:Array[GameObject] = []

var _modifiedSpawnCount
var _modifiedSpeed


# only use for the statistics. not very optimized...
func get_modified_values() -> Array:
	var allMods : Array = [
		_modifiedSpawnCount,
		_modifiedSpeed
	]
	if _bulletPrototype != null:
		var bulletModNodes : Array = []
		_bulletPrototype.getChildNodesWithMethod("get_modified_values", bulletModNodes)
		for bulletModNode in bulletModNodes:
			allMods.append_array(bulletModNode.get_modified_values())
	return allMods


func _enter_tree():
	initGameObjectComponent()
	if _gameObject:
		Global.World.connect("PlayerDied", clean_up)
		if _bulletPrototype == null:
			_bulletPrototype = ShadowPatchScene.instantiate()
			_bulletPrototype.setInheritModifierFrom(_gameObject)
			if "_weapon_index" in _bulletPrototype:
				_bulletPrototype._weapon_index = _weapon_index
		_modifiedSpeed = createModifiedFloatValue(1.0 / SpawnInterval, "AttackSpeed")
		_modifiedSpawnCount = createModifiedFloatValue(SpawnCount, "EmitCount")
	else:
		var parent = get_parent()
		if parent and (parent is Item or parent is Ability):
			_weapon_index = parent.WeaponIndex


func setBulletPrototype(newPrototypeScene : PackedScene):
	_bulletPrototype = newPrototypeScene.instantiate()
	_bulletPrototype.setInheritModifierFrom(_gameObject)
	if "_weapon_index" in _bulletPrototype:
		_bulletPrototype._weapon_index = _weapon_index


func applyModifierCategories():
	_modifiedSpeed.setModifierCategories(ModifierCategories)
	_modifiedSpawnCount.setModifierCategories(ModifierCategories)

func _exit_tree():
	clean_up();

func _process(delta):
	if _gameObject == null: return
	_spawn_timer -= delta
	if _spawn_timer <= 0:
		_spawn_timer += get_totalSpawnInterval()
		spawn()

func spawn():
	for i in get_totalSpawnCount():
		var spawnedObject : GameObject = Global.duplicate_gameObject_node(_bulletPrototype)
		spawnedObject.set_sourceGameObject(_gameObject)
		Global.attach_toWorld(spawnedObject)
		spawnedObject.connectToSignal("Expired", _on_shadow_patch_expired)
		var posComponent = spawnedObject.getChildNodeWithMethod("set_worldPosition")
		if posComponent:
			var spawnPos = _positionProvider.get_worldPosition()
			spawnPos += Vector2(randf() - .5, randf() - .5).normalized() * randf_range(MinRange, MaxRange)
			spawnedObject.global_position = spawnPos
			posComponent.set_worldPosition(spawnPos)
		shadow_patches.append(spawnedObject)
		await get_tree().create_timer(DelayPerSpawn / get_attackSpeedFactor(), false).timeout

func get_totalAttackSpeed() -> float:
	return _modifiedSpeed.Value()

func get_totalSpawnInterval() -> float:
	if UseAttackSpeedModifier:
		return 1.0 / get_totalAttackSpeed()
	return SpawnInterval

var _spawn_overflow : float
func get_totalSpawnCount() -> int:
	if UseMultihitModifier:
		_spawn_overflow += _modifiedSpawnCount.Value()
		var spawn_count = floor(_spawn_overflow)
		_spawn_overflow -= spawn_count
		return spawn_count
	return round(SpawnCount)

func get_attackSpeedFactor() -> float:
	return get_totalAttackSpeed() / (1.0 / SpawnInterval)


func clean_up():
	if _bulletPrototype != null:
		_bulletPrototype.queue_free()
		_bulletPrototype = null
	if _gameObject:
		Global.World.disconnect("PlayerDied", clean_up)
		_gameObject = null
	for p in shadow_patches:
		p.disconnectFromSignal("Expired", _on_shadow_patch_expired)
		var killer : Node = p.getChildNodeWithMethod("kill")
		if killer != null:
			killer.kill()
		else:
			p.queue_free()
	shadow_patches.clear()

func _on_shadow_patch_expired(shadow_patch:Node):
	shadow_patches.erase(shadow_patch)


@export_group("Modifier Info Area")
@export var Icon : Texture2D
@export var Name : String = "Shadow Patch"
@export_multiline var TooltipText : String = ""

func get_modifierInfoArea_icon() -> Texture2D:
	return Icon

func get_modifierInfoArea_cooldownfactor() -> float:
	return _spawn_timer / get_totalSpawnInterval()

func get_modifierInfoArea_tooltip() -> String:
	return TooltipText

func get_modifierInfoArea_name() -> String:
	return Name

func get_cooldown_factor() -> float:
	return 1.0 - _spawn_timer / get_totalSpawnInterval()
