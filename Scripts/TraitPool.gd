@tool
extends Node

@export var GlossaryResource : Resource
@export var TraitScenesFolders : Array[String]= []
@export var TraitDataFolder : String = ""
@export var ApplyDataFromConfigs : bool = true
@export var FetchTraitScenes : bool:
	set(_value):
		fetch_scenes()
		notify_property_list_changed()

@export var TraitScenePaths : Array[String] = []
@export var IconBasePath : String = "res://Sprites/Icons/Traits/"
@export var FrameBasePath : String = "res://Sprites/Icons/TraitFrames/"
@export var ModifierBasePath : String = "res://Modifiers/"

func fetch_scenes():
	var data = TraitDatabase.new()
	if ApplyDataFromConfigs and TraitDataFolder != "":
		data.load_from_path(TraitDataFolder)

	if TraitScenePaths == null: TraitScenePaths = []
	TraitScenePaths.clear()
	for d in TraitScenesFolders:
		var dir = DirAccess.open(d)
		if dir:
			dir.list_dir_begin()
			while true:
				var file_name = dir.get_next()
				if file_name == "": break
				elif !file_name.begins_with(".") and file_name.find(".tscn") >= 0:
					TraitScenePaths.append(d + "/" +file_name)
					if ApplyDataFromConfigs: update_trait_data(data, file_name, d + "/" +file_name)
			dir.list_dir_end()
		else:
			printerr("Could not open folder: %s" % d)


func update_trait_data(data : TraitDatabase, file_name : String, full_path : String):
	var item = data.get_item(file_name)
	if item != null:
		var node : Node = load(full_path).instantiate()
		for key in item.keys():
			if key == data.id_name or key == data.entry_name: continue
			if key == "Name":
				node.name = item[key]
			if key == "Icon":
				var img = load(IconBasePath+item[key])
				if img != null:
					node.set(key, img)
				continue
			if key == "Frame":
				var img = load(FrameBasePath+item[key])
				if img != null:
					node.set(key, img)
				continue
			if key == "Modifiers":
				for child in node.get_children():
					node.remove_child(child)
					child.free()
				for mod in item[key]:
					if mod.File == null: continue
					var mod_node : Node = load(ModifierBasePath+mod.File).instantiate()
					if mod_node:
						for mod_key in mod.keys():
							if mod_key == "File": continue
							mod_node.set(mod_key, mod[mod_key])
						node.add_child(mod_node)
						mod_node.set_owner(node)
				continue
			node.set(key, item[key])
		var scene = PackedScene.new()
		var result = scene.pack(node)
		if result == OK:
			ResourceSaver.save(scene, full_path)
		else:
			printerr("Could not save scene: %s" % full_path)


func queue_resource_load():
	for ts in TraitScenePaths:
		ResourceLoaderQueue.queueResource(ts)

func instantiate_traits_children():
	for ts in TraitScenePaths:
		var trait_scene = ResourceLoaderQueue.getCachedResource(ts)
		if trait_scene and trait_scene.can_instantiate():
			var trait_instance = trait_scene.instantiate()
			if trait_instance:
				add_child(trait_instance)

func roll_trait_selection(traitCount : int, excludeTraits : Array[Node]) -> Array[Node]:
	var traitSelection : Array[Node] = []
	var availableTraits = get_tree().get_nodes_in_group("AvailableTraits")
	if excludeTraits.size() > 0:
		availableTraits = availableTraits.filter(func(traitNode): return not excludeTraits.has(traitNode))

	if Global.is_world_ready():
		var index = 0
		while index < availableTraits.size():
			if not availableTraits[index].is_available_for_level(Global.World.Level):
				availableTraits.remove_at(index)
				index -= 1
			index += 1

	for i in traitCount:
		var count = len(availableTraits)
		if count == 0:
			break
		var randomTrait = availableTraits[randi_range(0, count - 1)]
		traitSelection.append(randomTrait)
		availableTraits.erase(randomTrait)
	return traitSelection

func get_trait_with_name(traitName:String) -> Node:
	for child in get_children():
		if child.Name == traitName:
			return child
	return null

func banish_trait(traitNode:Node):
	var category : String = traitNode.Category
	if category == null or category.is_empty():
		if traitNode.is_in_group("AvailableTraits"): traitNode.remove_from_group("AvailableTraits")
		if not traitNode.is_in_group("BanishedTraits"): traitNode.add_to_group("BanishedTraits")
		return

	for child in get_children():
		if child.Category == category:
			if child.is_in_group("AvailableTraits"): child.remove_from_group("AvailableTraits")
			if not child.is_in_group("BanishedTraits"): child.add_to_group("BanishedTraits")
