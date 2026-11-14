extends SceneTree
## Offline 010c diagnostic. Run in an isolated project, passing the source root.

func _initialize() -> void:
	var source_root := OS.get_cmdline_user_args()[0]
	var rows: Array = []
	var problems := 0
	for asset in ["assets/battle/backdrops/coast.png", "assets/textures/surfaces/ground_grass.png", "assets/textures/surfaces/leaf.png"]:
		for mipped in [false, true]:
			for profile in [Image.COMPRESS_PROFILE_MAX_QUALITY, Image.COMPRESS_PROFILE_COMPRESSED, Image.COMPRESS_PROFILE_MAX_COMPRESSION]:
				var source := Image.load_from_file(source_root.path_join(asset))
				if source == null:
					problems += 1
					continue
				source.convert(Image.FORMAT_RGBA8)
				if mipped:
					source.generate_mipmaps()
				var packed := source.duplicate() as Image
				var row := {"asset": asset, "mipped": mipped, "profile": profile}
				row["compress_error"] = packed.compress(Image.COMPRESS_ASTC, Image.COMPRESS_SOURCE_GENERIC, profile)
				row["format"] = packed.get_format()
				row["bytes"] = packed.get_data_size()
				if row.compress_error != OK:
					problems += 1
					rows.append(row)
					continue
				row["decompress_error"] = packed.decompress()
				if row.decompress_error != OK:
					problems += 1
					rows.append(row)
					continue
				packed.convert(Image.FORMAT_RGBA8)
				row["source_size"] = [source.get_width(), source.get_height()]
				row["decoded_size"] = [packed.get_width(), packed.get_height()]
				row["uncropped_metrics"] = source.compute_image_metrics(packed, false)
				# Keep the crop hypothesis visible alongside the exact encoder reference:
				# this build resizes to block dimensions with nearest interpolation.
				var region := Rect2i(0, 0, source.get_width(), source.get_height())
				row["base_metrics"] = source.get_region(region).compute_image_metrics(packed.get_region(region), false)
				var resized := packed.duplicate() as Image
				resized.clear_mipmaps()
				resized.resize(source.get_width(), source.get_height(), Image.INTERPOLATE_BILINEAR)
				row["resized_metrics"] = source.get_region(region).compute_image_metrics(resized, false)
				var aligned := source.duplicate() as Image
				aligned.clear_mipmaps()
				aligned.resize(packed.get_width(), packed.get_height(), Image.INTERPOLATE_NEAREST)
				var decoded_base := packed.get_region(Rect2i(0, 0, packed.get_width(), packed.get_height()))
				row["aligned_metrics"] = aligned.compute_image_metrics(decoded_base, false)
				var stem: String = asset.get_file().get_basename() + "-p%d-m%d" % [profile, int(mipped)]
				row["png_error"] = packed.save_png("res://" + stem + ".png")
				if row.png_error != OK:
					problems += 1
				rows.append(row)
	var report := {"engine": Engine.get_version_info(), "problems": problems, "rows": rows, "scope": "CPU ASTC round trips, isolated outputs; no GPU/device or production import acceptance."}
	var file := FileAccess.open("res://roundtrip.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	print("ASTC ROUNDTRIP DONE: %d problem(s)" % problems)
	quit(0 if problems == 0 else 1)
