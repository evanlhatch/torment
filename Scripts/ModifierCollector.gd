extends Control

@export var StatsTooltip : Control
@export_enum("Player Base Modifier", "Ability Modifier") var Type : int = 0

class ModifiedValueData:
	var BaseValue : float
	var FinalValue : float
	var Categories : Array[String]

	func _init(baseVal:float, finalVal:float, categories:Array[String]):
		BaseValue = baseVal
		FinalValue = finalVal
		Categories = categories
	
	func _to_string():
		return "B: %f  F: %f"%[BaseValue, FinalValue]

class ModifierData:
	var ModPercent : float
	var ModAdditive : float

	func _init(percent:float, additive:float):
		ModPercent = percent
		ModAdditive = additive
	
	func _to_string():
		return "%d%%, add:%s"%[ceili(ModPercent*100.0), ModAdditive]

func _ready():
	Global.WorldReady.connect(_on_world_ready)
	visibility_changed.connect(_on_visibility_changed)
	var entries = get_stat_entry_nodes()
	for e in entries:
		e.entered.connect(forward_tooltip_data)
		e.exited.connect(StatsTooltip.hide_tooltip)

func _on_world_ready():
	if Type == 0:
		Global.World.ItemPool.connect("InventoryChanged", update_stat_displays_with_base_modifier)

func forward_tooltip_data(statEntryNode:Node):
	StatsTooltip.set_tooltip(
		statEntryNode.get_stat_name(),
		statEntryNode,
		collectModifierWithType(Global.World.Player, statEntryNode.ModifierKey, statEntryNode.ModifierCategoriesOnly))


func collectBaseModifierOnGameObject(go:GameObject) -> Dictionary:
	var returnValue = {}
	var baseModNodes : Array = []
	go.getChildNodesWithMethod("is_character_base_node", baseModNodes)
	for baseModNode in baseModNodes:
		if not baseModNode.is_character_base_node():
			continue
		for baseMod in baseModNode.get_modified_values():
			if baseMod == null:
				continue
			if returnValue.has(baseMod.ModifiedBy()):
				returnValue[baseMod.ModifiedBy()].Categories.append_array(baseMod.getModifierCategories())
				#printerr("Character has more than one basevalue of %s"%baseMod.ModifiedBy())
			else:
				returnValue[baseMod.ModifiedBy()] = ModifiedValueData.new(
					float(baseMod.BaseValue()),
					float(baseMod.Value()),
					baseMod.getModifierCategories()
				)
	return returnValue


func collectModifiedValuesOnNodeList(nodeList:Array[Node]) -> Dictionary:
	var returnValue = {}
	for modNode in nodeList:
		if not modNode.has_method("get_modified_values"):
			continue
		for baseMod in modNode.get_modified_values():
			if baseMod == null:
				continue
			if returnValue.has(baseMod.ModifiedBy()):
				returnValue[baseMod.ModifiedBy()].Categories.append_array(baseMod.getModifierCategories())
			else:
				returnValue[baseMod.ModifiedBy()] = ModifiedValueData.new(
					float(baseMod.BaseValue()),
					float(baseMod.Value()),
					baseMod.getModifierCategories()
				)
	return returnValue


func collectModifierWithType(go:GameObject, modifierType:String, modifierCategoriesOnly:Array[String]) -> Dictionary:
	var modifierDict = {}
	var modifiers = go.getModifiers(modifierType, modifierCategoriesOnly)
	for mod in modifiers:
		var mod_percentage : float = mod.getMultiplierMod()
		var mod_additive : float = mod.getAdditiveMod()
		if mod_percentage != 0 or mod_additive != 0:
			var mod_name : String = mod.getName()
			if modifierDict.has(mod_name):
				modifierDict[mod_name].ModPercent += mod_percentage
				modifierDict[mod_name].ModAdditive += mod_additive
			else:
				modifierDict[mod_name] = ModifierData.new(mod_percentage, mod_additive)
	return modifierDict


func _on_visibility_changed():
	if not Global.is_world_ready() or Global.World.Player == null:
		return
	if Type == 0:
		update_stat_displays_with_base_modifier()
	StatsTooltip.hide_tooltip()

func update_stat_displays_with_base_modifier():
	await get_tree().process_frame
	var stats_data = collectBaseModifierOnGameObject(Global.World.Player)
	var entry_nodes = get_stat_entry_nodes()
	for e in entry_nodes:
		var key = e.get_modifier_key()
		if not stats_data.has(key):
			e.visible = false
			continue
		e.visible = true
		e.set_stat_data(stats_data[key])
		e.ModifierCategoriesOnly = stats_data[key].Categories
		e._on_mouse_exited()

func update_stat_displays_with_ability(abilityWeaponIndex:int):
	var allBestowedModifier : Array[Node]
	for ab in get_tree().get_nodes_in_group("AcquiredAbilities"):
		if ab.WeaponIndex == abilityWeaponIndex or ab.ExtendsAbilityWithWeaponIndex == abilityWeaponIndex:
			allBestowedModifier.append_array(ab.bestowed_modifiers)
	var stats_data = collectModifiedValuesOnNodeList(allBestowedModifier)
	var entry_nodes = get_stat_entry_nodes()
	for e in entry_nodes:
		var key = e.get_modifier_key()
		if not stats_data.has(key):
			e.visible = false
			continue
		e.visible = true
		e.set_stat_data(stats_data[key])
		# special handling for abilities: the ModifierCategories will
		# be overriden with those collected!
		e.ModifierCategoriesOnly = stats_data[key].Categories
		e._on_mouse_exited()

func hide_all_entry_nodes():
	var entry_nodes = get_stat_entry_nodes()
	for e in entry_nodes:
		e.visible = false
	
func get_stat_entry_nodes() -> Array:
	var fillArray = []
	var listOfNodesToSearch := get_children()
	var currentIndex : int = 0
	while currentIndex < listOfNodesToSearch.size():
		if listOfNodesToSearch[currentIndex].is_queued_for_deletion():
			currentIndex += 1
			continue
		if listOfNodesToSearch[currentIndex].has_method("set_stat_data"):
			fillArray.append(listOfNodesToSearch[currentIndex])
		else:
			listOfNodesToSearch.append_array(listOfNodesToSearch[currentIndex].get_children())
		currentIndex += 1
	return fillArray
