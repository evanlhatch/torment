extends Node

@export var UnlockedByQuestID : String
@export var UnlockKey : String = ""
@export var IsActiveWhenQuestUnlocked : bool = true
@export var SetActiveOnFirstUnlock : bool = true
@export var FirstTimeDelay : float = 0.0

signal FirstTimeUnlock(gating_node:Node)

var parent

func _ready():
	parent = get_parent()
	if ProjectSettings.get_setting("halls_of_torment/development/all_content_unlocked"):
		if ProjectSettings.get_setting("halls_of_torment/development/trigger_first_time_unlocks"):
			first_time_unlock()
		else:
			set_active(true and IsActiveWhenQuestUnlocked)
		return
	if Global.QuestPool.is_quest_complete(UnlockedByQuestID):
		if UnlockKey.length() > 0 and not Global.QuestPool.is_unlock_key_set(UnlockKey):
			first_time_unlock()
			Global.QuestPool.set_unlock_key(UnlockKey)
		else: set_active(IsActiveWhenQuestUnlocked)
	else: set_active(not IsActiveWhenQuestUnlocked)


func first_time_unlock():
	if SetActiveOnFirstUnlock:
		set_active(IsActiveWhenQuestUnlocked)
	if FirstTimeDelay <= 0.0: await get_tree().process_frame
	else: await get_tree().create_timer(FirstTimeDelay).timeout
	emit_signal("FirstTimeUnlock", self)


func set_active(active:bool):
	parent.visible = active
	parent.process_mode = PROCESS_MODE_PAUSABLE if active else PROCESS_MODE_DISABLED
