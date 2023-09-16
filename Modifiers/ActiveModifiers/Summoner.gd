extends GameObjectComponent

## has to have a SummonInput child!
@export var SummonScenes : Array[PackedScene]
@export var MaxActiveSummons : int = 1
@export var RespawnTime : float = -1
@export var StaggerInitialSpawns : float = 0.5
@export var SpawnRange : float = 200
## the GlobalRespawnTime tries to spawn a new summon, ignoring the
## individual RespawnTime. (for more of a frequency based spawning)
@export var GlobalRespawnTime : float = -1
@export var EmissionCount : float = 1
@export var ShowAbilityBar : bool = false

@export_group("internal state")
@export var _weapon_index : int = -1


@export_group("Modifier Settings")
@export var UseEmitCount : bool = false
@export var ModifierCategories : Array[String] = ["Summon"]

var _modifiedEmitCount
var _remainingSummons : float = 0

signal SummonWasSummoned(summonGameObject:GameObject)

class SummonData:
	var summonGameObject:GameObject
	var remainingTimeToSpawn:float

var _summonSlots:Array[SummonData]
var _remainingGlobalRespawnTime : float
var _summon_count : int

# only use for the statistics. not very optimized...
func get_modified_values() -> Array:
	var allMods : Array
	# only thing we can do here: we'll collect the
	# modifier of the currently active summons.
	# (the only summon ability that needs the modifier currently
	# is the golem and that always has a summon active)
	for summonSlot in _summonSlots:
		if summonSlot.summonGameObject == null:
			continue
		var modValueNodes : Array = []
		summonSlot.summonGameObject.getChildNodesWithMethod("get_modified_values", modValueNodes)
		for modNode in modValueNodes:
			allMods.append_array(modNode.get_modified_values())
		return allMods
	return allMods

func _enter_tree():
	initGameObjectComponent()
	if _gameObject == null:
		return
	_summonSlots = []
	_remainingGlobalRespawnTime = GlobalRespawnTime

	_modifiedEmitCount = createModifiedFloatValue(EmissionCount, "ObjectCount")
	_modifiedEmitCount.ValueUpdated.connect(emitCountWasChanged)
	applyModifierCategories()

	for i in range(MaxActiveSummons):
		var summonData:SummonData = SummonData.new()
		summonData.remainingTimeToSpawn = i * StaggerInitialSpawns
		_summonSlots.append(summonData)

func transformCategories(onlyWithDamageCategory:String, addModifierCategories:Array[String], removeModifierCategories:Array[String], addDamageCategories:Array[String], removeDamageCategories:Array[String]):
	for summon in _summonSlots:
		if summon.summonGameObject == null || summon.summonGameObject.is_queued_for_deletion():
			continue
		var summonTransformComps : Array = []
		summon.summonGameObject.getChildNodesWithMethod("transformCategories", summonTransformComps)
		for summonTransformComp in summonTransformComps:
			summonTransformComp.transformCategories(onlyWithDamageCategory, addModifierCategories, removeModifierCategories, addDamageCategories, removeDamageCategories)


func applyModifierCategories():
	_modifiedEmitCount.setModifierCategories(ModifierCategories)

func emitCountWasChanged(valueBefore:float, valueNow:float):
	if not UseEmitCount:
		return
	var targetMaxSummons : int = roundi(get_totalEmitCount() / EmissionCount * float(MaxActiveSummons))
	if targetMaxSummons > _summonSlots.size():
		for i in range(targetMaxSummons - _summonSlots.size()):
			var summonData:SummonData = SummonData.new()
			summonData.remainingTimeToSpawn = i * StaggerInitialSpawns
			_summonSlots.append(summonData)
	elif targetMaxSummons < _summonSlots.size():
		for i in range(_summonSlots.size() - targetMaxSummons):
			var summon = _summonSlots.pop_back()
			if summon.summonGameObject == null || summon.summonGameObject.is_queued_for_deletion():
				continue
			var killable = summon.summonGameObject.getChildNodeWithMethod("instakill")
			if killable != null:
				killable.instakill()

