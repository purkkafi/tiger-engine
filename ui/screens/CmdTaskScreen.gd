extends ColorRect
# empty screen spawned when the game is launched to input something
# to the command line


# should take no args and return an int representing the exit code
# of the application
var task: Callable


func _ready():
	self.color = TETheme.background_color
	
	await get_tree().process_frame
	
	var return_code = task.call() as int
	TE.quit_game(return_code)
