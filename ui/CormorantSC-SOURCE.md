Cormorant SC Bold (weight 700), downloaded from Google Fonts:
https://github.com/google/fonts/blob/main/ofl/cormorantsc/CormorantSC-Bold.ttf

Copyright 2015 the Cormorant Project Authors. Licensed under SIL OFL 1.1;
see CormorantSC-OFL.txt.

The bundled font has overlapping contours merged by
`tools/prepare_title_font.py` so Godot TextMesh can triangulate every letter.
The design, weight and metrics are preserved. To regenerate, download the
upstream TTF to a temporary path, install `fonttools` and `skia-pathops`, and
run that script with the downloaded path and `ui/CormorantSC-Bold.ttf`.
