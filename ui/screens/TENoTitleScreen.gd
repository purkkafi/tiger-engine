extends ColorRect


func _ready():
	# populate screen with buttons used to run scripts
	if DirAccess.dir_exists_absolute('res://assets/scripts/'):
		var dir: DirAccess = DirAccess.open('res://assets/scripts/')
		for file in dir.get_files():
			var btn: Button = Button.new()
			btn.text = file
			btn.connect('pressed', _run_script.bind('res://assets/scripts/' + file))
			$VBox.add_child(btn)
	
	# stage editor button
	var se_btn: Button = Button.new()
	se_btn.text = 'Stage Editor'
	se_btn.connect('pressed', func(): TE.switch_scene(preload('res://tiger-engine/engine/StageEditor.tscn').instantiate()))
	$VBox.add_child(se_btn)


func _on_run_pressed():
	_run_script(%ScriptPath.text)


func _run_script(script_path: String):
	var script: ScriptFile = Assets.scripts.get_unqueued(script_path)
	var game: TEGame = preload('res://tiger-engine/game/TEGame.tscn').instantiate()
	game.run_script(script)
	TE.switch_scene(game)
	
