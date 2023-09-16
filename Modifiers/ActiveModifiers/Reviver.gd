extends GameObjectComponent

@export var AddPercentOfMaxHealth : float = 0.5
@export var InvincibleTimeAfterRevive : float = 1
@export var ApplyBlast : bool = true
@export var ReviveIcon : Texture2D
@export var ReviveText : String
@export var ReviveTitle : String
@export var RemoveNodeAfterRevive : bool = false
@export var UseThisReviveLast : bool = false

signal Revived

var _healthComp

func _enter_tree():
	initGameObjectComponent()
	if not _gameObject:
		return
	_healthComp = _gameObject.getChildNodeWithMethod("addCheatDeathCallable")
	if not _healthComp:
		printerr("Reviver needs the Health component to work!")
		return
	_healthComp.addCheatDeathCallable(revive, UseThisReviveLast)

func _exit_tree():
	if _healthComp != null && !_healthComp.is_queued_for_deletion():
		_healthComp.removeCheatDeathCallable(revive)
	_healthComp = null
	_gameObject = null

func revive():
	var modifiedReviveText : String = ReviveText
	for child in get_children():
		if child.is_queued_for_deletion():
			continue
		if child.has_method("modifyReviveTextBeforeRevive"):
			modifiedReviveText = child.modifyReviveTextBeforeRevive(modifiedReviveText)

	await GlobalMenus.reviveScreenUI.ShowReviveScreen(ReviveTitle, modifiedReviveText, ReviveIcon)

	var addhealth : int = ceil((_healthComp.get_maxHealth() * AddPercentOfMaxHealth) - 0.001)
	_healthComp.add_health(addhealth)
	if InvincibleTimeAfterRevive > 0:
		_healthComp.setInvincibleForTime(InvincibleTimeAfterRevive)
	if ApplyBlast:
		var pos = get_gameobjectWorldPosition()
		Forces.RadialBlast(pos, 180, 250, Forces.Falloff.Quadratic)
		Fx.show_revive(get_gameobjectWorldPosition(), Callable())
	Revived.emit()
	

	if RemoveNodeAfterRevive:
		queue_free()
