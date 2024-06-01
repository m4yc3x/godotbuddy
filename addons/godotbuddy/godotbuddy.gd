@tool
extends EditorPlugin

var dock
# Declare the nodes
var button
var text_edit
var rich_text_label
var http_request
var chat_history = []
var system_prompt = "Your name is Godot Buddy, you are a master coder and game designer. You only use the Godot 4 Engine. You carefully follow all instructions you are given and avoid giving lengthy explanations of why or how something works. You always follow DRY and SOLID principles in all code you write. You always write self describing code with full names for all variables and functions. Always fully document code and functions with documentation comments using hashtags that completely explain all params and variables. You always use tabs for indentation. You always follow Godot 4 gdscript style guidelines. You always utilize getter and setter functions. You always statically type all variables and focus on maximizing performance. Instead of writing code in markdown tags you write them in bbcode [code][/code] tags. Use BBCode to make your messages look prettier."
var api_key = ""
var api_key_file = "user://api_key.txt"
var loading_icon: TextureRect

func _enter_tree():
	# Initialization of the plugin goes here.
	dock = preload("res://addons/godotbuddy/GodotBuddyDock.tscn").instantiate()
	add_control_to_dock(DOCK_SLOT_RIGHT_UR, dock)
	
	load_api_key()
	
	# Get the nodes from the dock instance
	button = dock.get_node("VBoxContainer/AISubmission/Button")
	text_edit = dock.get_node("VBoxContainer/AIPromptEditor/TextEdit")
	rich_text_label = dock.get_node("VBoxContainer/AIChatResponse/RichTextLabel")
	http_request = dock.get_node("VBoxContainer/HTTPRequest")
	loading_icon = dock.get_node("LoadingIcon")
	loading_icon.visible = false
	
	# Connect the button's pressed signal to the function
	button.connect("pressed", Callable(self, "_on_button_pressed"))
	http_request.connect("request_completed", Callable(self, "_on_request_completed"))

func _exit_tree():
	# Clean-up of the plugin goes here.
	remove_control_from_docks(dock)
	dock.free()

func _on_button_pressed():
	loading_icon.visible = true
	
	var text = text_edit.text
	
	# Check for @filename.gd pattern and replace with file contents
	var pattern: String = r"@([a-zA-Z0-9_/]+(\.gd|\.tscn|\.godot|\.asset))"
	var regex = RegEx.new()
	regex.compile(pattern)
	var matches = regex.search_all(text)
	for match in matches:
		var file_path = match.get_string(1)
		var file_contents = read_file_contents(file_path)
		text = text.replace("@" + file_path, file_path + ":\n\n" + file_contents)
	
	rich_text_label.append_text("\n\n---\n\n[u]User:[/u] " + text)
	
	# Append user's message to chat history
	chat_history.append({"role": "user", "content": text})
	
	var api_key_input = dock.get_node("VBoxContainer/GroqAPIKey/LineEdit").text
	api_key = api_key_input
	save_api_key()
	var url = "https://api.groq.com/openai/v1/chat/completions"
	var headers = ["Authorization: Bearer " + api_key, "Content-Type: application/json"]
	var body = {
		"messages": [{"role": "system", "content": system_prompt}] + chat_history,
		"model": "llama3-70b-8192"
	}
	
	# Show loading icon
	#var loading_icon = dock.get_node("VBoxContainer/LoadingIcon")
	#loading_icon.visible = true
	
	http_request.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(body))
	text_edit.text = ""

func _on_request_completed(result, response_code, headers, body):
	loading_icon.visible = false
	
	if response_code == 200:
		var response_str = body.get_string_from_utf8()
		var response = JSON.parse_string(response_str)
		if typeof(response) == TYPE_DICTIONARY and response.has("choices"):
			var response_data = response["choices"][0]["message"]["content"]
			
			rich_text_label.push_color(Color.DARK_SEA_GREEN)
			rich_text_label.append_text("\n\n---\n\n[u]AI:[/u] " + response_data)
			rich_text_label.pop()
			
			# Append AI's response to chat history
			chat_history.append({"role": "assistant", "content": response_data})
		else:
			rich_text_label.push_color(Color.DARK_RED)
			rich_text_label.append_text("\n\n---\n\n[u]Error:[/u] Failed to parse response.")
			rich_text_label.pop()
	else:
		rich_text_label.push_color(Color.DARK_RED)
		rich_text_label.append_text("\n\n---\n\n[u]Error:[/u] Request failed with code " + str(response_code))
		rich_text_label.pop()

func read_file_contents(file_name: String) -> String:
	var root_dir = "res://"
	var file_path = _find_file(root_dir, file_name)
	if file_path != "":
		var file = FileAccess.open(file_path, FileAccess.READ)
		if file:
			var contents = file.get_as_text()
			file.close()
			return contents
	return ""

func _find_file(dir: String, file_name: String) -> String:
	var dir_access = DirAccess.open(dir)
	if dir_access:
		dir_access.list_dir_begin()
		var file_or_dir = dir_access.get_next()
		while file_or_dir != "":
			if dir_access.current_is_dir():
				var sub_dir = dir + "/" + file_or_dir
				var result = _find_file(sub_dir, file_name)
				if result != "":
					return result
			elif file_or_dir == file_name:
				return dir + "/" + file_or_dir
			file_or_dir = dir_access.get_next()
	return ""

func save_api_key() -> void:
	var file = FileAccess.open("user://api_key.txt", FileAccess.WRITE)
	file.store_line(api_key)
	file.close()

func load_api_key() -> void:
	if FileAccess.file_exists("user://api_key.txt"):
		var file = FileAccess.open("user://api_key.txt", FileAccess.READ)
		api_key = file.get_as_text().strip_edges()
		file.close()
		dock.get_node("VBoxContainer/GroqAPIKey/LineEdit").text = api_key
	else:
		api_key = ""
