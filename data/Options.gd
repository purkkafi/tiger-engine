class_name Options extends Resource
# game engine options read from the file 'assets/options.tef' at startup


# path to the title screen scene
var title_screen: String = 'res://tiger-engine/ui/screens/TENoTitleScreen.tscn'
# methods used to animate overlays in and out, default to nothing
# they should take a single Control as an argument and return null
# (to indicate no animation) or the Tween used
var animate_overlay_in: Callable = func(_overlay: Control) -> Variant: return null
var animate_overlay_out: Callable = func(_overlay: Control) -> Variant: return null
# methods used to animate shadows in and out similarly
var animate_shadow_in: Callable = func(_shadow: ColorRect) -> Variant: return null
var animate_shadow_out: Callable = func(_shadow: ColorRect) -> Variant: return null
# callback that returns the game version or an empty string for none
# should take no arguments and return a String
var version_callback: Callable = func() -> String: return ''
# dict of custom view ids to paths of the View scenes
var custom_views: Dictionary = {}
# the id of the game's default theme; if null, the engine default theme is used
var default_theme: String
