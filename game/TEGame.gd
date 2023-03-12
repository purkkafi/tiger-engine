class_name TEGame extends Control
# main class for running the game
# TODO keyboard input


var vm: TEScriptVM # virtual machine that runs the game script
var mouse_advancing: bool = false # whether game is being advanced by holding the mouse
# default views
var nvl_view = preload('res://tiger-engine/game/views/NVLView.tscn')
var adv_view = preload('res://tiger-engine/game/views/ADVView.tscn')


func _ready():
	Global.ui_strings.translate(self)
	MobileUI.initialize_gui(self)
	
	$VNControls.btn_quit.connect('pressed', Callable(self, '_quit'))
	
	start_game()


func start_game():
	vm = TEScriptVM.new(load('res://assets/scripts/the_other_island.tef').scripts['main'])
	next_blocking()


# advances to the next instruction that blocks the game, handling everything inbetween
func next_blocking():
	var instructions: Array = vm.to_next_blocking()
	
	for ins in instructions:
		if ins is TEScript.IPlaySong:
			TEAudio.play_song(ins.song_id, Global.definitions.transitions[ins.transition_id].duration)
			
		elif ins is TEScript.INvl:
			_replace_view(nvl_view.instantiate())
		
		elif ins is TEScript.IAdv:
			_replace_view(adv_view.instantiate())
		
		else:
			push_error('cannot handle non-blocking instruction: %s' % [ins])
	
	var blocking = vm.next_blocking()
	if blocking is TEScript.IPause:
		$View.pause(blocking.duration)
		
	elif blocking is TEScript.IBlock:
		$View.show_block(Global.get_block(blocking.blockfile_id, blocking.block_id))
		_unhide_ui()
		
	elif blocking is TEScript.IBG:
		var tween = $VNStage.set_background(blocking.bg_id, Global.definitions.transitions[blocking.transition_id])
		if tween != null:
			$View.wait_tween(tween)
			
	elif blocking is TEScript.IHideUI:
		var tween: Tween = _hide_ui(Global.definitions.transitions[blocking.transition_id].duration)
		$View.wait_tween(tween)
		
	else:
		push_error('cannot handle blocking instruction: %s' % [blocking])


func _replace_view(new_view: Node):
	var old_view: Node = $View
	
	var old_pos: int = get_children().find(old_view)
	remove_child(old_view)
	add_child(new_view)
	move_child(new_view, old_pos)
	
	new_view.name = old_view.name
	new_view.adjust_size($VNControls)
	if old_view is View:
		new_view.copy_state_from(old_view as View)
	
	old_view.queue_free()


func _hide_ui(duration: float) -> Tween:
	var tween = create_tween()
	
	tween.tween_property($VNControls, 'modulate:a', 0.0, duration)
	tween.parallel().tween_property($View, 'modulate:a', 0.0, duration)
	
	return tween


func _unhide_ui():
	$VNControls.modulate.a = 1.0
	$View.modulate.a = 1.0


func _process(delta):
	# hack for some weird bullshit!	
	# sometimes end of 'game_advance_mouse' is not detected properly
	# this should help
	# TODO: was from old Godot 3 version, might be fixed now?
	if mouse_advancing and !Input.is_action_pressed('game_advance_mouse'):
		mouse_advancing = false
	
	if Input.is_action_pressed('game_advance_keys') or mouse_advancing:
		$View.game_advanced(delta)
	else:
		$View.game_not_advanced(delta)
	
	if $View.is_next_block_requested():
		next_blocking()
		return
		
	if $View.is_next_line_requested():
		$View.next_line()
		return
	
	$View.update_state(delta)


# detect if mouse is held to advance the game
func _gui_input(event):
	if event.is_action_pressed('game_advance_mouse'):
		mouse_advancing = true
	if event.is_action_released('game_advance_mouse'):
		mouse_advancing = false


func _quit():
	var popup = TEPopups.warning_dialog(Global.ui_strings['game_quit_game'])
	popup.get_ok_button().connect('pressed', Callable(self, '_do_quit'))


func _do_quit():
	get_tree().quit()
