extends RefCounted
## Godot normalizes gamepad buttons by position: south confirms, east backs out.
## Nintendo's printed letters differ, so the guide describes the actual bound positions.

static func identify(device_name: String, info := {}) -> String:
	var n := device_name.to_lower()
	var vendor := int(info.get("vendor_id", 0))
	if "dualsense" in n or "ps5" in n:
		return "ps5"
	if "dualshock 4" in n or "dualshock4" in n or "ps4" in n:
		return "ps4"
	if "dualshock 3" in n or "dualshock3" in n or "playstation 3" in n or "playstation(r)3" in n or "ps3" in n:
		return "ps3"
	if "playstation" in n or "sony" in n or vendor == 0x054c:
		return "ps4"
	if "joy-con" in n or "joycon" in n:
		return "joy-cons"
	if "wii u pro" in n:
		return "wii-u-pro"
	if "wii classic" in n:
		return "wii-classic"
	if "switch" in n or "nintendo" in n or vendor == 0x057e:
		return "switch-pro"
	if "stadia" in n:
		return "stadia"
	if "360" in n and ("xbox" in n or "xinput" in n):
		return "xbox-360"
	if "xbox" in n and ("series" in n or "elite" in n):
		return "xbox-series-x"
	return "xbox-one"


static func describe(layout: String) -> Dictionary:
	var names := {"ps5": "DualSense", "ps4": "DualShock 4", "ps3": "DualShock 3",
		"joy-cons": "Joy-Cons", "switch-pro": "Switch Pro", "wii-u-pro": "Wii U Pro",
		"wii-classic": "Wii Classic", "stadia": "Stadia", "xbox-360": "Xbox 360",
		"xbox-series-x": "Xbox Series", "xbox-one": "Xbox"}
	var out := {"name": names.get(layout, "Xbox"), "accept": "A", "back": "B", "start": "Menu", "pause": "View"}
	if layout.begins_with("ps"):
		out.merge({"accept": "Cross", "back": "Circle", "start": "Options" if layout != "ps3" else "Start",
			"pause": "Create" if layout == "ps5" else ("Select" if layout == "ps3" else "Share")}, true)
	elif layout in ["switch-pro", "joy-cons", "wii-u-pro", "wii-classic"]:
		out.merge({"accept": "B", "back": "A", "start": "+", "pause": "−"}, true)
	elif layout == "xbox-360":
		out.merge({"start": "Start", "pause": "Back"}, true)
	elif layout == "stadia":
		out.merge({"start": "Menu", "pause": "Options"}, true)
	return out


## Measured button centres in the Controllercons SVGs' 64 × 64 viewBoxes.
static func button_points(layout: String) -> Dictionary:
	var points := {
		"xbox-one": [Vector2(15.25, 21.75), Vector2(23.5, 32), Vector2(48.75, 26), Vector2(53.25, 21.75), Vector2(27.5, 21.5), Vector2(36.75, 21.5)],
		"xbox-series-x": [Vector2(15.25, 21.75), Vector2(23.75, 32), Vector2(48.25, 26), Vector2(52.5, 21.75), Vector2(27.25, 21.75), Vector2(36.5, 21.75)],
		"xbox-360": [Vector2(13.25, 21), Vector2(22, 32.25), Vector2(50.75, 26.25), Vector2(56, 21), Vector2(25, 21.25), Vector2(38.75, 21.25)],
		"ps5": [Vector2(21.75, 31.75), Vector2(12, 22.75), Vector2(52, 27.75), Vector2(56.25, 23.25), Vector2(17.25, 16.25), Vector2(46.75, 16.25)],
		"ps4": [Vector2(21.75, 33), Vector2(12, 24), Vector2(52, 28.5), Vector2(56.75, 24), Vector2(18.75, 18), Vector2(45, 18)],
		"ps3": [Vector2(22.5, 35.75), Vector2(12.5, 26.5), Vector2(50.5, 31), Vector2(55.5, 26.25), Vector2(26.25, 26.25), Vector2(37.75, 26.25)],
		"switch-pro": [Vector2(14.25, 23.25), Vector2(22, 31.25), Vector2(49, 27.5), Vector2(54, 22.75), Vector2(24.25, 18.25), Vector2(39.75, 18.25)],
		"joy-cons": [Vector2(14.75, 21), Vector2(14.75, 34.5), Vector2(49, 24.25), Vector2(52.5, 21), Vector2(19.75, 13.75), Vector2(44, 13.75)],
		"wii-u-pro": [Vector2(13, 23.25), Vector2(20, 33.75), Vector2(43.75, 38), Vector2(48.25, 33.75), Vector2(26.75, 26), Vector2(37, 26)],
		"wii-classic": [Vector2(23.75, 38.5), Vector2(12.25, 28.5), Vector2(52, 33), Vector2(58, 28.5), Vector2(27, 28.5), Vector2(36.75, 28.5)],
		"stadia": [Vector2(21.5, 31), Vector2(13.75, 22.25), Vector2(50, 23.75), Vector2(54.75, 19.5), Vector2(29, 21.5), Vector2(38.5, 21.5)]
	}
	var p: Array = points.get(layout, points["xbox-one"])
	return {"stick": p[0], "dpad": p[1], "accept": p[2], "back": p[3], "pause": p[4], "start": p[5]}


## Kenney's input prompts (assets/ui/input_prompts/) for a layout's buttons, by what they do here: its d-pad family
## (with _none / _<way>_outline variants) and the buttons that confirm, back out, open the book and pause.
static func prompt_icons(layout: String) -> Dictionary:
	if layout.begins_with("ps"):
		var menu: Array = {"ps5": ["playstation5_button_options", "playstation5_button_create"],
			"ps3": ["playstation3_button_start", "playstation3_button_select"]}.get(layout,
			["playstation4_button_options", "playstation4_button_share"])
		return {"dpad": "playstation_dpad", "accept": "playstation_button_cross", "back": "playstation_button_circle",
			"start": menu[0], "pause": menu[1]}
	if layout in ["switch-pro", "joy-cons", "wii-u-pro", "wii-classic"]:
		return {"dpad": "switch_dpad", "accept": "switch_button_b", "back": "switch_button_a",
			"start": "switch_button_plus", "pause": "switch_button_minus"}
	if layout == "xbox-360":
		return {"dpad": "xbox_dpad", "accept": "xbox_button_a", "back": "xbox_button_b", "start": "xbox_button_start",
			"pause": "xbox_button_back"}
	return {"dpad": "xbox_dpad", "accept": "xbox_button_a", "back": "xbox_button_b", "start": "xbox_button_menu",
		"pause": "xbox_button_view"}
