extends CanvasLayer


func _ready():
	%ErrorBox.visible = false
	await Global.awaitPlatformInit()
	if Global.PlatformInitResult != Global.PlatformInitResults.SteamworksActive:
		# todo: show error message and then quit.
		printerr("Steam failed to initialize! Message: %s"%Global.PlatformInitMessage)
		%QuitButton.pressed.connect(_on_quit_clicked)
		%ErrorBox.visible = true
	else:
		await Global.awaitInitialization()
		ResourceLoaderQueue.queueResource("res://Environments/OverWorld/Overworld.tscn")
		await ResourceLoaderQueue.waitForLoadingFinished()
		get_tree().change_scene_to_file("res://Environments/OverWorld/Overworld.tscn")


func _on_quit_clicked():
	get_tree().quit()
