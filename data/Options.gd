class_name Options extends Resource
# game engine options read from the file 'assets/options.tef' at startup


# path to the title screen scene
var title_screen: String
# color of TEInitScreen's background, default to black
var init_color: Color = Color.BLACK
# default theme of the game
var default_theme: Theme
# methods used to animate overlays in and out, default to nothing
# they should return null (to indicate no animation) or the Tween used
var animate_overlay_in: Callable = func(overlay): return null
var animate_overlay_out: Callable = func(overlay): return null
