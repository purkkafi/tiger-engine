class_name AnimatedCG extends RefCounted
# TODO refactor into a Resource
# and move animation code here

var duration: float # duration of this CG in seconds
var loop: bool # whether the animation loops or not
var layers: Array = [] # array of ACGLayer


func _init(values: Array):
	for val in values[0]:
		if val is Tag.Break or val is String:
			continue
		match val.name:
			'duration':
				duration = float(val.args[0][0].trim_suffix('s'))
			'loop':
				loop = true if val.args[0][0] == 'true' else false
			'layer':
				layers.append(ACGLayer.new(val.args, duration))
			_:
				push_error('Unknown ACG value: ' + val.name)


class ACGLayer extends RefCounted:
	var path: String # the path to the texture of this layer relative to the bg folder
	var transforms: Dictionary = {} # dict of property paths to ACGTransforms to apply to them
	
	
	func _init(args: Array, duration: float):
		self.path = args[0][0]
		
		for arg in args[1]:
			if arg is Tag.Break or arg is String:
				continue
			match arg.name:
				'x':
					transforms[':position:x'] = ACGTransform.new(arg.args, duration, 'px', 1920) #Util.SCREEN_WIDTH
				'y':
					transforms[':position:y'] = ACGTransform.new(arg.args, duration, 'px', 1080) #Util.SCREEN_HEIGHT)
				'a':
					transforms[':modulate:a'] = ACGTransform.new(arg.args, duration, 'alpha', 1)
				_:
					push_error('Unknown ACGLayer arg: ' + arg.name)


class ACGTransform extends RefCounted:
	var frames: Array = [] # keyframes of Arrays of form [time, value]
	var ease_curve = 1.0
	
	
	func _init(args: Array,duration: float,unit_suffix: String,unit_scale: float):
		for arg in args[0]:
			if arg is Tag.Break or arg is String:
				continue
			match arg.name:
				'at':
					frames.append([AnimatedCG.unit_copy(arg.args[0][0], 's', duration),
							AnimatedCG.unit_copy(arg.args[1][0], unit_suffix, unit_scale)])
				'ease':
					ease_curve = float(arg.args[0][0])
				'_':
					push_error('Illegal ACGTransform value: ' + arg.name)
		
		# manually add frame at t=0 if it doesn't exist
		# this fixes some animation weirdness
		var earliest = null
		var earliest_time = INF
		for frame in frames:
			if frame[0] < earliest_time:
				earliest_time = frame[0]
				earliest = frame
		
		if earliest_time > 0 and earliest != null:
			frames.push_front([0, earliest[1]])
		
	
# copied here from Util because it cannot be used due to autoload errors
# hope Godot fixes this at some point???
static func unit_copy(value: String, unit: String, scale: float) -> float:
	if value.ends_with(unit):
		return float(value.trim_suffix(unit))
	else:
		return float(value) * scale
