class_name CutsceneView extends View
# plays a cutscene, which is a Node2D with an autoplaying AnimationPlayer
# as a child


var path: String = '' # the full path to the scene
var cutscene: Node2D
var is_finished: bool


func parse_options(tags: Array[Tag], _ctxt: ControlExpr.GameContext):
	for tag in tags:
		match tag.name:
			'path':
				path = tag.get_string()
			_:
				TE.log_error('unknown argument for CutsceneView: %s' % tag)


func initialize(_ctxt: InitContext):
	cutscene = Assets.noncached.get_resource(path).instantiate()
	var anim_player = cutscene.get_node('AnimationPlayer')
	
	if anim_player == null:
		TE.log_error('root of cutscene "%s" does not have an AnimationPlayer as child' % path)
	
	anim_player.connect('animation_finished', func(_unused): check_finished())
	
	Audio.play_song('', 0) # stop previous song, if any
	add_child(cutscene)
	game.save_rollback()


func check_finished():
	if len(cutscene.get_node('AnimationPlayer').get_queue()) == 0:
		is_finished = true


func _waiting_custom_condition() -> bool:
	return !is_finished


func _current_label():
	return null


func _get_scene_path():
	return 'res://tiger-engine/game/views/CutsceneView.tscn'


func get_skip_mode():
	return View.SkipMode.PRESS


func skip_pressed():
	is_finished = true


func get_state() -> Dictionary:
	var savestate: Dictionary = super.get_state()
	savestate['cutscene_path'] = path
	return savestate


func from_state(savestate: Dictionary, ctxt: ControlExpr.GameContext):
	path = savestate['cutscene_path']
	super.from_state(savestate, ctxt)


func is_temporary() -> bool:
	return true
