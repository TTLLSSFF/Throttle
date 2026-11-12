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
!include "language.nsh"

!define PRODUCT_NAME "Throttle"
!define PRODUCT_PUBLISHER "Francesco Gruosso"
!define PRODUCT_WEB_SITE "https://github.com/FrancescoCoding/Throttle"
!define PRODUCT_EXE "throttle.exe"
!define REG_UNINSTALL "Software\Microsoft\Windows\CurrentVersion\Uninstall\Throttle"
!define REG_APP "Software\Throttle"

Var ThrottleMainName
Var ThrottleDesktopName
Var ThrottleUninstallName
Var ThrottleUninstallLink
Var ThrottleX64Message
Var ThrottleDeleteDataMessage

!ifndef VERSION
  !define VERSION "0.2.2"
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
!define MUI_FINISHPAGE_LINK "GitHub"
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
  CreateShortCut "$SMPROGRAMS\Throttle\$ThrottleUninstallLink" "$INSTDIR\Uninstall.exe"

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

Function .onMouseOverSection
  ${If} $0 == -1
    SendMessage $mui.ComponentsPage.DescriptionText ${WM_SETTEXT} 0 "STR:"
    EnableWindow $mui.ComponentsPage.DescriptionText 0
    SendMessage $mui.ComponentsPage.DescriptionText ${WM_SETTEXT} 0 "STR:$mui.ComponentsPage.DescriptionText.Info"
  ${ElseIf} $0 == ${SEC_MAIN}
    EnableWindow $mui.ComponentsPage.DescriptionText 1
    ${If} $LANGUAGE == ${LANG_SIMPCHINESE}
      SendMessage $mui.ComponentsPage.DescriptionText ${WM_SETTEXT} 0 "STR:Throttle 主程序和 WinDivert 驱动文件（必需）。"
    ${Else}
      SendMessage $mui.ComponentsPage.DescriptionText ${WM_SETTEXT} 0 "STR:Throttle and the WinDivert driver files. Required."
    ${EndIf}
  ${ElseIf} $0 == ${SEC_DESKTOP}
    EnableWindow $mui.ComponentsPage.DescriptionText 1
    ${If} $LANGUAGE == ${LANG_SIMPCHINESE}
      SendMessage $mui.ComponentsPage.DescriptionText ${WM_SETTEXT} 0 "STR:在桌面上创建 Throttle 快捷方式。"
    ${Else}
      SendMessage $mui.ComponentsPage.DescriptionText ${WM_SETTEXT} 0 "STR:Add a Throttle shortcut to the desktop."
    ${EndIf}
  ${EndIf}
FunctionEnd

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
  Delete "$SMPROGRAMS\Throttle\卸载 Throttle.lnk"
  RMDir "$SMPROGRAMS\Throttle"

  Delete "$DESKTOP\Throttle.lnk"

  DeleteRegKey HKLM "${REG_UNINSTALL}"
  DeleteRegKey HKLM "${REG_APP}"

  ; Settings, rules and window layout belong to the user, so never remove them
  ; silently. A silent uninstall leaves them in place.
  IfSilent skip_data_prompt
  MessageBox MB_YESNO|MB_ICONQUESTION "$ThrottleDeleteDataMessage" IDNO skip_data_prompt
  RMDir /r "$APPDATA\Throttle"
  skip_data_prompt:
SectionEnd

Function .onInit
  ; Follow the Windows display language. The app itself still offers
  ; English / 简体中文 in Settings > Language. Detect it before the 64-bit
  ; check so that message is localized too.
  !insertmacro THROTTLE_DETECT_LANGUAGE

  ${If} $LANGUAGE == ${LANG_SIMPCHINESE}
    StrCpy $ThrottleMainName "Throttle 主程序"
    StrCpy $ThrottleDesktopName "桌面快捷方式"
    StrCpy $ThrottleUninstallLink "卸载 Throttle.lnk"
    StrCpy $ThrottleX64Message "Throttle 仅支持 64 位 Windows。"
  ${Else}
    StrCpy $ThrottleMainName "Throttle"
    StrCpy $ThrottleDesktopName "Desktop shortcut"
    StrCpy $ThrottleUninstallLink "Uninstall Throttle.lnk"
    StrCpy $ThrottleX64Message "Throttle requires 64-bit Windows."
  ${EndIf}

  ${IfNot} ${RunningX64}
    MessageBox MB_ICONSTOP|MB_OK "$ThrottleX64Message"
    Abort
  ${EndIf}
  SetRegView 64
  SectionSetText ${SEC_MAIN} "$ThrottleMainName"
  SectionSetText ${SEC_DESKTOP} "$ThrottleDesktopName"
FunctionEnd

Function un.onInit
  SetRegView 64
  !insertmacro THROTTLE_DETECT_LANGUAGE
  ${If} $LANGUAGE == ${LANG_SIMPCHINESE}
    StrCpy $ThrottleUninstallName "卸载"
    StrCpy $ThrottleDeleteDataMessage "是否同时删除当前用户的 Throttle 设置、规则和窗口布局？"
  ${Else}
    StrCpy $ThrottleUninstallName "Uninstall"
    StrCpy $ThrottleDeleteDataMessage "Also delete Throttle settings, rules and window layout for this user?"
  ${EndIf}
  SectionSetText ${SEC_UNINSTALL} "$ThrottleUninstallName"
FunctionEnd
