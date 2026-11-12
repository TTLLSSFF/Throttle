Unicode true

; Set the compressor before any file data is compressed.
SetCompressor /SOLID lzma

!include "language.nsh"

; Single-file portable launcher. It embeds the app and the WinDivert runtime,
; unpacks them into %LOCALAPPDATA%\Throttle\portable\<version> (reusing a
; complete extraction so a running instance is never overwritten), then starts
; throttle.exe. Requesting administrator here means the child process inherits
; elevation and Windows shows a single UAC prompt.

!ifndef VERSION
  !define VERSION "0.2.2"
!endif
!ifndef SOURCE_DIR
  !define SOURCE_DIR "dist\stage"
!endif
!ifndef OUT_FILE
  !define OUT_FILE "dist\Throttle-portable.exe"
!endif
!ifndef ICON_FILE
  !define ICON_FILE "assets\throttle.ico"
!endif

Name "Throttle Portable ${VERSION}"
OutFile "${OUT_FILE}"
RequestExecutionLevel admin
Icon "${ICON_FILE}"

VIProductVersion "${VERSION}.0"
VIAddVersionKey "ProductName" "Throttle Portable"
VIAddVersionKey "FileDescription" "Throttle portable launcher"
VIAddVersionKey "FileVersion" "${VERSION}"
VIAddVersionKey "ProductVersion" "${VERSION}"
VIAddVersionKey "CompanyName" "Francesco Gruosso"
VIAddVersionKey "LegalCopyright" "MIT"

!define PORTABLE_DIR "$LOCALAPPDATA\Throttle\portable\${VERSION}"

Var ThrottlePortableUnpackFailed

Function .onInit
  !insertmacro THROTTLE_DETECT_LANGUAGE
  ${If} $LANGUAGE == ${LANG_SIMPCHINESE}
    StrCpy $ThrottlePortableUnpackFailed "无法将 Throttle 运行时文件解压到：$\r$\n${PORTABLE_DIR}"
  ${Else}
    StrCpy $ThrottlePortableUnpackFailed "Throttle could not unpack its runtime files to:$\r$\n${PORTABLE_DIR}"
  ${EndIf}
FunctionEnd

Section "Portable"
  IfFileExists "${PORTABLE_DIR}\throttle.exe" 0 extract
  IfFileExists "${PORTABLE_DIR}\WinDivert.dll" 0 extract
  IfFileExists "${PORTABLE_DIR}\WinDivert64.sys" 0 extract
  Goto launch

extract:
  RMDir /r "${PORTABLE_DIR}"
  SetOutPath "${PORTABLE_DIR}"
  File "${SOURCE_DIR}\throttle.exe"
  File "${SOURCE_DIR}\WinDivert.dll"
  File "${SOURCE_DIR}\WinDivert64.sys"
  File "${SOURCE_DIR}\LICENSE"
  File "${SOURCE_DIR}\THIRD_PARTY_NOTICES.md"
  IfFileExists "${PORTABLE_DIR}\throttle.exe" launch
  MessageBox MB_ICONSTOP "$ThrottlePortableUnpackFailed"
  Quit

launch:
  Exec '"${PORTABLE_DIR}\throttle.exe"'
SectionEnd
