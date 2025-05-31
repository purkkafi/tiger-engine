class_name CutsceneView extends View
# plays a cutscene, which is a Node2D with an autoplaying AnimationPlayer
# as a child


var path: String = '' # the full path to the scene
var cutscene: Node2D
var is_finished: bool
var wait_input: bool = false # if true, user must advance at end & can be skipped with speedup
var stop_music: bool = true # if true, previous song is stopped
var custom_options: Dictionary[String, String] = {} # custom options
var waiting_for_input: bool = true
var anim_player: AnimationPlayer
var was_playing_before_pause: bool
var pause_position: float


func parse_options(tags: Array[Tag]):
	for tag in tags:
		match tag.name:
			'path':
				path = tag.get_string()
			'wait_input':
				wait_input = tag.get_string() == 'true'
			'stop_music':
				stop_music = tag.get_string() == 'true'
			_:
				custom_options[tag.name] = tag.get_string()


func initialize(_ctxt: InitContext):
	cutscene = Assets.noncached.get_resource(path).instantiate()
	anim_player = cutscene.get_node('AnimationPlayer') as AnimationPlayer
	
	if anim_player == null:
		TE.log_error(TE.Error.FILE_ERROR,
			"root of cutscene '%s' does not have an AnimationPlayer as child" % path)
	
	anim_player.connect('animation_finished', func(_unused): check_finished())
	
	TE.overlay_opened.connect(_pause_on_overlay)
	TE.overlay_closed.connect(_resume_after_overlay)
	
	if stop_music:
		TE.audio.play_song('', 0) # stop previous song, if any
	
	if len(custom_options) != 0:
		if 'set_custom_options' in cutscene:
			cutscene.set_custom_options(custom_options)
		else:
			TE.log_error(TE.Error.SCRIPT_ERROR,
				"unsupported custom options to cutscene '%s%': %s" % [path, custom_options])
	
	add_child(cutscene)
	game.save_rollback()


func _pause_on_overlay():
	if 'dont_pause_on_overlay' in cutscene and cutscene.dont_pause_on_overlay:
		return
	
	was_playing_before_pause = anim_player.is_playing()
	if was_playing_before_pause:
		pause_position = anim_player.current_animation_position
		anim_player.pause()
		if '_pause' in cutscene:
			cutscene._pause()


func _resume_after_overlay():
	if 'dont_pause_on_overlay' in cutscene and cutscene.dont_pause_on_overlay:
		return
	
	if was_playing_before_pause:
		anim_player.seek(0)
		anim_player.advance(pause_position)
		anim_player.play()
		if '_resume' in cutscene:
			cutscene._resume()


func check_finished():
	if len(cutscene.get_node('AnimationPlayer').get_queue()) == 0:
		is_finished = true


func _waiting_custom_condition() -> bool:
	if wait_input:
		return waiting_for_input
	else:
		return !is_finished


# hook into game_advanced to detech user input
func game_advanced(delta: float):
	super.game_advanced(delta)
	if is_finished:
		waiting_for_input = false


func _process(_delta):
	# if 'wait_input' is true, allow skipping entire animation with speedup
	if wait_input and self.speedup == Speedup.SPEEDUP:
		is_finished = true
		waiting_for_input = false


func _current_label():
	return null


func get_skip_mode():
	return View.SkipMode.PRESS


func skip_pressed():
	is_finished = true
	wait_input = false


func get_state() -> Dictionary:
	var savestate: Dictionary = super.get_state()
	savestate['cutscene_path'] = path
	savestate['wait_input'] = wait_input
	savestate['custom_options'] = custom_options
	return savestate


func from_state(savestate: Dictionary):
	path = savestate['cutscene_path']
	wait_input = savestate['wait_input']
	custom_options.clear()
	custom_options.merge(savestate['custom_options'])
	super.from_state(savestate)


func is_temporary() -> bool:
	return true


# do not hide anything with the hide button
func get_hidable_control():
	return null
