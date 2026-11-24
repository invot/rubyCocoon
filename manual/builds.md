# Builds and releases

[◀ Manual index](index.md)

Every push to `main` or `master` builds the full game for Windows and Android on GitHub
(`.github/workflows/windows-build.yml`), alongside the separate public Web demo. Godot exports headless on Linux
after the quick checks and publishes the full native downloads as "Latest build". Successful runs on `main` also
publish the full Web game to production Pages, while the parallel demo job updates the demo alias. A build can
also be started by hand from the Actions tab, as before.

- `RubyCocoon-windows.zip`: one portable `RubyCocoon.exe` (unzip and run; it isn't signed, so the first time Windows
  SmartScreen asks: More info, Run anyway).
- `RubyCocoon-android.apk`: the phone app "Ruby Cocoon" (`com.rubycocoon.x`, beside the original Ruby Cocoon app). It's
  signed with the `ANDROID_KEYSTORE_BASE64` repository secret (Godot's debug keystore from the computer that builds the
  phone copies, base64-encoded), so a download installs over a copy built there. Without the secret only Windows is
  built.

