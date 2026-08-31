extends RefCounted


static func build(llm_settings: Dictionary, model_path: String, port_number: String) -> PackedStringArray:
	var context_size: int = int(llm_settings["context_size"])
	var args := PackedStringArray(["-c", str(context_size)])
	if bool(llm_settings["fit"]):
		args.append_array(PackedStringArray(["--fit", "on"]))
	else:
		args.append_array(PackedStringArray(["--fit", "off"]))
	if bool(llm_settings["ngl"]):
		var ngl_value: int = int(llm_settings["ngl_value"])
		args.append_array(PackedStringArray(["-ngl", str(ngl_value)]))
	args.append_array(PackedStringArray(["-m", model_path, "--port", port_number]))
	return args
