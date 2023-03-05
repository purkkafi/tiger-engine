class_name Lexer extends RefCounted
# lexer for the game config language


# regex for determining whether a character is a part of a tag
var TAG_CHAR_REGEX: RegEx = RegEx.create_from_string('\\w')
# placeholder EOF character
const EOF: String = '\uE000'
# characters that can be a part of a Newline token after it starts with \n
const NEWLINE_CHARS: Array[String] = [ '\n', ' ', '\t' ]
# characters that mark the end of a String
var STR_END_REGEX: RegEx = RegEx.create_from_string('[{}\n\\x{E000}\\\\]')
# error message in case of tokenization failure
var error_message: String


enum TokenType {
	TAG,
	BRACE_OPEN,
	BRACE_CLOSE,
	NEWLINE,
	STRING
}


# represents a token
# instances should be obtained with the static methods
# only Tag and String tokens have values
# tokens store their file & line of origin for debug purposes
class Token extends RefCounted:
	
	var type: int
	var value: String
	var file: String
	var line: int


	func _init(_type: int, _value: String, _file: String, _line: int):
		self.type = _type
		self.value = _value
		self.file = _file
		self.line = _line
	
	
	static func tag(val: String, _file: String, _line: int) -> Token:
		return Token.new(TokenType.TAG, val, _file, _line)
	
	
	static func string(val: String, _file: String, _line: int) -> Token:
		return Token.new(TokenType.STRING, val, _file, _line)
	
	
	static func brace_open(_file: String, _line: int) -> Token:
		return Token.new(TokenType.BRACE_OPEN, '{', _file, _line)
	
	
	static func brace_close(_file: String, _line: int) -> Token:
		return Token.new(TokenType.BRACE_CLOSE, '{', _file, _line)
	
	
	static func newline(_file: String, _line: int) -> Token:
		return Token.new(TokenType.NEWLINE, '<newline>', _file, _line)
	
	
	func where() -> String:
		return file + ':' + str(line)
	
	
	func _to_string() -> String:
		match type:
			TokenType.TAG:
				return 'TAG(%s)' % value
			TokenType.STRING:
				return 'STR(%s)' % value
			TokenType.BRACE_OPEN:
				return 'BRACE_OPEN'
			TokenType.BRACE_CLOSE:
				return 'BRACE_CLOSE'
			TokenType.NEWLINE:
				return 'NEWLINE'
			_:
				return '?"%s"?' % value


func _read_file(path: String):
	var file = FileAccess.open(path, FileAccess.READ)
	assert(file != null, 'cannot read file %s' % [path])
	return file.get_as_text()


func _is_newline_char(chr: String):
	return chr in NEWLINE_CHARS


func _is_tag_char(chr: String):
	return TAG_CHAR_REGEX.search(chr) != null


# returns whether there is an escape sequence (\\ or \{ or \})
# at given index in the given string
func is_escape(str: String, index: int):
	if str[index] != '\\':
		return false
	if index >= len(str):
		return false
	var second = str[index+1]
	return second == '\\' or second == '{' or second == '}'


# tokenizes the file at the given path, see tokenize_string()
func tokenize_file(path: String):
	return tokenize_string(_read_file(path), path)


# tokenizes a given string; the given path is passed to the tokens
# returns an array of Lexer.Tokens on success, null on failure
# if tokenization fails, see error_message for error message
func tokenize_string(text: String, path: String):
	text += EOF
	var index: int = 0
	var tokens: Array[Token] = []
	var line: int = 1
	
	while text[index] != EOF:
		if text[index] == "{":
			tokens.append(Token.brace_open(path, line))
			index += 1
			continue
			
		elif text[index] == "}":
			tokens.append(Token.brace_close(path, line))
			index += 1
			continue
			
		# skip newlines & add newline token
		elif text[index] == '\n':
			while(_is_newline_char(text[index])):
				if text[index] == '\n':
					line += 1
				index += 1
			tokens.append(Token.newline(path, line))
			continue
		
		# handle as tag unless the \ represents an escape sequence
		elif text[index] == '\\' and not is_escape(text, index):
			index += 1
			var start = index
			while(_is_tag_char(text[index])):
				index += 1
			var end = index
			var tag = text.substr(start, end-start)
			
			if len(tag) == 0:
				error_message = 'trailing empty tag in %s' % path
				return null
			else:
				tokens.append(Token.tag(tag, path, line))
		
		else: # assumed to be string
			var start = index
			var found_escapes: bool = false
			
			# find potential end character
			while true:
				var result = STR_END_REGEX.search(text, index)
				index = result.get_start()
				
				# skip over escape sequences, break on others
				if is_escape(text, index):
					index += 2
					found_escapes = true
					continue
				
				break
			
			var string = text.substr(start, index-start)
			
			# replace escape sequences if they were found
			if found_escapes:
				string = string.replace('\\\\', '\\')
				string = string.replace('\\{', '{')
				string = string.replace('\\}', '}')
			
			tokens.append(Token.string(string, path, line))
	
	# remove potential first newline
	if tokens[0].type == TokenType.NEWLINE:
		tokens.remove_at(0);
	
	# remove potential last newline
	if tokens[len(tokens)-1].type == TokenType.NEWLINE:
		tokens.remove_at(len(tokens)-1)
	
	return tokens
