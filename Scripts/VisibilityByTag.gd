extends GameObjectComponent

@export var VisibleWhenTagActive : String

func _ready():
	initGameObjectComponent()
	Global.World.Tags.TagsUpdated.connect(_on_tags_updated)

func _on_tags_updated():
	var tag_active = Global.World.Tags.isTagActive(VisibleWhenTagActive)
	_gameObject.visible = tag_active
	_gameObject.process_mode = Node.PROCESS_MODE_PAUSABLE if tag_active else Node.PROCESS_MODE_DISABLED
