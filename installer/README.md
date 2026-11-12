# Installer and release artifacts

This folder builds the three Windows packages that ship with a release:

- `Throttle.nsi` — NSIS setup executable. Installs `throttle.exe` and the two
  WinDivert runtime files into `%ProgramFiles%\Throttle`, registers an
  uninstall entry, and adds Start Menu shortcuts.
- `ThrottlePortable.nsi` — single-file portable launcher. On first run it
  unpacks the same payload into
  `%LOCALAPPDATA%\Throttle\portable\<version>` and starts Throttle, with no
  installer and no Start Menu entries. Later runs reuse a complete extraction,
  so a running instance is never overwritten.
- `build-zip.sh` — portable folder archive. The five runtime and notice files
  sit at the archive root, so extracting it gives a directly runnable copy.

The application keeps its settings in `%APPDATA%\Throttle`. The setup
uninstaller asks before deleting that folder, and a silent uninstall leaves it
in place. Neither package creates a startup entry: the app registers its own
"run at login" scheduled task from the tray menu when the user asks for it.

The setup and the portable launcher pick English or Simplified Chinese from the
Windows display language. The application itself switches language under
Settings > Language.

## Build

Requirements: a Rust toolchain, the vendored WinDivert files under
`vendor/WinDivert-2.2.2-A/x64`, and NSIS 3 for the setup and the portable
launcher. `makensis` may be on `PATH`, in the default install location, or
pointed at with `NSIS_MAKENSIS`.

Build everything, with a `.sha256` next to each file:

```bash
./installer/build-all.sh
```

Or build one artifact at a time:

```bash
./installer/build-installer.sh   # dist/Throttle-v<version>-windows-x64-setup.exe
./installer/build-zip.sh         # dist/Throttle-v<version>-windows-x64.zip
./installer/build-portable.sh    # dist/Throttle-v<version>-windows-x64-portable.exe
```

Each script reads the version from `Cargo.toml`, runs `cargo build --release`,
stages `throttle.exe`, `WinDivert.dll`, `WinDivert64.sys`, `LICENSE` and
`THIRD_PARTY_NOTICES.md` in `dist/stage`, and writes the artifact to `dist/`.
Override the version with `VERSION=0.2.1 ./installer/build-all.sh`.

Both `.nsi` files are UTF-8 with BOM and must stay that way: NSIS would decode
a BOM-less script with the system code page and turn the Chinese strings into
mojibake. The scripts refuse to compile without the BOM.

`build-zip.sh` uses PowerShell's `Compress-Archive` when `powershell.exe` is
available and falls back to `zip`. Keep the zip name ending in
`-windows-x64.zip`: the in-app updater only accepts a release asset with that
suffix plus a matching `.sha256`, and it expects `throttle.exe` at the zip
root.

## Release workflow

`.github/workflows/release.yml` builds all three artifacts on `windows-latest`
and uploads them with their checksums to the GitHub release when:

- a tag matching `v*` is pushed, or
- the workflow is started manually with a tag that already exists.

The tag must equal `v` plus the `Cargo.toml` version (for example `v0.2.1`),
otherwise the workflow stops before building. The release contains the setup,
the zip, the portable launcher and the three `.sha256` files.

## Notes

- None of the artifacts is code-signed, so Windows SmartScreen may warn on
  first run. Every build requests administrator rights because Throttle loads
  the WinDivert driver.
- The portable launcher extracts to `%LOCALAPPDATA%\Throttle\portable\<version>`
  and leaves that copy in place. Delete the folder to reclaim the space.
- The in-app updater consumes the zip asset (`*-windows-x64.zip`), not the
  setup or the portable launcher.
