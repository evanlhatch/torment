@tool
extends Resource
class_name QuestDialogue

@export_group("Dialogue Data")
@export var Title : String = "Dialogue Title"
@export_multiline var DialogueText : String = "Hello!"
@export var ButtonText : String = "Continue"
@export var DialogueAnimation : String = ""
@export var IdleAnimation : String = ""
@export var DialogueAudio : AudioStream
@export var FollowupGameState : GameState.States = GameState.States.InGame
@export var FollowupDialogue : QuestDialogue

@export_group("Progress Settings")
@export var SetTagsAfterDismiss : Array[String]
@export var RemoveTagsAfterDismiss : Array[String]


func _init():
	Title = "Dialogue Title"
	DialogueText = "Hello!"
	ButtonText = "Continue"
	DialogueAnimation = ""

func on_dismiss():
	if Global.is_world_ready() and SetTagsAfterDismiss != null:
		for tag in SetTagsAfterDismiss:
			Global.World.Tags.setTagActive(tag)
		if RemoveTagsAfterDismiss != null:
			Global.World.Tags.deactivateTags(RemoveTagsAfterDismiss)
