extends RefCounted
## Which model a beast is drawn with, by its genes, for everywhere the game shows one (battle, the overworld, the
## portraits, the Sky Tower's bird):
##   - a line's forms (a "form" with a model in assets/beasts/) and merges of them (genes with a "recipe") are the new
##     beasts, animated (beast_rig.gd): rig() builds one, sized by its "size" gene
##   - the legendaries (a PSX "form") and the robots (a "model") keep their old models (voxel_beast.gd, voxel_assets.gd),
##     which each caller builds as before
## A ghost (shade over 0.5: a half-ghost merge has 0.62) is drawn in black and purple, wrapped in smoke.

const Rig = preload("res://scripts/gfx/beast_rig.gd")
const DIR := "res://assets/beasts/"

## per form: whether it has a new model
static var _has := {}


## Whether these genes are drawn with a rig.
static func rigged(genes: Dictionary) -> bool:
	if genes.has("recipe"):
		return true
	var f := String(genes.get("form", ""))
	if not _has.has(f):
		_has[f] = f != "" and ResourceLoader.exists(DIR + f + ".res")
	return _has[f]


static func ghostly(genes: Dictionary) -> bool:
	return float(genes.get("shade", 0.0)) > 0.5


## The beast's rig, scaled by its size times k, or null for genes drawn the old way.
static func rig(genes: Dictionary, k := 1.0) -> Node3D:
	if not rigged(genes):
		return null
	var r: Rig = Rig.new()
	if genes.has("recipe"):
		r.setup_recipe(genes["recipe"], ghostly(genes))
	else:
		r.setup(String(genes["form"]), ghostly(genes))
	var s := float(genes.get("size", 1.0)) * k
	r.scale = Vector3(s, s, s)
	return r


## How tall a rig stands as scaled (a flyer hovering), in its parent's units.
static func height(r: Rig) -> float:
	return (r.height() + (Rig.HOVER if r.kind == "flyer" else 0.0)) * r.scale.y


## A rig's bounds in its own space, its pieces as they stand at rest (a flyer hovering).
static func bounds(r: Rig) -> AABB:
	var bb := AABB()
	var first := true
	for mi in r.find_children("*", "MeshInstance3D", true, false):
		var xf: Transform3D = r.pivot.transform * r.skel.transform * (mi as MeshInstance3D).transform
		var b: AABB = xf * (mi as MeshInstance3D).get_aabb()
		bb = b if first else bb.merge(b)
		first = false
	return bb


## A rig cast as a statue: every piece in one material, holding still in its first pose.
static func cast(r: Rig, mat: Material) -> void:
	r.set_process(false)
	for mi in r.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_override = mat
	if r.smoke != null:
		r.smoke.queue_free()
		r.smoke = null