func _exit_tree():
	if _gameObject == null || _gameObject.is_queued_for_deletion():
		return

	for summon in _summonSlots:
		if summon.summonGameObject == null || summon.summonGameObject.is_queued_for_deletion():
			continue
		var killable = summon.summonGameObject.getChildNodeWithMethod("instakill")
		if killable != null:
			killable.instakill()
	_summonSlots = []
	_summon_count = 0
	_gameObject = null

func _process(delta):
	if _gameObject == null:
		return
	var doGlobalSpawn : bool = false
	if GlobalRespawnTime > 0:
		_remainingGlobalRespawnTime -= delta
		if _remainingGlobalRespawnTime <= 0:
			doGlobalSpawn = true
			_remainingSummons += get_totalEmitCount()

	for summon in _summonSlots:
		if summon.summonGameObject != null:
			continue

		if doGlobalSpawn or summon.remainingTimeToSpawn >= 0:
			summon.remainingTimeToSpawn -= delta
			if doGlobalSpawn or summon.remainingTimeToSpawn < 0:
				var spawnPosition:Vector2 = Vector2.ONE * (0.2 + 0.8 * randf())
				summon.summonGameObject = SummonScenes.pick_random().instantiate()
				summon.summonGameObject.set_sourceGameObject(_gameObject)
				summon.summonGameObject.setInheritModifierFrom(_gameObject, true)
				for summonGOChild in summon.summonGameObject.get_children():
					if "_weapon_index" in summonGOChild:
						summonGOChild._weapon_index = _weapon_index
				Global.attach_toWorld(summon.summonGameObject)
				var summonInputComp = summon.summonGameObject.getChildNodeWithMethod("set_summonedBy")
				if summonInputComp != null:
					summonInputComp.set_summonedBy(_gameObject)
				spawnPosition = spawnPosition.rotated(randf() * 2.0 * PI)
				spawnPosition *= SpawnRange
				spawnPosition += get_gameobjectWorldPosition()
				summon.summonGameObject.global_position = spawnPosition
				summon.summonGameObject.connectToSignal("Killed", summonWasKilled.bind(summon))
				summon.summonGameObject.connectToSignal("Instakilled", summonWasKilled.bind(summon))
				_remainingSummons -= 1
				if _remainingSummons < 1:
					doGlobalSpawn = false
				_remainingGlobalRespawnTime = GlobalRespawnTime
				_summon_count += 1
				SummonWasSummoned.emit(summon.summonGameObject)

	doGlobalSpawn = false
	_remainingSummons = fmod(_remainingSummons, 1.0)


func summonWasKilled(_killer:Node, summonData:SummonData):
	if _gameObject == null || _gameObject.is_queued_for_deletion():
		return
	summonData.remainingTimeToSpawn = RespawnTime
	summonData.summonGameObject = null
	_summon_count -= 1


func get_totalEmitCount() -> float:
	if UseEmitCount:
		return _modifiedEmitCount.Value()
	return EmissionCount


@export_group("Modifier Info Area")
@export var Icon : Texture2D
@export var Name : String = "Summoned Rats"
@export_multiline var TooltipText : String = ""

func get_modifierInfoArea_icon() -> Texture2D:
	return Icon

func get_modifierInfoArea_cooldownfactor() -> float:
	if GlobalRespawnTime > 0 and (MaxActiveSummons <= 1 or _summon_count < MaxActiveSummons):
		return _remainingGlobalRespawnTime / GlobalRespawnTime
	return 0.0

func get_modifierInfoArea_valuestr() -> String:
	if MaxActiveSummons > 1 and _summon_count > 0:
		return str(_summon_count)+"/"+str(_summonSlots.size())
	return ""

func get_modifierInfoArea_name() -> String:
	return Name

func get_modifierInfoArea_tooltip() -> String:
	return TooltipText

func set_maxActiveSummons(newMaxActiveSummons:int):
	var delta_count = newMaxActiveSummons - MaxActiveSummons
	if delta_count > 0:
		var index_offset : int = max(len(_summonSlots), 0)
		for i in range(MaxActiveSummons):
			var summonData:SummonData = SummonData.new()
			summonData.remainingTimeToSpawn = (i + index_offset) * StaggerInitialSpawns
			_summonSlots.append(summonData)
	MaxActiveSummons = newMaxActiveSummons
