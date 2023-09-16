extends GameObjectComponent

@export var ShownDialogue : QuestDialogue
@export var DestroyOnEvent : bool

signal DialogueDismissed

func _ready():
	initGameObjectComponent()
	_gameObject.connectToSignal("Touched", show_dialogue)


func show_dialogue():
	GlobalMenus.storyDialogueUI.set_dialogue(ShownDialogue)
	GameState.SetState(GameState.States.StoryDialogue)
	if DestroyOnEvent:
		_gameObject.queue_free()
	await GlobalMenus.storyDialogueUI.DialogueDismissed
	DialogueDismissed.emit()
