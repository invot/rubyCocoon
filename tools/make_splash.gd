extends SceneTree
## Makes the boot splash (assets/icon/boot_splash.png; project.godot application/boot_splash): a moment of the title
## screen's scene (scripts/gfx/title_stage.gd), just before the shadow dragon rises from below.
## It is 2560 x 1080 and covers the screen (stretch mode Cover) the way the title's camera keeps its height, so from 16:9
## to 21:9 the boot splash shows just what the title will. Prints how long the scene took to build.
## Run (needs a window, not --headless):  godot --path . --script res://tools/make_splash.gd

const TitleStage = preload("res://scripts/gfx/title_stage.gd")
const OUT := "res://assets/icon/boot_splash.png"
## Match the live title's opening frame, before its single ascent.
const AT := 0.0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(320, 180)
	var vp := SubViewport.new()
	vp.size = Vector2i(2560, 1080)
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var t0 := Time.get_ticks_usec()
	var stage := TitleStage.new()
	vp.add_child(stage)
	print("title scene built in %.0f ms" % ((Time.get_ticks_usec() - t0) / 1000.0))
	stage.freeze(AT)
	for i in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_png(OUT)
	print("wrote ", OUT)
	quit()
