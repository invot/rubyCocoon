extends RefCounted
## Fictional substitution alphabet, not a translation. Logical reading order is left to right.
## A–Z map consecutively to U+10A80–U+10A99; case folds and spacing/punctuation survive.
const FONT = preload("res://ui/NotoSansOldNorthArabian-Regular.ttf")


static func encode(english: String) -> String:
	var result := ""
	for ch in english.to_upper():
		var cp := ch.unicode_at(0)
		result += String.chr(0x10a80 + cp - 65) if cp >= 65 and cp <= 90 else ch
	return result


static func apply(label: Label3D, english: String) -> void:
	label.set_meta("english_text", english)
	label.font = FONT
	label.text = encode(english)
	label.text_direction = TextServer.DIRECTION_LTR
