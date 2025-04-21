class_name ArgParser extends RefCounted


static var SORT_BY_SHORTEST: Callable = func(s1, s2): return len(s1) < len(s2)


var registered_args: Array[Arg] = []
var exclusive_sets: Array = []


enum Type {
	STRING,
	STRING_ARRAY,
	FLAG
}


class Arg extends RefCounted:
	var name: String
	var aliases: Array[String]
	var type: Type
	var help_text: String
	var help_value_name: String


# registers an argument for parsing
# name: the canonical name used by default
# type: the kind of value the argument accepts
# aliases: alternate names for referring to the arg
func register(name: String, type: Type = Type.STRING, aliases: Array[String] = [], help_text: String = '', help_value_name: String = '') -> ArgParser:
	var arg: Arg = Arg.new()
	arg.name = name
	arg.aliases = aliases
	arg.type = type
	arg.help_text = help_text
	arg.help_value_name = help_value_name
	registered_args.append(arg)
	return self


# given an array of canonical names of args, marks them as mutually exclusive
# a parse error will occur if multiple are passed
func set_as_exclusive(exclusive_args: Array[String]):
	for exc_arg in exclusive_args:
		if _find_arg(exc_arg) == null:
			push_error('unknown arg %s, cannot apply exclusive set %s' % [exc_arg, ', '.join(exclusive_args)])
			return
	exclusive_sets.append(exclusive_args)


# attempts to find the Arg that matches the given name; null if not found
func _find_arg(name: String) -> Variant:
	for arg in registered_args:
		if arg.name == name or name in arg.aliases:
			return arg
	return null


# parses the passed values representing OS command line arguments
# returns either:
# – a dict with the key 'error' and an error message
# – a dict mapping the canonical names of each passed argument to the parsed values
# for the final arguments passed after named args, the name is the empty string
func parse(values: Array[String]) -> Dictionary[String, Variant]:
	var found: Dictionary[String, Variant] = {}
	var index: int = 0
	
	while index < len(values):
		var value: String = values[index]
		
		# encountered non-argument value: parse final args passed after every argument
		if not value.begins_with('-'):
			var final_args: Array[String] = []
			
			while index < len(values):
				if values[index].begins_with('-'):
					return { 'error': 'misplaced argument: %s' % values[index]}
				final_args.append(values[index])
				index = index+1
			
			found[''] = final_args
			break
		
		# encountered argument: first find out what it is
		var arg: Variant = _find_arg(value)
		if arg == null:
			return { 'error': 'unknown argument: %s' % value }
		arg = arg as Arg
		index = index+1
		
		# parse according to declared type
		match arg.type:
			Type.FLAG:
				found[arg.name] = null
				
			Type.STRING:
				if index >= len(values):
					return { 'error': 'expected value for %s' % value}
				found[arg.name] = values[index]
				index = index+1
				
			Type.STRING_ARRAY:
				var parts: Array[String] = []
				while index < len(values) and not values[index].begins_with('-'):
					parts.append(values[index])
					index = index+1
				found[arg.name] = parts
	
	# check exclusivity
	var found_per_eset: Dictionary[Array, int] = {}
	for arg in found.keys():
		for eset in exclusive_sets:
			if arg in eset:
				found_per_eset[eset] = found_per_eset.get(eset, 0) + 1
	
	for eset in found_per_eset:
		if found_per_eset[eset] > 1:
			return { 'error': 'only one of %s is allowed' % ', '.join(eset) }
	
	return found


func print_help():
	print('  HELP: Tiger Engine command line arguments:\n')
	
	var name_strings: Dictionary[Arg, String] = {}
	
	for ra in registered_args:
		var all_names: Array[String] = []
		all_names.append(ra.name)
		all_names.append_array(ra.aliases)
		all_names.sort_custom(SORT_BY_SHORTEST)
		
		var name_string: String = ', '.join(all_names)
		if ra.help_value_name != '':
			name_string = '%s=%s' % [name_string, ra.help_value_name]
		
		name_strings[ra] = name_string
	
	var indent: int = name_strings.values().map(func(ns): return len(ns)).max()
	indent = min(20, indent)
	
	for arg in name_strings.keys():
		arg = arg as Arg
		var ns: String = name_strings[arg]
		var name_part: String = ns.rpad(indent)
		
		if len(name_part) <= indent:
			print('  %s  %s' % [name_part, arg.help_text])
		else:
			print('  %s\n  %s  %s' % [name_part, ' '.repeat(indent), arg.help_text])
