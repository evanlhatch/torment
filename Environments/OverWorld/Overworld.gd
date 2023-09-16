extends Node2D

@export var Camera : Camera2D
@export var PlayerInput : Node
@export var InteractableObjectPaths : Array[NodePath]

var current_player_character : GameObject

signal PlayerCharacterSelected

func _ready():
	await Global.awaitInitialization()
	GlobalMenus.hudOverworld.update_hud()
	$Entrance.connect("body_entered", on_entrance_reached)
	#$Exit.connect("body_entered", on_exit_reached)
	for np in InteractableObjectPaths:
		var n = get_node(np)
		if n != null:
			connect_object_parts(n)
		else:
			for c in n.get_children():
				connect_object_parts(c)


func connect_object_parts(object:Node):
	for c in object.get_children():
		if c.has_signal("CharacterSelected"):
			c.CharacterSelected.connect(switch_player_character)
		if c.has_signal("HoverTextEntered"):
			c.HoverTextEntered.connect(on_hover_text_entered)
			c.HoverTextExited.connect(on_hover_text_exited)


func on_entrance_reached(_body:Node2D):
	if Global.WorldsPool.get_unlockedWorldsCount() > 1:
		GameState.SetState(GameState.States.RegisterOfHalls)
	else:
		Global.WorldsPool.enterSelectedWorld()

func on_exit_reached(_body:Node2D):
	OS.alert("You took a stumble on the stairs!", "Oops!")
	Global.quit_game()

func on_hover_text_entered(hoverText):
	GlobalMenus.hudOverworld.show_hover_text(hoverText)

func on_hover_text_exited(_hoverText):
	GlobalMenus.hudOverworld.show_hover_text("")

func switch_player_character(targetPlayerCharacter : GameObject):
	PlayerInput.get_parent().remove_child(PlayerInput)

	if current_player_character:
		var returnNode = current_player_character.getChildNodeWithMethod("return_to_bonfire")
		returnNode.return_to_bonfire(true)
		var selectionNode = current_player_character.getChildNodeWithMethod("set_isInPlayerControl")
		selectionNode.set_isInPlayerControl(false)

	current_player_character = targetPlayerCharacter
	current_player_character.add_child(PlayerInput)
	var positionProvider = current_player_character.getChildNodeWithMethod("get_worldPosition")

	Camera.reparent(positionProvider)

	PlayerInput.connectToNewParentGameObject()
	var selectionNode = current_player_character.getChildNodeWithMethod("set_isInPlayerControl")
	selectionNode.set_isInPlayerControl(true)

	var playerCharSceneProvider = current_player_character.getChildNodeWithMethod("get_playerCharacterScene")
	Global.ChosenPlayerCharacterScene = playerCharSceneProvider.get_playerCharacterScene()
	Global.ChosenPlayerCharacterIdentifier = playerCharSceneProvider.PlayerCharacterIdentifier

	if not Global.PlayerProfile.Loadouts.has(playerCharSceneProvider.PlayerCharacterIdentifier):
		# when this char doesn't have a loadout, yet, we'll just send an empty loadout
		Global.PlayerProfile.Loadouts[playerCharSceneProvider.PlayerCharacterIdentifier] = Patch.DEFAULT_PLAYER_PROFILE.Equipped
	# get the loadout for the current character:
	Global.PlayerProfile.Equipped = Global.PlayerProfile.Loadouts[playerCharSceneProvider.PlayerCharacterIdentifier].duplicate(true)
	# make sure the mark slot is present in the equipment data
	if not Global.PlayerProfile.Equipped.has("Mark"):
		Global.PlayerProfile.Equipped["Mark"] = ""


	var characterNameProvider = current_player_character.getChildNodeWithMethod("get_hover_text")
	GlobalMenus.itemStashUI.set_character_name(characterNameProvider.get_hover_text())

	var tween = create_tween()
	tween.tween_property(Camera, "position", Vector2.ZERO, 1.0).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	emit_signal("PlayerCharacterSelected")
	GlobalMenus.hudOverworld.onCharacterSelected()

	if GlobalMenus.title != null and not GlobalMenus.title.is_queued_for_deletion():
		GlobalMenus.title.dismiss()




# 🥕🥕🥕🥕🥕🥕
var r_sound = preload("res://Audio/AudioFXResources/RantSound.tres")
func _on_control_pressed(): FxAudioPlayer.play_sound_mono(r_sound, false, false, -8.0)
var fp_count : int
func _on_fire_pressed():
	fp_count += 1; if fp_count >= 5: fp_count = 0; do_spark(); if randf() < 0.4: do_fire()
func do_spark(): pass
func do_fire(): pass
