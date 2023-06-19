class_name Options extends Resource
# game engine options read from the file 'assets/options.tef' at startup


# path to the title screen scene
var title_screen: String = 'res://tiger-engine/ui/screens/TENoTitleScreen.tscn'
# path to the splash screen scene or null if none
var splash_screen: String
# callback that returns the game version or an empty string for none
# should take no arguments and return a String
var version_callback: Callable = func() -> String: return ''
# dict of custom view ids to paths of the View scenes
var custom_views: Dictionary = {}
# the id of the game's default theme; if null, the engine default theme is used
var default_theme: String
