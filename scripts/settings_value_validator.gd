class_name SettingsValueValidator
extends RefCounted

const MIN_PORT := 1
const MAX_PORT := 65535
const MIN_TIMEOUT := 1
const MIN_IMAGE_DIMENSION := 16
const MAX_IMAGE_DIMENSION := 16384


static func is_non_negative_integer(value: Variant) -> bool:
	var parsed := _parse_integer(value)
	return parsed.get("valid", false) and int(parsed["value"]) >= 0


static func is_positive_integer(value: Variant) -> bool:
	var parsed := _parse_integer(value)
	return parsed.get("valid", false) and int(parsed["value"]) > 0


static func is_valid_port(value: Variant) -> bool:
	var parsed := _parse_integer(value)
	if not parsed.get("valid", false):
		return false
	var port := int(parsed["value"])
	return port >= MIN_PORT and port <= MAX_PORT


static func is_valid_timeout(value: Variant) -> bool:
	var parsed := _parse_integer(value)
	return parsed.get("valid", false) and int(parsed["value"]) >= MIN_TIMEOUT


static func is_valid_image_dimension(value: Variant) -> bool:
	var parsed := _parse_integer(value)
	if not parsed.get("valid", false):
		return false
	var dimension := int(parsed["value"])
	return dimension >= MIN_IMAGE_DIMENSION \
		and dimension <= MAX_IMAGE_DIMENSION


static func non_negative_integer_or_default(value: Variant, default_value: int) -> int:
	var parsed := _parse_integer(value)
	return int(parsed["value"]) if parsed.get("valid", false) and int(parsed["value"]) >= 0 else default_value


static func positive_integer_or_default(value: Variant, default_value: int) -> int:
	var parsed := _parse_integer(value)
	return int(parsed["value"]) if parsed.get("valid", false) and int(parsed["value"]) > 0 else default_value


static func port_or_default(value: Variant, default_value: int) -> int:
	var parsed := _parse_integer(value)
	return int(parsed["value"]) if is_valid_port(value) else default_value


static func timeout_or_default(value: Variant, default_value: int) -> int:
	var parsed := _parse_integer(value)
	return int(parsed["value"]) if is_valid_timeout(value) else default_value


static func image_dimension_or_default(value: Variant, default_value: int) -> String:
	var parsed := _parse_integer(value)
	return str(int(parsed["value"])) if is_valid_image_dimension(value) else str(default_value)


static func _parse_integer(value: Variant) -> Dictionary:
	if value is int:
		return {"valid": true, "value": value}
	if value is float:
		var number := value as float
		if is_finite(number) and number == floor(number):
			return {"valid": true, "value": int(number)}
		return {"valid": false}
	var text := str(value).strip_edges()
	if text.is_valid_int():
		return {"valid": true, "value": text.to_int()}
	return {"valid": false}
