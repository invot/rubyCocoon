# Supplied tropical hut

Source: the user's `Low poly stylized tribal tropical hut.zip`, supplied with its rendered reference screenshot.
The archive contains `collection/model_0.obj`, `model_1.obj`, `model_2.obj`, `Color.png`, `Alpha.png`,
`bump.png` and `Normal_Map.png`. It includes no author, source URL or licence document; its OBJ material-library
references point to MTL files that are not included.

The game uses the complete `model_1.obj`; `model_0.obj` omits a roof sector. Conversion removes degenerate
triangles and the cloth entrance panel, rebuilds the materials from the supplied colour and inverse-alpha maps,
and fits the model to Kelpwick's existing plots. Plaster is recoloured at runtime. Solid wood doors, timber
platforms, stilts and stairs use the supplied wood finish. A flat ceiling inside the walls seals the interior;
the supplied thatch is the only visible roof. Hanging red garnish and all loose leaf cards are removed; the village uses its existing
small bush models as ground planting instead. Textures are resized, smoothed once through the shared pipeline, and sampled with
linear mipmapped anisotropic filtering. The optional bump and normal maps are not used.

Converted resources: `assets/exteriors/tribal_hut.res` and `tribal_hut_wood.res`.
The wooden fences reuse `tribal_hut_wood.res`, with varied UV crops along their pickets and rails.
Rebuild: `tools/prepare_tribal_hut.py` and `tools/import_tribal_hut.gd`, followed by the documented smoothing/import steps.
Original downloads remain untouched.
