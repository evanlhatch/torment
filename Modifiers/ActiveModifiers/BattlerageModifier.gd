extends GameObjectComponent2D

@export var AddAttackSpeedPercentPerEntry : float = 0.02
@export var EntryLifetime : float = 2.0
@export var ModifierCap : float = 0.6

@export var Name : String
func get_modifier_name() -> String:
	return Name

var buff_entries : Array[float]
var _attackSpeedMod : Modifier

func _enter_tree():
	if buff_entries == null: buff_entries = []
	initGameObjectComponent()
	if _gameObject != null:
		Global.World.connect("DeathEvent", _on_death_event)
		_attackSpeedMod = Modifier.create("AttackSpeed", _gameObject)
		_attackSpeedMod.setName(Name)
		updateModifier()


func _exit_tree():
	if _gameObject != null && !_gameObject.is_queued_for_deletion():
		_gameObject = null
	if Global.World != null:
		if Global.World.is_connected("DeathEvent", _on_death_event):
			Global.World.disconnect("DeathEvent", _on_death_event)


func _on_death_event(_deadObject:GameObject, killedBy:GameObject):
	if killedBy == null:
		return
	var actualDamageSource = killedBy
	var rootSourceProvider = killedBy.getChildNodeWithMethod("get_rootSourceGameObject")
	if rootSourceProvider:
		var rootSource = rootSourceProvider.get_rootSourceGameObject()
		if rootSource: actualDamageSource = rootSource
	
	if actualDamageSource.is_in_group("FromPlayer"):
		buff_entries.append(EntryLifetime)
		updateModifier()

func _process(delta):
#ifdef PROFILING
#	updateBattlerage(delta)
#
#func updateBattlerage(delta):
#endif
	var buff_count = len(buff_entries)
	if (buff_count == 0): return
	for i in range(buff_count - 1, -1, -1):
		buff_entries[i] -= delta
		if buff_entries[i] <= 0.0:
			buff_entries.remove_at(i)
	if buff_count != len(buff_entries):
		updateModifier()

func updateModifier():
	var mul_mod : float = clamp(AddAttackSpeedPercentPerEntry * float(len(buff_entries)),
		0.0, ModifierCap)
	_attackSpeedMod.setMultiplierMod(mul_mod)
	_gameObject.triggerModifierUpdated("AttackSpeed")
	if mul_mod > 0:
		_mod_value_str = "%s%%" % ceili(mul_mod * 100.0)
	else:
		_mod_value_str = ""

func get_modifier_count() -> int:
	if buff_entries != null:
		return int(ceil(_attackSpeedMod.getMultiplierMod() * 100.0))
	return 0

@export_group("Modifier Info Area")
@export var Icon : Texture2D
@export_multiline var TooltipText : String = ""
var _mod_value_str : String = ""

func get_modifierInfoArea_icon() -> Texture2D:
	return Icon

func get_modifierInfoArea_cooldownfactor() -> float:
	if buff_entries.size() == 0:
		return 1
	return 1 - buff_entries[0] / EntryLifetime

func get_modifierInfoArea_active() -> bool:
	return not buff_entries.is_empty()

func get_modifierInfoArea_valuestr() -> String:
	return _mod_value_str

func get_modifierInfoArea_tooltip() -> String:
	return TooltipText

func get_modifierInfoArea_name() -> String:
	return Name
