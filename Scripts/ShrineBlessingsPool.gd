@tool
extends Node

@export var BlessingScenesFolder : String ="res://GameElements/ShrineBlessings"
@export var FetchBlessingScenes : bool:
	set(_value):
		fetch_blessings()
@export var BlessingScenePaths : Array[String] = []

var Blessings : Array = []

func fetch_blessings():
	if BlessingScenePaths == null: BlessingScenePaths = []
	var dir = DirAccess.open(BlessingScenesFolder)

	BlessingScenePaths.clear()
	if dir:
		dir.list_dir_begin()
		while true:
			var file_name = dir.get_next()
			if file_name == "": break
			elif !file_name.begins_with(".") and file_name.find(".tscn") >= 0:
				BlessingScenePaths.append(BlessingScenesFolder + "/" +file_name)
		dir.list_dir_end()
		notify_property_list_changed()
	else:
		printerr("Could not open folder: %s" % BlessingScenesFolder)

func queue_resource_load():
	for blessingScenePath in BlessingScenePaths:
		ResourceLoaderQueue.queueResource(blessingScenePath)

func instantiate_item_children():
	for blessingScenePath in BlessingScenePaths:
		var blessingResource = ResourceLoaderQueue.getCachedResource(blessingScenePath)
		var blessing = blessingResource.instantiate()
		blessing.loadBlessingUnlockLevel()
		add_child(blessing)
		Blessings.append(blessing)

