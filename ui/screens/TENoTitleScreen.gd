extends ColorRect


func _on_run_pressed():
	var script: ScriptFile = load(%ScriptPath.text)
	var game: TEGame = preload('res://tiger-engine/game/TEGame.tscn').instantiate()
	game.run_script(script)
	TE.switch_scene(game)
	
