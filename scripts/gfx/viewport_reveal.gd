class_name ViewportReveal
## Keeps a SubViewport's on-screen picture hidden until the viewport has drawn
## real frames, so a freshly allocated (uninitialised) render target never shows
## as scrambled noise. Call again whenever the viewport is resized, because
## resizing reallocates the target.

const FRAMES := 2


static func hold(picture: CanvasItem, view: SubViewport, frames := FRAMES) -> void:
	if picture == null or view == null:
		return
	var token := int(picture.get_meta(&"_reveal_token", 0)) + 1
	picture.set_meta(&"_reveal_token", token)
	picture.visible = false
	if view.render_target_update_mode == SubViewport.UPDATE_DISABLED or view.render_target_update_mode == SubViewport.UPDATE_WHEN_VISIBLE:
		# (a hidden picture would otherwise stop the viewport from ever drawing)
		view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	for i in frames:
		await RenderingServer.frame_post_draw
		if not is_instance_valid(picture) or not is_instance_valid(view):
			return
	if int(picture.get_meta(&"_reveal_token", 0)) == token:
		picture.visible = true
