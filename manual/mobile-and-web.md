# Mobile and the web

[◀ Manual index](index.md)

Phone and tablet builds, their touch controls and renderer, and the browser version with its Cloudflare Pages deployment and password-protected demo.

- Settings are in [settings and performance](settings-and-performance.md).
- Desktop and Android builds are in [builds and releases](builds.md).

## Phones and touch

### Models and renderer

- Pack models over 300 triangles get levels of detail baked in by `tools/import_psx_models.gd`, so far-off trees and rocks draw fewer triangles. `godot --path . --rendering-method mobile -- --scene=perf --detail=1` prints what each map costs.
- The project uses the Mobile renderer on phones and tablets, sensor-landscape orientation, ETC2/ASTC textures, and an expanding aspect, so wide phones get extra width instead of black bars.

### Touch controls

- On touch devices the d-pad, A/B and Start/Pause buttons appear automatically. Connecting a controller hides them unless Screen was explicitly selected in Settings.
- The controller guide appears on the book's Settings right page. Touch targets retain phone sizing while the pad is hidden. All connected inputs use the same actions, so every screen and the flute minigame work with them.
- HUD windows and menus, including the arena ladder's trainer list, must never overlap A/B or their enlarged hit areas. Only the Start menu may use that space while those buttons are hidden. Ordinary lists keep full-sized rows and paginate above the controls.
- Each button answers taps a little outside its drawn edge. The arrows are silent; A and B click softly at a low pitch, with B two notes below A.
- Tap the world to walk, double-tap to run, and tap things to use them (see Controls in the [README](../README.md)).
- Taps on or near the on-screen buttons never count as world taps or reach menu rows behind them: each cluster (the whole d-pad including its middle, A and B, Start and Pause) has a no-tap zone around it.

To try the touch layout on desktop:

```sh
godot --path . -- --touch
```

## Web version (iPhone and any browser)

### Fullscreen on mobile browsers

- A **Play fullscreen** button appears before play. Leaving fullscreen pauses the game and silences audio until **Resume fullscreen** is tapped. The fullscreen icon at the top right toggles fullscreen.
- Detection uses browser user-agent information (including iPads using a desktop agent), never viewport size. Installed home-screen apps already run without browser chrome.
- Browsers without the fullscreen API offer **Play in browser**, with an iPhone home-screen installation hint.

### Building it

`python tools/make_web.py` builds a version that runs in the browser into `build/web/`, ready to host on Cloudflare Pages. It needs Godot's web export templates (`web_nothreads_*.zip` in `%APPDATA%\Godot\export_templates\4.8.beta3\`) and ffmpeg.

- **Small download:** about 18 MB before the title screen. The engine and game data are gzipped and stored as parts under `data/` (Cloudflare Pages takes files of up to 25 MiB); a small script in `index.html` joins and unzips them in the browser. Both exports leave out unused sound effects, unused models and the full-size copies of models that have a `_lo` version (`tools/make_export_presets.py`).
- **Music on demand:** the web build doesn't contain the music. Each track is a small Ogg file under `music/` (about 1.3 MB) that the game downloads the first time it plays it, then keeps.
- **Renderer:** Godot's Compatibility renderer (WebGL 2), single-threaded, so it needs no special server headers. It needs Safari / iOS 16.4 or newer (or any current browser).
- **Local check:** `python -m http.server 8060 --directory build/web`, then open http://localhost:8060.

### Deploying

From the Cloudflare dashboard: go to Workers & Pages > Create > Pages > Upload assets, name the project and drop in the `build/web` folder. Or from a terminal (Node.js, after `npx wrangler login`):

```sh
npx wrangler pages deploy build/web --project-name rubycoccon
```

