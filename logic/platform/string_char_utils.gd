# logic/utils/string_char_utils.gd
extends RefCounted
class_name StringCharUtils

const _ASCII_DOT := 46
const _ASCII_ZERO := 48
const _ASCII_NINE := 57


static func is_ascii_digit_code(code: int) -> bool:
	return code >= _ASCII_ZERO and code <= _ASCII_NINE


static func char_string_is_ascii_digit(unit: String) -> bool:
	return unit.length() == 1 and is_ascii_digit_code(unit.unicode_at(0))


static func is_decimal_digit_dot_only(s: String) -> bool:
	for i in s.length():
		var c := s.unicode_at(i)
		if c != _ASCII_DOT and not is_ascii_digit_code(c):
			return false
	return true
