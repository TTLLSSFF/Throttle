Unicode true
; Throttle installer for 64-bit Windows.
; Built by installer/build-installer.sh, which stages the payload and passes
; VERSION / SOURCE_DIR / OUT_FILE / ICON_FILE as absolute paths.
; Keep this file UTF-8 with BOM: without the BOM makensis can decode the
; Chinese strings using the system code page and garble them.

!include "MUI2.nsh"
!include "FileFunc.nsh"
!include "LogicLib.nsh"
!include "x64.nsh"

!define PRODUCT_NAME "Throttle"
!define PRODUCT_PUBLISHER "Francesco Gruosso"
!define PRODUCT_WEB_SITE "https://github.com/FrancescoCoding/Throttle"
!define PRODUCT_EXE "throttle.exe"
!define REG_UNINSTALL "Software\Microsoft\Windows\CurrentVersion\Uninstall\Throttle"
!define REG_APP "Software\Throttle"

!ifndef VERSION
  !define VERSION "0.2.1"
!endif
!ifndef SOURCE_DIR
  !define SOURCE_DIR "dist\stage"
!endif
!ifndef OUT_FILE
  !define OUT_FILE "dist\Throttle-v${VERSION}-windows-x64-setup.exe"
!endif
!ifndef ICON_FILE
  !define ICON_FILE "assets\throttle.ico"
!endif

Name "${PRODUCT_NAME} ${VERSION}"
OutFile "${OUT_FILE}"
InstallDir "$PROGRAMFILES64\Throttle"
InstallDirRegKey HKLM "${REG_APP}" "InstallDir"
RequestExecutionLevel admin
SetCompressor /SOLID lzma
BrandingText "${PRODUCT_NAME} ${VERSION}"

VIProductVersion "${VERSION}.0"
VIAddVersionKey "ProductName" "${PRODUCT_NAME}"
VIAddVersionKey "ProductVersion" "${VERSION}"
VIAddVersionKey "FileVersion" "${VERSION}.0"
VIAddVersionKey "CompanyName" "${PRODUCT_PUBLISHER}"
VIAddVersionKey "FileDescription" "Throttle installer"
VIAddVersionKey "LegalCopyright" "Copyright (C) 2026 Francesco Gruosso"

!define MUI_ABORTWARNING
!define MUI_ICON "${ICON_FILE}"
!define MUI_UNICON "${ICON_FILE}"
!define MUI_FINISHPAGE_RUN "$INSTDIR\${PRODUCT_EXE}"
!define MUI_FINISHPAGE_RUN_NOTCHECKED
!define MUI_FINISHPAGE_LINK "Throttle on GitHub"
!define MUI_FINISHPAGE_LINK_LOCATION "${PRODUCT_WEB_SITE}"

!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_LICENSE "${SOURCE_DIR}\LICENSE"
!insertmacro MUI_PAGE_COMPONENTS
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH

!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_UNPAGE_FINISH

!insertmacro MUI_LANGUAGE "English"
!insertmacro MUI_LANGUAGE "SimpChinese"

LangString DESC_SEC_MAIN ${LANG_ENGLISH} "Throttle and the WinDivert driver files. Required."
LangString DESC_SEC_MAIN ${LANG_SIMPCHINESE} "Throttle 主程序和 WinDivert 驱动文件（必需）。"
LangString DESC_SEC_DESKTOP ${LANG_ENGLISH} "Add a Throttle shortcut to the desktop."
LangString DESC_SEC_DESKTOP ${LANG_SIMPCHINESE} "在桌面上创建 Throttle 快捷方式。"
LangString MSG_DELETE_DATA ${LANG_ENGLISH} "Also delete Throttle settings, rules and window layout for this user?"
LangString MSG_DELETE_DATA ${LANG_SIMPCHINESE} "是否同时删除当前用户的 Throttle 设置、规则和窗口布局？"

