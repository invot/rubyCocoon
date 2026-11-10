extends RefCounted
## The top bar outside battle (scripts/ui/top_bar.gd): several pickups in quick succession merge ("Potion x3"), gold
## adds up, a place name waits its turn, each message slides in, holds and leaves, and the bar is hidden afterwards.
## --scene=top-bar [--gem=sapphire] [--touch] [--shots=res://build/shots/top_bar]  (shots: _pickup, _gold, _place)

var bad := 0


func _check(ok: bool, label: String) -> void:
	if not ok:
		bad += 1
	print("%s %s" % ["ok  " if ok else "FAIL", label])


func run(main: Node) -> void:
	await main._do_goto(String(main._test.get("map", "tidewater")), "center")
	await main._wait(1.5)
	var tb = UI.top_bar
	var shots := String(main._test.get("shots", ""))
	var capture := func(label: String) -> void:
		if shots == "":
			return
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(shots.get_base_dir()))
		main._save_shot(shots + "_" + label + ".png")
	# (whatever the arrival announced is let go first)
	var t := 0.0
	while tb.visible and t < 12.0:
		await main._wait(0.1)
		t += 0.1
	_check(not tb.visible and tb.pending() == 0, "the bar is hidden while there is nothing to say")

	for i in 3:
		GameState.add_item("potion")
		UI.pickup("potion")
		await main._wait(0.15)
	UI.gold(50)
	UI.gold(70)
	UI.place_name("Tidewater", "Market Row")
	await main._wait(0.5)
	_check(tb.visible and tb.current_text() == "Potion x3", "three quick pickups merge into one message (%s)" % tb.current_text())
	_check(tb.left_icon.visible and tb.left_icon.texture != null and not tb.right_icon.visible, "a pickup has its item's icon on the left and no right icon")
	_check(tb.pending() == 3, "gold and the place name wait their turn (%d showing or waiting)" % tb.pending())
	var r: Rect2 = tb.get_global_rect()
	var vp: Rect2 = tb.get_viewport_rect()
	_check(r.position.y >= 0.0 and r.end.x <= vp.size.x and r.position.x >= 0.0, "the bar sits on screen at the top")
	_check(absf(r.get_center().x - vp.size.x * 0.5) <= 2.0, "the bar is centred")
	await capture.call("pickup")

	await _until(main, tb, "+120 gold")
	_check(tb.current_text() == "+120 gold", "gold received together adds up (%s)" % tb.current_text())
	await main._wait(0.4)
	await capture.call("gold")

	await _until(main, tb, "Tidewater")
	_check(tb.current_text() == "Tidewater" and tb.sub_label.visible and tb.sub_label.text == "Market Row", "the place name follows, with its second line")
	await main._wait(0.4)
	await capture.call("place")

	# a long notice wraps instead of running off the screen
	UI.toast("A very long notice that keeps going and going, to see that the top bar wraps onto a second line rather than growing past its widest", "notice")
	await _until(main, tb, "A very long")
	await main._wait(0.4)
	_check(tb.size.x <= tb.MAX_W + 1.0 and tb.label.get_line_count() >= 2, "a long notice wraps at the bar's widest (%d wide, %d lines)" % [int(tb.size.x), tb.label.get_line_count()])
	await capture.call("long")

	t = 0.0
	while tb.visible and t < 12.0:
		await main._wait(0.1)
		t += 0.1
	_check(not tb.visible and tb.pending() == 0, "the bar slides away once everything has been said")
	print("TOP BAR DONE: %d problem(s)" % bad)


func _until(main: Node, tb, prefix: String) -> void:
	var t := 0.0
	while not (tb.visible and tb.current_text().begins_with(prefix) and tb._phase == "hold") and t < 15.0:
		await main._wait(0.1)
		t += 0.1
