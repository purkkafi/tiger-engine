class_name Options extends Resource
# game engine options read from the file 'assets/options.tef' at startup


# path to the title screen scene
var title_screen: String = 'res://tiger-engine/ui/screens/TENoTitleScreen.tscn'
# path to the splash screen scene (String) or null if none
var splash_screen: Variant = null
# callback that returns the game version or an empty string for none
# should take no arguments and return a String
var version_callback: Callable = func() -> String: return ''
# unlockable namespaces that show a toast notification when unlocked
var notify_on_unlock: Array[String] = []
# dict of custom view ids to paths of the View scenes
var custom_views: Dictionary = {}
var custom_sprite_objects: Dictionary = {}
# the id of the game's default theme; if null, the engine default theme is used
var default_theme: Variant = null
# url for reporting bugs from the error dialog (String)
# if null, the option to do so will not be shown to the user
var bug_report_url: Variant = null
# path to scene (String) containing custom controls that will shop up in-game
var ingame_custom_controls: Variant = null
# dict of vfx ids to paths of scripts
var vfx_registry: Dictionary = {}
