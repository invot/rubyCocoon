# Item and town icons

Source: user-supplied `ItemsIcons_v1.0.zip`, titled **Items & Icons Mega Pack** in its license.
No creator or source URL is named in the archive; none is inferred. The source downloads are untouched.

The [included license](Items%20Icons%20Mega%20Pack%20-%20License.txt) permits personal and commercial
game use, modifications and recoloring. It prohibits standalone redistribution, asset resale, NFT use
and AI-training datasets. The selected derivatives are included only as part of this game.

`tools/item_icon_sources.json` selects the source shapes and permanent item palettes.
`tools/item_icon_provenance.json` records the exact archive path used for each converted icon.
`tools/import_item_icons.py` copies those PNG images at their original dimensions and silhouettes,
recoloring only the explicit variants. The game uses sharp nearest filtering for these PNGs and never
tints these images with the interface gem. No image tracing, reshaping or upscaling is applied.
The wooden bat, four-leaf clover and three-house town symbol are original project SVGs.

To rebuild the converted icons from the original archive:

```powershell
python -m pip install --target build/icon_tools pillow
python tools/import_item_icons.py C:/Users/invot/Downloads/ItemsIcons_v1.0.zip
# Use the local Godot 4.7 executable:
godot --headless --path . --import
```

The supplied `9-free-pixel-art-rpg-icons-pixarts-store.zip` was inspected for comparison;
none of its artwork is included in the game.
