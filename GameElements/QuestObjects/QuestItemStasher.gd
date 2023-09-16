extends GameObjectComponent

@export var QuestID : String = ""
@export var StashedItemID : String = ""

func _ready():
	initGameObjectComponent()
	Global.QuestPool.QuestCompleted.connect(_on_quest_completed)

func _on_quest_completed(quest:Node):
	if quest.ID == QuestID:
		Global.PlayerProfile["ItemStash"].append(StashedItemID)
		Global.savePlayerProfile(true)
