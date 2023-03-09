class_name Options extends Resource
# game engine options read from the file 'assets/options.tef' at startup


# path to the title screen scene
var title_screen: String
# background color of various screens
var background_color: Color = Color.BLACK
# methods used to animate overlays in and out, default to nothing
# they should take a single Control as an argument and return null
# (to indicate no animation) or the Tween used
var animate_overlay_in: Callable = func(_overlay: Control) -> Variant: return null
var animate_overlay_out: Callable = func(_overlay: Control) -> Variant: return null
# callback that returns the game version or an empty string for none
# should take no arguments and return a String
var version_callback: Callable = func() -> String: return ''
