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
	popup.get_ok_button().text = TE.localize.general_ok
	
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
	popup.title = TE.localize['general_warning']
	popup.exclusive = true
	popup.get_ok_button().text = TE.localize['general_ok']
	popup.get_cancel_button().text = TE.localize['general_cancel']
	
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
	
	popup.connect('canceled', _remove_popup.bind(popup))
	popup.connect('confirmed', _remove_popup.bind(popup))
	
	return popup


static func _remove_popup(popup: AcceptDialog):
	popup.get_parent().remove_child(popup)
	popup.queue_free()


# standard popup for presenting the user arbitrary content
func info_dialog(title: String, content: Control) -> AcceptDialog:
	var popup: AcceptDialog = AcceptDialog.new()
	popup.unresizable = true
	popup.title = title
	popup.exclusive = true
	popup.get_ok_button().text = TE.localize['general_ok']
	
	var margins = MarginContainer.new()
	margins.add_child(content)
	popup.add_child(margins)
	
	add_shadow(popup)
	
	TE.current_scene.add_child(popup)
	popup.popup_centered_clamped()
	
	popup.connect('canceled', _remove_popup.bind(popup))
	popup.connect('confirmed', _remove_popup.bind(popup))
	
	return popup


# popup for showing the user an unrecoverable error
# the error consists of a GameError type and an optional extra message
# switches away from the current scene and shows the popup
# the user is given the option to return to the title screen by pressing OK
func error_dialog(game_error: TE.Error, extra_msg: String = ''):
	TE.switch_scene(
		preload('res://tiger-engine/ui/screens/TEErrorScreen.tscn').instantiate(),
		_display_error_dialog.bind(game_error, extra_msg),
		false
	)


func _display_error_dialog(old_scene: Node, game_error: TE.Error, extra_msg: String = ''):
	var label: RichTextLabel = RichTextLabel.new()
	label.custom_minimum_size = Vector2(800, 50)
	label.bbcode_enabled = true
	label.fit_content = true
	
	var error_type: String
	if extra_msg != '':
		extra_msg = '%s: %s' % [TE.localize.general_error, extra_msg]
	
	match game_error:
		TE.Error.BAD_SAVE:
			error_type = TE.localize.error_bad_save
		TE.Error.SCRIPT_ERROR:
			error_type = TE.localize.error_script
		TE.Error.FILE_ERROR:
			error_type = TE.localize.error_file
		TE.Error.ENGINE_ERROR:
			error_type = TE.localize.error_engine
		TE.Error.TEST_FAILED:
			error_type = 'TEST_FAILED'
		TE.Error.TEST_ERROR:
			error_type = 'TEST_ERROR'
		_:
			TE.log_warning('unknown game error shown: %s' % [game_error])
			error_type = 'ERROR ' + str(game_error)
	
	label.text = '[b][center]%s[/center][/b]%s' % [error_type, '\n\n'+extra_msg if extra_msg != '' else '']
	
	var dialog: AcceptDialog = info_dialog(TE.localize.general_error, label)
	dialog.connect('canceled', _to_titlescreen.bind(old_scene))
	dialog.connect('confirmed', _to_titlescreen.bind(old_scene))
	dialog.connect('custom_action', _custom_error_action.bind(old_scene))
	
	var ignore: Button = dialog.add_button(TE.localize.general_ignore, false, 'ignore')
	ignore.theme_type_variation = 'DangerButton'
	if TE.opts.bug_report_url != null:
		dialog.add_button(TE.localize.general_report, false, 'report')


func _to_titlescreen(old_scene: Node):
	old_scene.queue_free()
	var title_screen = load(TE.opts.title_screen).instantiate()
	TE.switch_scene(title_screen)


func _custom_error_action(action: String, old_scene: Node):
	match action:
		'ignore':
			TE.switch_scene(old_scene)
		'report':
			OS.shell_open(TE.opts.bug_report_url)
		_:
			push_error('unknown custom action in error dialog: %s' % action)


func add_shadow(to_node: Node):
	var shadow: ColorRect = ColorRect.new()
	shadow.position = Vector2(0, 0)
	shadow.size = Vector2(TE.SCREEN_WIDTH, TE.SCREEN_HEIGHT)
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shadow.color = TETheme.shadow_color
	shadow.z_index += 99
	
	TE.current_scene.add_child(shadow)
	to_node.connect('tree_exited', _remove_shadow.bind(shadow))


func _remove_shadow(shadow: ColorRect):
	shadow.get_parent().remove_child.call_deferred(shadow)
	shadow.queue_free()
