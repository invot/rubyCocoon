extends RefCounted
## --scene=action-icons: every battle bar icon (scripts/battle/action_icons.gd) on a white bar like the battle's, in its
## three colour groups, with the two target marks; checks each move has an icon of the right group. Prints
## "ACTION ICONS DONE: n problem(s)". Add --shot=path to capture the sheet.
const UIKit = preload("res://scripts/ui/ui_kit.gd")
const ActionIcons = preload("res://scripts/battle/action_icons.gd")
const MoveDB = preload("res://scripts/data/move_db.gd")

const ROWS := [
	["Elemental attacks", [["fire", "Ember"], ["water", "Water Jet"], ["earth", "Rock Toss"], ["air", "Gust"], ["ghost", "Shadow Claw"]]],
	["Plain attacks", [["attack", "Tackle"], ["attack", "Slingshot"]]],
	["Everything else", [["defend", "Defend"], ["move", "Move"], ["heal", "Mend"], ["buff", "Howl"], ["hex", "Leer"], ["item", "Items"],
		["flute", "Flute"], ["watch", "Watch"], ["summon", "Summon"], ["run", "Run"]]],
	["Targets", [["weak", "Weak to it"], ["resist", "Resists it"]]],
]


class Sheet extends Control:
	func _draw() -> void:
		var font := UIKit.font_body()
		var head := UIKit.font_head()
		var px := UIKit.body_px(26)
		draw_rect(Rect2(Vector2.ZERO, size), Color("#23262e"))
		var y := 40.0
		for row in ROWS:
			draw_string(head, Vector2(40, y + 22), String(row[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, UIKit.head_px(24), Color.WHITE)
			y += 40.0
			var x := 40.0
			for item in row[1]:
				var label := String(item[1])
				var w := 16.0 + 22.0 + 7.0 + font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x + 16.0
				if x + w > size.x - 40.0:
					x = 40.0
					y += 56.0
				draw_rect(Rect2(x, y, w, 40), Color.WHITE)
				var at := Vector2(x + 16.0 + 11.0, y + 20.0)
				if String(item[0]) in ["weak", "resist"]:
					ActionIcons.draw_mark(self, String(item[0]), at, 10.0)
				else:
					ActionIcons.draw(self, String(item[0]), at, 11.0)
				draw_string(font, Vector2(x + 16.0 + 22.0 + 7.0, y + 20.0 + font.get_ascent(px) * 0.36), label, HORIZONTAL_ALIGNMENT_LEFT, -1, px, UIKit.DARK)
				x += w + 14.0
			y += 72.0


func run(main, opts: Dictionary) -> void:
	var bad := 0
	for id in MoveDB.MOVES:
		var m: Dictionary = MoveDB.MOVES[id]
		var kind := ActionIcons.for_move(id)
		var want := "support"
		if String(m["kind"]) == "attack":
			want = "attack" if String(m["el"]) == "neutral" else "element"
		if ActionIcons.group(kind) != want or (want == "element" and kind != String(m["el"])):
			bad += 1
			print("FAIL %s (%s %s) has icon %s" % [id, m["el"], m["kind"], kind])
	var seen := {}
	for g in ["fire", "water", "earth", "air", "ghost", "attack", "defend"]:
		var c := ActionIcons.color(g)
		for o in seen:
			var d: Color = seen[o]
			if Vector3(c.r - d.r, c.g - d.g, c.b - d.b).length() < 0.18:
				bad += 1
				print("FAIL %s and %s are too close in colour" % [g, o])
		seen[g] = c
	var sheet := Sheet.new()
	sheet.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UI.add_child(sheet)
	await main._wait(0.4)
	print("ACTION ICONS DONE: %d problem(s)" % bad)
