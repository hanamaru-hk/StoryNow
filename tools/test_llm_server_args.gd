extends SceneTree

const LLMServerArgs := preload("res://scripts/llm_server_args.gd")

var _failures := 0


func _init() -> void:
	var defaults := {
		"context_size": 0,
		"fit": true,
		"ngl": false,
		"ngl_value": 99,
	}
	var default_args := LLMServerArgs.build(defaults, "model.gguf", "48763")
	_expect(default_args == PackedStringArray(["-c", "0", "--fit", "on", "-m", "model.gguf", "--port", "48763"]), "default arguments enable fit and omit ngl")

	_expect("-ngl" not in default_args, "ngl=false omits the ngl flag")
	_expect("99" not in default_args, "ngl=false omits the ngl value")

	var manual := defaults.duplicate()
	manual["ngl"] = true
	var manual_args := LLMServerArgs.build(manual, "model.gguf", "48763")
	_expect("-ngl" in manual_args, "ngl=true includes the ngl flag")
	_expect("99" in manual_args, "ngl=true includes the configured ngl value")

	var fit_disabled := defaults.duplicate()
	fit_disabled["fit"] = false
	var fit_disabled_args := LLMServerArgs.build(fit_disabled, "model.gguf", "48763")
	var fit_index := fit_disabled_args.find("--fit")
	_expect(fit_index >= 0 and fit_disabled_args[fit_index + 1] == "off", "fit=false passes --fit off")

	if _failures == 0:
		print("LLM server argument tests passed")
		quit(0)
	else:
		push_error("%d LLM server argument test(s) failed" % _failures)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
