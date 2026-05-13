class_name RuntimeScriptExtender


static func extend(object: Object, script: Script) -> void:
	var state: Dictionary[String, Variant] = {}
	var connections: Dictionary[String, Dictionary] = {}
	
	var properties := object.get_property_list()
	for property in properties:
		if property.name == "script":
			continue
		
		state[property.name] = object.get(property.name)
	
	for sig in object.get_signal_list():
		for connection in object.get_signal_connection_list(sig.name):
			connection[connection.signal] = connection
	
	object.set_script(script)
	
	for variable_name in state:
		object.set(variable_name, state[variable_name])
	
	for signal_name in connections:
		var connection := connections[signal_name]
		object.connect(signal_name, connection.callable, connection.flags)
