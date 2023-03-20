extends ColorRect


func _ready():
	# populate screen with buttons used to run scripts
	if DirAccess.dir_exists_absolute('res://assets/scripts/'):
		var dir: DirAccess = DirAccess.open('res://assets/scripts/')
		for file in dir.get_files():
			var btn: Button = Button.new()
			btn.text = file
			btn.connect('pressed', Callable(self, '_run_script').bind('res://assets/scripts/' + file))
			$VBox.add_child(btn)


func _on_run_pressed():
	_run_script(%ScriptPath.text)


func _run_script(script_path: String):
	var script: ScriptFile = load(script_path)
	var game: TEGame = preload('res://tiger-engine/game/TEGame.tscn').instantiate()
	game.run_script(script)
	TE.switch_scene(game)
	
