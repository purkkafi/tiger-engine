class_name InGameContext extends VariableContext
# extends VariableContext with support for actions intended to be used by scripts


var game: TEGame
var view_result: Variant = null # result of last View or null


func _init(names: Array[String], values: Array[Variant], _game: TEGame):
	super._init(names, values)
	self.game = _game


# functions available for use in the control expression


func result() -> Variant:
	if view_result == null:
		push_error('result() called when last View did not produce a result')
	return view_result


func show_toast(title: String, description: String, icon = null):
	TE.send_toast_notification(title, description, icon)


func localize(id: String):
	return TE.localize[id]


# unlockables


func unlock(unlockable: String):
	TE.persistent.unlock(unlockable)


func is_unlocked(unlockable: String) -> bool:
	return TE.persistent.is_unlocked(unlockable)


# selectors that grant access to the Stage and its contents


func stage():
	return game.stage()


func bg():
	return game.stage().bg()


func fg():
	return game.stage().fg()


func sprite(sprite_id: String):
	return game.stage().find_sprite(sprite_id)
