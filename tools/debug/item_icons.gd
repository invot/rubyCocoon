extends RefCounted
## Isolated visual check of item artwork in the real Bag, courier and town HUD.
const UIKit = preload("res://scripts/ui/ui_kit.gd")
const Items = preload("res://scripts/data/item_db.gd")
const Book = preload("res://scripts/ui/book_menu.gd")
const Locker = preload("res://scripts/ui/locker_screen.gd")
var main: Node
var opts: Dictionary
var bad := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		bad += 1
	print("%s %s" % ["ok" if ok else "FAIL", message])

func shot(name: String) -> void:
	if opts.has("shots") and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		main._save_shot(String(opts.shots) + "_" + name + ".png")

func run(root: Node, options: Dictionary) -> void:
	main = root
	opts = options
	check(GameState.save_dir().begins_with("res://build/"), "isolated test state")
	if bad:
		return
	if DisplayServer.get_name() != "headless":
		main.get_window().grab_focus()
	var originals := {}
	for id in Items.ITEMS:
		var extension := "svg" if id in ["bat", "lucky_clover"] else "png"
		check(ResourceLoader.exists("res://assets/ui/items/%s.%s" % [id, extension]), "artwork exists: " + id)
		var texture: Texture2D = UI.Glyphs.item(id)
		check(UI.Glyphs.smooth(texture) == (extension == "svg"), "original artwork sampling: " + id)
		originals[id] = texture.get_image().get_data()
	check(UI.Glyphs.item("tome_fire").get_size() == Vector2(16, 16), "dynamic tomes use supplied artwork")
	check(UI.Glyphs.item("sheet_hymn").get_size() == Vector2(16, 16), "dynamic sheet music uses supplied artwork")
	check(UI.Glyphs.item("unknown_test_item") != null, "unknown item fallback")
	UI.auto = true
	await main._go("caccoon", "start")
	main.world.frozen = true
	UI.auto = false
	await main._wait(3.5)
	GameState.inventory = {"minor_potion": 9, "spirit_drop": 7, "remedy_herb": 4, "honey_cake": 2, "silver_flute": 1, "slingshot": 1}
	GameState.locker = {"potion": 9, "revival_seed": 3, "fire_bomb": 4, "power_collar": 1}
	GameState.courier_request = {"items": GameState.locker.duplicate()}
	var screen := Locker.new()
	screen.mode = "receive"
	UI.push(screen)
	await main._wait(0.4)
	for gem in UIKit.ACCENT_ORDER:
		UIKit.set_accent(gem)
		UI.root.theme = UIKit.make_theme()
		UI.controls.refresh()
		screen._refresh()
		await main._wait(0.3)
		var fixed_colors := true
		for id in originals:
			fixed_colors = fixed_colors and UI.Glyphs.item(id).get_image().get_data() == originals[id]
		check(fixed_colors, "all item colors unchanged in " + gem)
		for list in screen.lists:
			for button in list.buttons:
				check(button.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "pack icons use sharp courier sampling")
		await shot("courier_" + gem)
	await main._press("ui_down")
	check(screen.lists[0]._focus == 1, "courier focus navigation")
	screen.close({})
	await main._wait(0.25)
	GameState.courier_request = {}
	var book = Book.new().setup(main.world, "bag")
	UI.push(book)
	await main._wait(0.4)
	for gem in UIKit.ACCENT_ORDER:
		UIKit.set_accent(gem)
		UI.root.theme = UIKit.make_theme()
		book._open_tab(3)
		book.mode = "list"
		book._focus_first()
		await main._wait(0.3)
		await shot("bag_" + gem)
	book.close()
	await main._wait(0.3)
	UIKit.set_accent("Ruby")
	UI.root.theme = UIKit.make_theme()
	UI.controls.refresh()
	UI.place_name("Cocoon Cove")
	await main._wait(0.5)
	check(UI.top_bar.left_icon.texture == UI.Glyphs.tex("town"), "town arrival shows houses")
	await shot("town")
	await main._wait(3.5)
	UI.pickup("potion")
	await main._wait(0.5)
	check(UI.top_bar.left_icon.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "pickup notice keeps pack icon sharp")
	await shot("pickup")
	await main._wait(3.5)
	# Replacing a notice retains the correct location-specific artwork.
	GameState.map_id = "coastal_path"
	UI.place_name("Coastal Path")
	check(UI.top_bar.left_icon.texture == UI.Glyphs.tex("pin"), "non-town locations retain their location marker")
	var crest := UIKit.tex("crest_wave")
	UI.place_name("Bellerive", "", crest)
	check(UI.top_bar.left_icon.texture == crest, "arena town crest is preserved")
	print("ITEM ICONS DONE: %d problem(s)" % bad)
