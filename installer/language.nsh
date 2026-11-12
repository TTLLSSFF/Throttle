; Shared language detection for the Throttle setup and portable launcher.
;
; Windows reports the user's display language through GetUserDefaultUILanguage.
; Any Chinese UI language maps to the Simplified Chinese installer; every other
; language uses English. The application itself still offers both languages in
; Settings > Language.
;
; Keep the comparison decimal: NSIS LogicLib/IntCmp does not parse 0x04 as 4,
; which silently left the installer in English on Chinese systems.

!ifndef THROTTLE_LANGUAGE_NSH
!define THROTTLE_LANGUAGE_NSH

!include "LogicLib.nsh"

; MUI_LANGUAGE defines these, but the portable launcher has no pages and does
; not load MUI languages. Keep the numeric IDs available for both scripts.
!ifndef LANG_ENGLISH
  !define LANG_ENGLISH 1033
!endif
!ifndef LANG_SIMPCHINESE
  !define LANG_SIMPCHINESE 2052
!endif

!macro THROTTLE_DETECT_LANGUAGE
  System::Call 'kernel32::GetUserDefaultUILanguage() i .r0'
  IntOp $1 $0 & 0x3FF
  ${If} $1 == 4
    StrCpy $LANGUAGE ${LANG_SIMPCHINESE}
  ${Else}
    StrCpy $LANGUAGE ${LANG_ENGLISH}
  ${EndIf}
!macroend

!endif
