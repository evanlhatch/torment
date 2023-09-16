@tool
extends Node

@export var AbilityScenesFolder : String = "res://GameElements/Abilities"
@export var FetchAbilityScenes : bool:
	set(_value):
		fetch_scenes()
		notify_property_list_changed()

@export var GetWeaponIndices : bool:
	set(_value):
		get_weapon_indices()
		notify_property_list_changed()

@export var AbilityScenePaths : Array[String] = []


func fetch_scenes():
	if AbilityScenePaths == null: AbilityScenePaths = []
	var dir = DirAccess.open(AbilityScenesFolder)

	if dir:
		AbilityScenePaths.clear()
		dir.list_dir_begin()
		while true:
			var file_name = dir.get_next()
			if file_name == "": break
			elif !file_name.begins_with(".") and file_name.find(".tscn") >= 0:
				AbilityScenePaths.append(AbilityScenesFolder + "/" +file_name)
		dir.list_dir_end()
	else:
		printerr("Could not open folder: %s" % AbilityScenesFolder)


func sort_ascending(a, b):
	if a[0] < b[0]:
		return true
	return false


func get_weapon_indices():
	if not Engine.is_editor_hint(): return

	var output_string : String = ""
	var weapon_tuples = []

	# fetch ability names along with their weapon indices
	for abilityScenePath in AbilityScenePaths:
		var ability = load(abilityScenePath).instantiate()
		weapon_tuples.append([ability.WeaponIndex, ability.Name])
		ability.queue_free()
	weapon_tuples.sort_custom(sort_ascending)

	var unique_indices = []
	for entry in weapon_tuples:
		if entry[0] >= 0:
			if unique_indices.has(entry[0]):
				printerr("Duplicate weapon index found: '%d' - '%s'!" % entry)
			else:
				unique_indices.append(entry[0])
		output_string += "%d\t%s\n" % entry
	DisplayServer.clipboard_set(output_string)


func queue_resource_load():
	for ability_scene_path in AbilityScenePaths:
		ResourceLoaderQueue.queueResource(ability_scene_path)

func instantiate_abilities_children():
	for ability_scene_path in AbilityScenePaths:
		var ability_scene = ResourceLoaderQueue.getCachedResource(ability_scene_path)
		if ability_scene:
			add_child(ability_scene.instantiate())

func roll_ability_selection(abilityCount : int, minUpgradesInSelection : int, excludeAbilities : Array[Node]) -> Array[Node]:
	const maxBaseCount : int = 6
	var abilitySelection : Array[Node] = []
	var availableAbilities = get_tree().get_nodes_in_group("AvailableAbilities")
	var acquired_abilities = get_tree().get_nodes_in_group("AcquiredAbilities")

	if excludeAbilities.size() > 0:
		availableAbilities = availableAbilities.filter(func(abilityNode): return not excludeAbilities.has(abilityNode))

	# can't have more upgrades in our selection than actual choices
	if abilityCount < minUpgradesInSelection:
		minUpgradesInSelection = abilityCount

	# count the number of base abilities we already have
	var currentBaseCount = 0
	for ability in acquired_abilities:
		if ability.ExtendsAbilityWithWeaponIndex == -1:
			currentBaseCount += 1

	# split the available abilities into base and upgrade abilities
	var baseAbilities = []
	var upgradeAbilities = []
	for ability in availableAbilities:
		if ability.ExtendsAbilityWithWeaponIndex == -1:
			baseAbilities.append(ability)
		else:
			upgradeAbilities.append(ability)

	# before taking from all abilities, lets make sure we have the requrest amount of min. upgrades
	for i in minUpgradesInSelection:
		var count = len(upgradeAbilities)
		if count == 0:
			break
		var randomAbility = upgradeAbilities[randi_range(0, count - 1)]
		abilitySelection.push_front(randomAbility)
		availableAbilities.erase(randomAbility)
		upgradeAbilities.erase(randomAbility)

	# in case we have already the max. number of base abilities, we can only add upgrades
	# so we set the available abilities to the upgrade abilities
	if currentBaseCount >= maxBaseCount:
		availableAbilities = upgradeAbilities

	# now we can add the rest abilities from our pool
	for i in abilityCount - len(abilitySelection):
		var count = len(availableAbilities)
		if count == 0:
			break
		var randomAbility = availableAbilities[randi_range(0, count - 1)]
		abilitySelection.push_front(randomAbility)
		availableAbilities.erase(randomAbility)

	return abilitySelection


func get_ability_with_name(abilityName:String) -> Node:
	for child in get_children():
		if child.Name == abilityName:
			return child
	return null


func find_ability_with_weapon_index(weapon_index : int) -> Node:
	for i in get_children():
		if i.WeaponIndex == weapon_index:
			return i
	return null


func get_ability_name_from_weapon_index(weapon_index : int) -> String:
	if weapon_index < 100: return "DEFAULT WEAPON"
	var ability = find_ability_with_weapon_index(weapon_index)
	if ability: return ability.Name
	return "?UNKNOWN? ABILITY"

func get_ability_icon_from_weapon_index(weapon_index : int) -> Texture2D:
	if weapon_index < 100: return null
	var ability = find_ability_with_weapon_index(weapon_index)
	if ability: return ability.Icon
	return null

