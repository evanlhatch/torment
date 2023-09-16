extends Resource
class_name WorldResource

@export var WorldName : String
@export var WorldImage : Texture2D
@export var LockedByQuestID : String
@export var LordQuestID : String
@export_file("*.tscn") var WorldScene : String
@export_file("*.tscn") var ItemPoolScene : String
@export_file("*.tscn") var TraitPoolScene : String
@export_file("*.tscn") var AbilityPoolScene : String


func queue_resource_load():
	ResourceLoaderQueue.queueResource(WorldScene)
	ResourceLoaderQueue.queueResource(ItemPoolScene)
	ResourceLoaderQueue.queueResource(TraitPoolScene)
	ResourceLoaderQueue.queueResource(AbilityPoolScene)


