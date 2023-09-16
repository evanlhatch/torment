extends GameObjectComponent2D

@export_group("Emission Parameters")
@export var EmitEverySeconds : float = 1
@export var EmitRadius : float = 0
@export var EmissionPosOffset : Vector2
@export var TargetSelectionRadius : float = 200
@export var TargetSelectionLocatorPool : String = "Enemies"
@export var ShootRandomWithoutTarget : bool = false
@export var ModifierCategories : Array[String] = ["Projectile"]

@export_group("UI Settings")
@export var ShowCooldownInHUD : bool = false

@export_group("Audio")
@export var Audio : AudioStreamPlayer

@export_group("Scene References")
@export var EmitScene : PackedScene
@export var BulletGroups : Array[StringName]

@export_group("Internal State")
@export var _weapon_index : int

var _bulletPrototype : GameObject

var _emitTimer : float
var _modifiedAttackSpeed
var _modifiedRange

# only use for the statistics. not very optimized...
func get_modified_values() -> Array:
	var allMods : Array = [
		_modifiedAttackSpeed,
		_modifiedRange
	]
	if _bulletPrototype != null:
		var bulletModNodes : Array = []
		_bulletPrototype.getChildNodesWithMethod("get_modified_values", bulletModNodes)
		for bulletModNode in bulletModNodes:
			allMods.append_array(bulletModNode.get_modified_values())
	return allMods


func _enter_tree():
	if _gameObject == null:
		var parent = get_parent()
		if parent and parent.has_method("get_weapon_index"):
			_weapon_index = parent.get_weapon_index()

func _ready():
	initGameObjectComponent()
	if not _gameObject:
		process_mode = PROCESS_MODE_DISABLED
		return
	process_mode = PROCESS_MODE_INHERIT
	_bulletPrototype = EmitScene.instantiate()
	_bulletPrototype.setInheritModifierFrom(_gameObject)
	var weapon_index_setter = _bulletPrototype.getChildNodeWithMethod("set_weapon_index")
	if weapon_index_setter != null: weapon_index_setter.set_weapon_index(_weapon_index)

	var bullet_modifier_nodes : Array = []
	_bulletPrototype.getChildNodesWithMethod("initialize_modifiers", bullet_modifier_nodes)
	for n in bullet_modifier_nodes: n.initialize_modifiers(self)
		
	_modifiedAttackSpeed = createModifiedFloatValue(1.0 / EmitEverySeconds, "AttackSpeed")
	_modifiedRange = createModifiedFloatValue(TargetSelectionRadius, "Range")
	_modifiedAttackSpeed.connect("ValueUpdated", attackSpeedWasUpdated)
	applyModifierCategories()
	attackSpeedWasUpdated(_modifiedAttackSpeed.Value(), _modifiedAttackSpeed.Value())

	_emitTimer = EmitEverySeconds
	for group in BulletGroups:
		_bulletPrototype.add_to_group(group)


func _exit_tree():
	_allModifiedValues.clear()
	_modifiedAttackSpeed = null
	_modifiedRange = null
	if _bulletPrototype != null:
		_bulletPrototype.queue_free()
		_bulletPrototype = null

func applyModifierCategories():
	_modifiedAttackSpeed.setModifierCategories(ModifierCategories)
	_modifiedRange.setModifierCategories(ModifierCategories)

func attackSpeedWasUpdated(_oldValue:float, newValue:float):
	EmitEverySeconds = 1.0 / newValue

func _process(delta):
	_emitTimer -= delta
	while _emitTimer <= 0:
		emit_with_passed_time(abs(_emitTimer))
		_emitTimer += EmitEverySeconds
	if _positionProvider:
		global_position = _positionProvider.get_worldPosition()

func emit_with_passed_time(passedTime : float) -> void:
	if _bulletPrototype:
		
		var targetPosition = get_targetPosition()
		if targetPosition == null:
			if not ShootRandomWithoutTarget:
				return
			targetPosition = Vector2(randf_range(-100, 100),randf_range(-100, 100))
		var emitDir = (targetPosition - get_gameobjectWorldPosition()).normalized()
		
		if Audio != null: Audio.play()
		var bullet : GameObject = Global.duplicate_gameObject_node(_bulletPrototype)
		bullet.set_sourceGameObject(_gameObject)
		Global.attach_toWorld(bullet, false)
		
		var dirComponent = bullet.getChildNodeWithMethod("set_targetDirection")
		if dirComponent:
			dirComponent.set_targetDirection(emitDir)
			
		var posComponent = bullet.getChildNodeWithMethod("set_worldPosition")
		if posComponent:
			posComponent.set_worldPosition(
				get_gameobjectWorldPosition() + EmissionPosOffset + emitDir * EmitRadius)
		
		var motionComponent = bullet.getChildNodeWithMethod("calculateMotion")
		if motionComponent:
			var motion = motionComponent.calculateMotion(passedTime)
			motionComponent.global_position += motion

func get_targetPosition():
	var targets = Global.World.Locators.get_gameobjects_in_circle(
		TargetSelectionLocatorPool, global_position, _modifiedRange.Value())
	var target = pick_random_safely(targets)
	var candidateCount = len(targets)
	if candidateCount > 0:
		while not is_instance_valid(target):
			targets.erase(target)
			candidateCount -= 1
			if candidateCount <= 0: return
			target = targets.pick_random()
	if target == null:
		return null
	var targetPosition = target.getChildNodeWithMethod("get_worldPosition")
	if targetPosition:
		return targetPosition.get_worldPosition()
	else:
		return null

func pick_random_safely(array:Array):
	var pick = null
	var array_length = len(array)
	while array_length > 0 and (pick == null or pick.is_queued_for_deletion()):
		var random_index:int = randi_range(0, array_length - 1)
		pick = array[random_index]
		if pick == null or pick.is_queued_for_deletion():
			array.remove_at(random_index)
			array_length = len(array)
	return pick

func get_cooldown_hud_flag() -> bool:
	return ShowCooldownInHUD

func get_cooldown_factor() -> float:
	return 1.0 - _emitTimer / EmitEverySeconds