The site is then at [rubycoccon.pages.dev](https://rubycoccon.pages.dev). `_headers` caches the data parts forever (their names change whenever the game does) and the music for a week.

**On an iPhone:** open the site in Safari, then Share > Add to Home Screen. It gets the app icon and opens full screen, in landscape.

### Runtime benchmark

For the isolated overhaul runtime benchmark, run `python tools/vo_web.py export`, then `python tools/vo_web.py serve` and open `http://127.0.0.1:8061/?vo_perf=1`.

- It makes two route passes and saves full traces under `build/perf/vo/baseline-web/`; it does not measure the production compressed download pipeline.
- See `docs/visual_overhaul/003-web.md` for results and cache limitations.
- When Claude and Codex work concurrently, use `docs/visual_overhaul/parallel-handoff.md`: model requests are serialized by the shared wrappers, and heavy renders and measured native commands use `python tools/local_resource.py -- <command>`.

### Automatic web deployment and authentication

The [build workflow](../.github/workflows/windows-build.yml) runs on every push to `main` (the current default branch) or `master`, and can also run manually.

- **Demo job:** a separate job checks progression and builds `build/web_demo/` with the **Web Demo** preset's baked-in `demo` feature. It deploys to the existing `rubycoccon` Pages project with `--branch=demo`, updating [demo.rubycoccon.pages.dev](https://demo.rubycoccon.pages.dev). It reuses the same Cloudflare secrets as the full build.
- **Artifacts:** the demo and full Web packages are separate Actions artifacts (`RubyCocoon-web-demo` and `RubyCocoon-web`). A failed demo check or export prevents that demo deployment.
- **Full game:** successful runs update the native `latest` release, and runs on `main` also deploy the full Web game to [rubycoccon.pages.dev](https://rubycoccon.pages.dev).
- **Branch behaviour:** the demo job independently updates its own Pages alias on `main` or `master`. Manual runs from other branches keep the existing native-release behaviour but do not deploy either Web site. Repository visibility and release access settings are unchanged; the repository and its non-draft releases are currently public.

### The password

`functions/_middleware.js` is a Pages Function that asks for a password (any username) on every address of the project except [demo.rubycoccon.pages.dev](https://demo.rubycoccon.pages.dev). That covers the full game at rubycoccon.pages.dev, `main.rubycoccon.pages.dev` and each deploy's own address.

- Only the password's SHA-256 is in the repository. To change it, replace `PASSWORD_SHA256` with the output of `printf 'NewPassword' | sha256sum`.
- `wrangler pages deploy` picks up `functions/` from the folder it runs in, so run deploys from the repository root, as the workflow does.

### The demo

- Build locally with `python tools/make_web.py --demo`; the normal command still builds the full Web game into `build/web/`.
- To upload the demo manually using the existing Cloudflare login:

  ```sh
  npx wrangler pages deploy build/web_demo --project-name=rubycoccon --branch=demo
  ```

- The demo includes Cocoon Cove, Bellerive, Shellhaven, Kelpwick, Dustwell Oasis, and their interiors and roads. After restoring the river, board with Captain Reed to see the credits or stay to explore and battle freely. The full game continues to Sunwall.
- Demo saves use `user://demo_saves/`, separate from full-game saves, with no automatic import from them. The exported demo ignores development scenario arguments. For editor previews, add `--demo` after Godot's `--` separator.

### Repository secrets

Set these under the GitHub repository's **Settings → Secrets and variables → Actions → New repository secret**:

| Secret | What it is |
|---|---|
| `CLOUDFLARE_API_TOKEN` | A Cloudflare custom API token with **Account → Cloudflare Pages → Edit**, restricted to the account that owns `rubycoccon`. |
| `CLOUDFLARE_ACCOUNT_ID` | That account's **Account ID**, from the Cloudflare dashboard. An App ID or Pages project ID is not a substitute. The deploy command identifies the project by its name, `rubycoccon`. |

- Keep token values in GitHub secrets. No browser login is needed in CI.
- Without both secrets, the workflow keeps building and saving the web artifact and reports a deployment-skipped warning. After adding them, run the workflow on `main` to publish both Web versions.
- Keep the existing Pages project's production branch as `main` so `demo` remains a preview alias.
- See [Cloudflare's CI authentication guide](https://developers.cloudflare.com/pages/how-to/use-direct-upload-with-continuous-integration/).
- For local builds, `GODOT` can override the Godot executable (`GODOT=/path/to/godot python tools/make_web.py`). Run `node --test tools/tests/web_fullscreen.test.cjs` for the browser-shell regression checks.
