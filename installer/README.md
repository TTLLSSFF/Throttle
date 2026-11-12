# Installer

`Throttle.nsi` is the NSIS script for the Windows setup executable. It installs
`throttle.exe` together with the two WinDivert runtime files into
`%ProgramFiles%\Throttle`, registers an uninstall entry, and adds Start Menu
shortcuts. The app keeps its settings in `%APPDATA%\Throttle`; the uninstaller
asks before deleting that folder, and a silent uninstall leaves it in place.

The installer picks English or Simplified Chinese from the Windows display
language. The application itself switches language under Settings > Language.

## Build

NSIS 3 is required (`makensis` on `PATH`, in the default install location, or
pointed at with `NSIS_MAKENSIS`). `Throttle.nsi` is UTF-8 with BOM and must
stay that way; the build script refuses to compile it without the BOM.

```bash
./installer/build-installer.sh
```

The script builds the release binary, stages the payload in `dist/stage`, and
writes:

- `dist/Throttle-v<version>-windows-x64-setup.exe`
- `dist/Throttle-v<version>-windows-x64-setup.exe.sha256`

Override the version with `VERSION=0.2.1 ./installer/build-installer.sh`.

## Notes

- The setup is not code-signed, so Windows SmartScreen may warn on first run.
- The app registers its own "run at login" scheduled task from its tray menu;
  the installer does not create a startup entry.
- The in-app updater consumes the release zip (`*-windows-x64.zip`), not this
  setup executable.
