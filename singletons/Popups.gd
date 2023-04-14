extends Node
# utility class for spawning standard popups
# its functions return the created popup object
# TODO: add shadow ColorRect to the scene behind the popups
# (use same mechanism for overlays?)



# popup for entering text
# title is the window title, edit is the LineEdit to insert
func text_entry_dialog(title: String, edit: LineEdit) -> AcceptDialog:
	var popup: AcceptDialog = AcceptDialog.new()
	popup.unresizable = true
	popup.title = title
	popup.exclusive = true
	popup.get_ok_button().text = TE.ui_strings.general_ok
	
	var margins: MarginContainer = MarginContainer.new()
	margins.custom_minimum_size = Vector2(600, 0)
	margins.add_child(edit)
	popup.register_text_enter(edit)
	popup.add_child(margins)
	
	add_shadow(popup)
	
	TE.current_scene.add_child(popup)
	popup.popup_centered_clamped()
	edit.grab_focus()
	
	return popup


# popup for presenting a warning & making user choose between OK and cancel
func warning_dialog(msg: String) -> ConfirmationDialog:
	var popup: ConfirmationDialog = ConfirmationDialog.new()
	popup.unresizable = true
	popup.title = TE.ui_strings['general_warning']
	popup.exclusive = true
	popup.get_ok_button().text = TE.ui_strings['general_ok']
	popup.get_cancel_button().text = TE.ui_strings['general_cancel']
	
	var margins: MarginContainer = MarginContainer.new()
	var label: Label = Label.new()
	label.text = msg
	margins.add_child(label)
	popup.add_child(margins)
	
	add_shadow(popup)
	
	TE.current_scene.add_child(popup)
	popup.popup_centered_clamped()
	
	# make the less destructive option the default
	Callable(popup.get_cancel_button(), 'grab_focus').call_deferred()
	
	return popup


# standard popup for presenting the user arbitrary content
func info_dialog(title: String, content: Control) -> AcceptDialog:
	var popup: AcceptDialog = AcceptDialog.new()
	popup.unresizable = true
	popup.title = title
	popup.exclusive = true
	popup.get_ok_button().text = TE.ui_strings['general_ok']
	
	var margins = MarginContainer.new()
	margins.add_child(content)
	popup.add_child(margins)
	
	add_shadow(popup)
	
	TE.current_scene.add_child(popup)
	popup.popup_centered_clamped()
	
	return popup


# standard errors
enum GameError {
	BAD_SAVE, # save cannot be loaded
	SCRIPT_ERROR, # developer made a fucky wucky while writing the game script
	TEST_ERROR # error for debug purposes
}


# popup for showing the user an unrecoverable error
# switches away from the current scene and shows the popup
# the user is given the option to return to the title screen by pressing OK
func error_dialog(game_error: GameError) -> AcceptDialog:
	TE.switch_scene(preload('res://tiger-engine/ui/screens/TEErrorScreen.tscn').instantiate())
	await get_tree().process_frame
	var label: Label = Label.new()
	
	match game_error:
		GameError.BAD_SAVE:
			label.text = TE.ui_strings.error_bad_save
		GameError.SCRIPT_ERROR:
			label.text += TE.ui_strings.error_script
		GameError.TEST_ERROR:
			label.text = 'This is a test error. It should only be displayed for debug purposes.'
		_:
			TE.log_error('unknown game error shown: %s' % [game_error])
			label.text = str(game_error)
	
	var dialog: AcceptDialog = info_dialog(TE.ui_strings.general_error, label)
	dialog.connect('confirmed', Callable(self, '_to_titlescreen'))
	
	return dialog


func _to_titlescreen():
	var title_screen = load(TE.opts.title_screen).instantiate()
	TE.switch_scene(title_screen)


func add_shadow(to_node: Node):
	var shadow: ColorRect = ColorRect.new()
	shadow.position = Vector2(0, 0)
	shadow.size = Vector2(TE.SCREEN_WIDTH, TE.SCREEN_HEIGHT)
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shadow.color = TE.opts.shadow_color
	shadow.z_index += 99
	
	TE.current_scene.add_child(shadow)
	to_node.connect('canceled', Callable(self, '_remove_shadow').bind(shadow))
	to_node.connect('confirmed', Callable(self, '_remove_shadow').bind(shadow))


func _remove_shadow(shadow: ColorRect):
	shadow.get_parent().remove_child.call_deferred(shadow)
	shadow.queue_free()