Section "Throttle" SEC_MAIN
  SectionIn RO
  SetShellVarContext all

  ; An upgrade cannot replace the executable while it is running. The app is
  ; a single elevated process, so a forced stop is safe and loses no data.
  nsExec::Exec 'taskkill /F /IM ${PRODUCT_EXE}'
  Pop $0

  SetOutPath "$INSTDIR"
  File "${SOURCE_DIR}\throttle.exe"
  File "${SOURCE_DIR}\WinDivert.dll"
  File "${SOURCE_DIR}\WinDivert64.sys"
  File "${SOURCE_DIR}\LICENSE"
  File "${SOURCE_DIR}\THIRD_PARTY_NOTICES.md"

  WriteUninstaller "$INSTDIR\Uninstall.exe"

  CreateDirectory "$SMPROGRAMS\Throttle"
  CreateShortCut "$SMPROGRAMS\Throttle\Throttle.lnk" "$INSTDIR\${PRODUCT_EXE}"
  CreateShortCut "$SMPROGRAMS\Throttle\Uninstall Throttle.lnk" "$INSTDIR\Uninstall.exe"

  WriteRegStr HKLM "${REG_UNINSTALL}" "DisplayName" "${PRODUCT_NAME}"
  WriteRegStr HKLM "${REG_UNINSTALL}" "DisplayVersion" "${VERSION}"
  WriteRegStr HKLM "${REG_UNINSTALL}" "Publisher" "${PRODUCT_PUBLISHER}"
  WriteRegStr HKLM "${REG_UNINSTALL}" "DisplayIcon" "$INSTDIR\${PRODUCT_EXE}"
  WriteRegStr HKLM "${REG_UNINSTALL}" "InstallLocation" "$INSTDIR"
  WriteRegStr HKLM "${REG_UNINSTALL}" "UninstallString" '"$INSTDIR\Uninstall.exe"'
  WriteRegStr HKLM "${REG_UNINSTALL}" "QuietUninstallString" '"$INSTDIR\Uninstall.exe" /S'
  WriteRegStr HKLM "${REG_UNINSTALL}" "URLInfoAbout" "${PRODUCT_WEB_SITE}"
  WriteRegDWORD HKLM "${REG_UNINSTALL}" "NoModify" 1
  WriteRegDWORD HKLM "${REG_UNINSTALL}" "NoRepair" 1

  ${GetSize} "$INSTDIR" "/S=0K" $0 $1 $2
  IntFmt $0 "0x%08X" $0
  WriteRegDWORD HKLM "${REG_UNINSTALL}" "EstimatedSize" "$0"

  WriteRegStr HKLM "${REG_APP}" "InstallDir" "$INSTDIR"
SectionEnd

Section /o "Desktop shortcut" SEC_DESKTOP
  SetShellVarContext all
  CreateShortCut "$DESKTOP\Throttle.lnk" "$INSTDIR\${PRODUCT_EXE}"
SectionEnd

!insertmacro MUI_FUNCTION_DESCRIPTION_BEGIN
  !insertmacro MUI_DESCRIPTION_TEXT ${SEC_MAIN} $(DESC_SEC_MAIN)
  !insertmacro MUI_DESCRIPTION_TEXT ${SEC_DESKTOP} $(DESC_SEC_DESKTOP)
!insertmacro MUI_FUNCTION_DESCRIPTION_END

Section "Uninstall" SEC_UNINSTALL
  SetShellVarContext all

  nsExec::Exec 'taskkill /F /IM ${PRODUCT_EXE}'
  Pop $0

  ; The app creates this scheduled task when "Launch at startup" is enabled.
  ; It points at the executable being removed, so drop it as well.
  nsExec::Exec 'schtasks /Delete /TN ${PRODUCT_NAME} /F'
  Pop $0

  Delete "$INSTDIR\throttle.exe"
  Delete "$INSTDIR\WinDivert.dll"
  Delete "$INSTDIR\WinDivert64.sys"
  Delete "$INSTDIR\LICENSE"
  Delete "$INSTDIR\THIRD_PARTY_NOTICES.md"
  Delete "$INSTDIR\Uninstall.exe"
  RMDir "$INSTDIR"

  Delete "$SMPROGRAMS\Throttle\Throttle.lnk"
  Delete "$SMPROGRAMS\Throttle\Uninstall Throttle.lnk"
  RMDir "$SMPROGRAMS\Throttle"

  Delete "$DESKTOP\Throttle.lnk"

  DeleteRegKey HKLM "${REG_UNINSTALL}"
  DeleteRegKey HKLM "${REG_APP}"

  ; Settings, rules and window layout belong to the user, so never remove them
  ; silently. A silent uninstall leaves them in place.
  IfSilent skip_data_prompt
  MessageBox MB_YESNO|MB_ICONQUESTION "$(MSG_DELETE_DATA)" IDNO skip_data_prompt
  RMDir /r "$APPDATA\Throttle"
  skip_data_prompt:
SectionEnd

Function .onInit
  ${IfNot} ${RunningX64}
    MessageBox MB_ICONSTOP|MB_OK "Throttle requires 64-bit Windows.$\r$\nThrottle 仅支持 64 位 Windows。"
    Abort
  ${EndIf}
  SetRegView 64

  ; Follow the Windows display language. The app itself still offers
  ; English / 简体中文 in Settings > Language.
  System::Call 'kernel32::GetUserDefaultUILanguage() i .r0'
  IntOp $1 $0 & 0x3FF
  ${If} $1 == 0x04
    StrCpy $LANGUAGE ${LANG_SIMPCHINESE}
    SectionSetText ${SEC_MAIN} "Throttle 主程序"
    SectionSetText ${SEC_DESKTOP} "桌面快捷方式"
  ${Else}
    StrCpy $LANGUAGE ${LANG_ENGLISH}
  ${EndIf}
FunctionEnd

Function un.onInit
  SetRegView 64
  System::Call 'kernel32::GetUserDefaultUILanguage() i .r0'
  IntOp $1 $0 & 0x3FF
  ${If} $1 == 0x04
    StrCpy $LANGUAGE ${LANG_SIMPCHINESE}
  ${Else}
    StrCpy $LANGUAGE ${LANG_ENGLISH}
  ${EndIf}
FunctionEnd
