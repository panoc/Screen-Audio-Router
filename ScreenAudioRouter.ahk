; ============================================================================
; ScreenAudioRouter.ahk  -  AutoHotkey v2 (Adaptive Multi-Monitor GUI Edition)
;
; Routes all enabled tracked applications' audio to the output device assigned
; to the screen their window is currently on, with per-app overrides,
; monitor overrides, global app/monitor overrides, a title-bar menu (mouse
; combination selectable), audio anchored to one window per app, top-right screen OSD
; and automatic contradiction detection/avoidance.
; ============================================================================
; Screen Audio Router
; Copyright (C) 2026 panoc  -  https://github.com/panoc
;
; This program is free software: you can redistribute it and/or modify it under
; the terms of the GNU General Public License as published by the Free Software
; Foundation, either version 3 of the License, or (at your option) any later version.
;
; This program is distributed in the hope that it will be useful, but WITHOUT ANY
; WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
; PARTICULAR PURPOSE. See the GNU General Public License for more details.
; You should have received a copy of the license along with this program (LICENSE).
; If not, see <https://www.gnu.org/licenses/>.
; ============================================================================
;@Ahk2Exe-SetName          Screen Audio Router
;@Ahk2Exe-SetDescription   Screen Audio Router
;@Ahk2Exe-SetVersion       1.6.1
;@Ahk2Exe-SetCopyright (C) 2026 panoc - GPLv3 - github.com/panoc
;@Ahk2Exe-SetOrigFilename  Screen Audio Router.exe
#Requires AutoHotkey v2.0
#SingleInstance Force
CoordMode("ToolTip", "Screen")
CoordMode("Mouse", "Screen")
CoordMode("Menu", "Screen")

; ------------------------------- CONFIG -------------------------------------
APP_VERSION := "1.6.1"   ; keep equal to the SetVersion line at the top (-betaN = test build)
SVV      := A_ScriptDir "\SoundVolumeView.exe"
IniFile  := A_ScriptDir "\ScreenAudioRouter.ini"
IconDll   := FileExist(A_ScriptDir "\res\sor-icons.dll") ? A_ScriptDir "\res\sor-icons.dll" : A_ScriptDir "\sor-icons.dll"   ; 101 normal, 102 partial, 103 off, 104-107 monitors 1-4, 108 all monitors, 109 app
IconFiles := Map(101, "trayico.ico", 102, "trayicopr.ico", 103, "trayiconr.ico", 104, "m1.ico", 105, "m2.ico"
               , 106, "m3.ico", 107, "m4.ico", 108, "mon.ico", 109, "ap.ico")
; The nine icons are built into the exe: the .ico files must be in the res folder when
; compiling (Ahk2Exe stops with an error if one is missing).
;@Ahk2Exe-AddResource res\trayico.ico, 101
;@Ahk2Exe-AddResource res\trayicopr.ico, 102
;@Ahk2Exe-AddResource res\trayiconr.ico, 103
;@Ahk2Exe-AddResource res\m1.ico, 104
;@Ahk2Exe-AddResource res\m2.ico, 105
;@Ahk2Exe-AddResource res\m3.ico, 106
;@Ahk2Exe-AddResource res\m4.ico, 107
;@Ahk2Exe-AddResource res\mon.ico, 108
;@Ahk2Exe-AddResource res\ap.ico, 109

DEFAULT_DEVICE         := "DefaultRenderDevice"
DEFAULT_CAPTURE_DEVICE := "DefaultCaptureDevice"
DISABLED_MONITOR       := "Disabled"
MAX_MONITORS           := 4
MIXER_BATCH_SIZE       := 12   ; apps per SoundVolumeView launch in "Reset Win Mixer" (1 = one call per command)

AUTOSTART_NAME         := "ScreenAudioRouter"
AUTOSTART_RUN_KEY      := "HKCU\Software\Microsoft\Windows\CurrentVersion\Run"
AUTOSTART_APPROVED_KEY := "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run"

DEFAULT_HK_FOCUSED  := "^!o"     ; Ctrl+Alt+O (toggles override for focused tracked app)
DEFAULT_HK_ALL_MONS := "^!m"     ; Ctrl+Alt+M (toggles global All-Monitors override)
DEFAULT_HK_ALL      := "^!+o"    ; Ctrl+Alt+Shift+O (toggles global All-Apps override)
DEFAULT_HK_REAPPLY  := "^!r"     ; Ctrl+Alt+R (re-apply routing now)

HkOverrideFocused := DEFAULT_HK_FOCUSED
HkOverrideAllMons := DEFAULT_HK_ALL_MONS
HkOverrideAll     := DEFAULT_HK_ALL
HkReapply         := DEFAULT_HK_REAPPLY

RegHkFocused := ""
RegHkAllMons := ""
RegHkAll     := ""
RegHkReapply := ""

MonHotkeys       := Map()    ; monNum -> configured hotkey string
RegMonHotkeys    := Map()    ; monNum -> currently registered hotkey string

AppHotkeys       := Map()    ; app.exe -> configured hotkey string
RegAppHotkeys    := Map()    ; app.exe -> currently registered hotkey string

PollMs                    := 500
StartMinimized            := true
AvoidConflicts            := true
EnableTitleBarMenu        := true
EnableAllAppsTitleBarMenu := true
DisableAllRouting         := false
DisableMonitorRouting     := false
DisableAppRouting         := false

; ------------------------------- BUTTON COLORS ------------------------------
; Set any color using "#RRGGBB" or "RRGGBB", or "" to use the default GUI button.
Color1 := "#15803D"   ; Green
Color2 := "#2D648E"   ; Blue
Color3 := "#4B5563"   ; Slate Gray
Color4 := "#B73333"   ; Red
Color5 := "#93D2FF"   ; Cyan
Color6 := "#D97706"   ; Amber / Orange
Color7  := "#64A9DB"   ; Cyan2
Color8  := "#0F766E"   ; Teal
Color9  := "#C49A3E"   ; Dark orange
Color10  := "#634E1F"   ; Dark orange
ColorDefault := "#FDFDFD"   ; Default

; Assign any ColorN (or ColorDefault for the theme's default button color) to any button:
BtnColorRoutingOn      := Color1
BtnColorRoutingOff     := Color4

BtnColorApply          := Color8
BtnColorClose          := Color4

BtnColorMonOvrOff      := ColorDefault
BtnColorMonOvrOn       := Color2

BtnColorAppOvrOff      := ColorDefault
BtnColorAppOvrOn       := Color9


BtnColorDetect         := ColorDefault
BtnColorRefresh        := ColorDefault
BtnColorIdentifyMons   := ColorDefault
BtnColorRemoveApp      := ColorDefault
BtnColorResetAppOvr    := ColorDefault
BtnColorFixConflicts   := ColorDefault
BtnColorQuickActions   := ColorDefault     ; "Re-apply Routing Now"

; Global Hotkeys & Quick Actions toggle buttons (On = while that override is on):
BtnColorQuickSelectedOff := ColorDefault   ; "Toggle Selected (app)"
BtnColorQuickSelectedOn  := Color9
BtnColorQuickAllAppsOff  := ColorDefault   ; "Toggle All-Apps Override"
BtnColorQuickAllAppsOn   := Color9
BtnColorQuickAllMonsOff  := ColorDefault   ; "Toggle All-Monitors Override"
BtnColorQuickAllMonsOn   := Color2
BtnColorHkSet          := ColorDefault
BtnColorHkClear        := ColorDefault
BtnColorHkReset        := ColorDefault
BtnColorResetOverrides := ColorDefault
BtnColorResetWinMixer  := ColorDefault
BtnColorResetSettings  := Color4     ; "Reset All..." (all settings back to first start)

; Detected Running Apps window:
BtnColorDetectWinDetect := ColorDefault
BtnColorDetectWinAdd    := ColorDefault
BtnColorDetectWinClose  := ColorDefault

; Name of the selected app in the Per-App section (any ColorN, or "" for the theme's accent color):
SelectedAppColor        := Color6

; ------------------------------- THEME --------------------------------------
; Window colors (hex RGB, no "#"). Change them here and restart the script.
; Button colors are set above (Color1.. / BtnColor..).

APP_TITLE_SIZE := 20                    ; font size of the "Screen Audio Router" title (8-16)
SELECTED_APP_SIZE := 11                 ; font size of the selected app's name in the Per-App section (9-14)
TABLE_ROW_HEIGHT := 22                  ; height of the rows in the Tracked Applications table (18-40)

THEME := Map(
;    "appTitle",     "64A9DB",
	"appTitle",     "D1750C",
    "frameTitle",   "D1750C",
    "frame",        "6B7280",
    "bg",           "1F2125",
    "text",         "C8CCD3",
    "textHead",     "D0D3D9",
    "text2",        "A1A7B3",
    "muted",        "6B7280",
    "hint",         "8B93A1",
    "accent",       "7AA2F7",
    "capture",      "60A5FA",
    "ok",           "C8CCD3",
    "warn",         "C8CCD3",
    "err",          "F87171",
    "statusOvr",    "",         ; status bar while an override is on (not a warning), "" = text
    "editBg",       "2B2D31",
    "listBg",       "26282C",
    "rowBg",        "",
    "rowText",      "",
    "rowHoverLift", "-32",
    "rowHoverText", "E3E8EF",
    "selBg",        "2D648E",   ; selected table row
    "selText",      "E3E8EF",
    "selHoverLift", "0",
    "selHoverText", "",
    "ovrRowText",   "2B2D31",
    "ovrRowHoverLift", "-42",
    "ovrRowHoverText", "2B2D31",
    "selOvrText",   "E3E8EF",         ; selected row with an override on (background = selBg), "" = BtnColorAppOvrOn
    "selOvrStrip",  "4",        ; width of the override-colored strip on its left edge, 0 = none
    "gridLine",     "26282C",   ; table grid: lines between the rows
    "gridLineV",    "",         ; table grid: lines between the columns, "" = none
    "hdrBg",        "3A3D44",
    "hdrText",      "DADDE5",
    "hdrLine",      "929499",
    "sepLine",      "3A3D44",
    "btnDefault",   "3A3D44",
    "btnText",      "",         ; text of dark buttons, "" = text
    "btnTextLight", "111111",   ; text of light buttons (a light ColorN)
    "ddlBg",        "",         ; drop-down lists (closed), "" = btnDefault
    "ddlText",      "",         ; drop-down lists: text (closed and open), "" = text
    "ddlListBg",    "",         ; drop-down lists: the open list, "" = editBg
    "btnDisBg",     "2A2C31",
    "btnDisFg",     "6B7280",
    "btnDisBorder", "3A3D44",
    "hoverLift",    "-32",
    "hoverBorder",  "3A3D44",
    "checkBg",      "2B2D31",   ; checkbox: box
    "checkBorder",  "6B7280",   ; checkbox: box outline
    "checkOnBg",    "2D648E",   ; checkbox: box when ticked
    "checkMark",    "E3E8EF"    ; checkbox: tick mark
)

; ------------------------------- STATE --------------------------------------
Apps                      := Map()    ; app.exe -> bool (true = enabled, false = disabled)
MonitorRules              := Map()    ; monNum -> normal deviceId
MonitorOverrideRules      := Map()    ; monNum -> per-monitor override deviceId
MonitorOverrideActive     := Map()    ; monNum -> bool (true = per-monitor override active)
PrevMonitorOverrideActive := Map()    ; monNum -> bool (snapshot)
MonitorOff                := Map()    ; monNum -> true: monitor unticked ("Enabled" off); its Output / Ovrd / Mic are kept

AllMonitorsMode           := false    ; true when Global All-Monitors Override is ON
AllMonitorsDevice         := DEFAULT_DEVICE

AppOverrideRules          := Map()    ; app.exe -> configured per-app override deviceId (defaults to DEFAULT_DEVICE)
AppOverrideActive         := Map()    ; app.exe -> bool (true = per-app override currently active)
Released                  := Map()    ; app.exe -> true (apps released from all-apps override)

LastRouted                := Map()    ; app.exe -> "mon|deviceId" last applied
LastSeen                  := Map()    ; app.exe -> last monitor its window was seen on
SessionFix                := Map()    ; "app|flow" -> {sig, tries, last}: re-routing an app heard on the wrong device (SessionWatchTick)
RouteFailed               := Map()    ; app.exe -> {tries, last}: Windows refused its routing (no sound yet), done when its sound starts
RoutedAt                  := Map()    ; app.exe -> tick of its last routing that Windows accepted
SessionStuck              := Map()    ; "app|flow" -> endpoint id the app keeps playing / recording on by itself

for m in [AppHotkeys, RegAppHotkeys, Apps, AppOverrideRules, AppOverrideActive, Released, LastRouted, LastSeen, SessionFix, SessionStuck, RouteFailed, RoutedAt]
    m.CaseSense := false

AllMode               := false    ; true when Global All-Apps Override is ON
AllDevice             := DEFAULT_DEVICE
LastFocusedTrackedApp := ""
LastForegroundHwnd    := 0

; Shared process/window scan cache (see RefreshScan)
ScanStamp             := 0
ScanAppCount          := -1
ScanRunning           := Map()    ; tracked exe -> true while a process exists
ScanWindow            := Map()    ; tracked exe -> best visible window hwnd
ScanRunning.CaseSense := false
ScanPids              := Map()    ; tracked exe -> process ids (for native routing)
ScanPids.CaseSense    := false
TitleSize             := Max(8, Min(APP_TITLE_SIZE, 16))
NativeAudio           := true     ; BETA: list devices / route apps without SoundVolumeView
NativeNote            := ""       ; last native problem, shown by the beta compare tool
DebugLog              := false    ; write routing decisions / device changes to ScreenAudioRouter.log
LogFile               := A_ScriptDir "\ScreenAudioRouter.log"
DeviceWarnReadyAt     := 0        ; no missing-device warnings before this tick (devices still appearing)
ScanWindow.CaseSense  := false
IsStartingUp          := true

CachedDevices       := []
CachedMics          := []       ; active recording devices (microphones), same form as CachedDevices
DeviceMics          := Map()    ; output device key -> the microphone paired with it (Devices window)
DeviceMics.CaseSense := false
DevicePairOff       := Map()    ; output device key -> true: its pair is paused (Windows default mic), the microphone is kept
DevicePairOff.CaseSense := false
MicsFollowOutput    := true     ; master switch for microphones (Devices window)
AppMicOn            := Map()    ; app -> true: Mic override ticked (counts while the app's override is on)
AppMicDevice        := Map()    ; app -> microphone of its Mic override ("" / none = paired with the override device)
MonMicOn            := Map()    ; monitor -> true: Mic override ticked (counts while the monitor's override is on)
MonMicDevice        := Map()    ; monitor -> microphone of its Mic override ("" / none = paired with the Ovrd device)
AppMicOn.CaseSense := false, AppMicDevice.CaseSense := false
AppSystemMic        := Map()    ; app -> true: also make its microphone the Windows default (per-app option)
AppSystemMic.CaseSense := false
AppHideTrayIcon     := Map()    ; app -> true: no tray icon while its override is on
AppHideTrayIcon.CaseSense := false
CachedCandidates    := []
SelectedApp         := ""
MonCount            := MAX_MONITORS
DetectedMonCount    := Min(Max(MonitorGetCount(), 1), MAX_MONITORS)
BuiltMonSignature   := ""
KnownMonSignature   := GetMonitorLayoutSignature()   ; layout the engine currently knows about
GuiDirty            := false    ; GUI must be rebuilt before it is next shown
DevicesStale        := false    ; CachedDevices must be re-read before the GUI next uses it
MainWinX            := ""       ; main window position, kept across closes and restarts
MainWinY            := ""
AppFixedDevice      := Map()    ; app -> device it always uses ("Follow monitor" unticked)
AppFixedDevice.CaseSense := false
AppTempOverride     := Map()    ; app -> device used instead of its saved override device until the override ends
AudioEndpointSig    := ""       ; active playback device ids at the last device scan
EndpointActive      := Map()    ; normalized device id -> true while that playback device is active
EndpointKnown       := Map()    ; normalized device id -> true for every playback device Windows knows
WarnedMissing       := Map()    ; device -> true once the user was told it is missing (until it returns)
WarnedApp           := Map()    ; "app|device" -> true once told that app's device is missing
EndpointActiveX     := Map()    ; same, by exact id (devices you own two of)
EndpointKnownX      := Map()
MultiDevNames       := Map()    ; normalized id -> true: you own two or more of this device (learned, saved)
EndpointActive.CaseSense := false, EndpointKnown.CaseSense := false
EndpointActiveX.CaseSense := false, EndpointKnownX.CaseSense := false, MultiDevNames.CaseSense := false
WarnedMissing.CaseSense := false, WarnedApp.CaseSense := false
DeviceCheckPending  := false    ; a device change is waiting for its registry check
DeviceCheckStage    := 0
ToastSec            := 3        ; how long notifications stay (s); warnings stay longer
DeviceWarnings      := true     ; warn when an assigned output device is missing
WarningSound        := true     ; play the Windows warning sound with those warnings
EdtToastSec         := ""
SavePending         := false    ; the INI has changes that have not been written yet
SkipExitSave        := false    ; restarting after Import / Reset all: do not write the old settings back on exit
ShowWindowOnce      := false    ; open the window once after a restart (Reset all)

; Theme: the palette in use, filled from THEME at the top.
ExtraIcons          := Map()    ; tray id -> {res, tip, kind, key} of the extra override icons shown now
AppTrayIds          := Map()    ; app -> its tray icon id (stable for the session)
NextAppTrayId       := 2100
TrayMainState       := 0        ; resource id currently shown as the main tray icon
TRAY_CB_MSG         := 0x85A1   ; callback message of the extra tray icons
HoverTips           := Map()    ; control hwnd -> hover tooltip text (AddTip)
ListHotRow          := Map()    ; list hwnd -> row under the mouse (from 0), -1 = none (own hover drawing)
CtrlColorCache      := Map()    ; control hwnd -> text color last set (SetCtrlColor)
DdlItemCache        := Map()    ; drop-down hwnd -> its entries last set (SetDdlItems)
LastTrackedRows     := []       ; the table rows as last shown (PopulateAppList updates only what changed)
ListRowTips         := Map()    ; list hwnd -> Map(row index from 0 -> tooltip text), full names for long cells
LvRowColors         := Map()    ; list hwnd -> Map(row index from 0 -> background color), e.g. apps with their override on
DarkChecks          := Map()    ; checkbox hwnd -> {hot, dirty}: painted by the script (both themes, see DarkCheckProc)
DarkChecksActive    := true     ; false while closing: the checkboxes are left to Windows
PaintedDdls         := Map()    ; drop-down hwnd -> {hot}: painted by the script (see DdlProc)
ThemedLVs           := Map()    ; ListView hwnd -> true while its rows are drawn by the script

; Which window decides an app's monitor (see FindWindow)
FollowFocusGlobal   := false    ; true = apps follow their focused/topmost window (old behaviour)
AppFollowFocus      := Map()    ; app -> 1 / 0; missing = use FollowFocusGlobal
AnchorHwnd          := Map()    ; app -> the window whose monitor the app's audio follows
AnchorPending       := Map()    ; app -> monitor of an adopted anchor; audio held until it changes

; Title-bar menu mouse combination
TitleBarMenuKey     := "^RButton"
TitleBarHitTest     := true     ; ask the window where its title bar is (WM_NCHITTEST)
TitleBarKeyChoices  := [["Ctrl+Right-Click", "^RButton"], ["Alt+Right-Click", "!RButton"]
                      , ["Shift+Right-Click", "+RButton"], ["Middle-Click", "MButton"]
                      , ["Ctrl+Middle-Click", "^MButton"]]
ThemeKeys           := ["bg", "text", "textHead", "text2", "muted", "hint", "accent", "capture"
                      , "ok", "warn", "err", "statusOvr", "editBg", "listBg", "btnDefault", "btnDisBg", "btnDisFg", "btnDisBorder"
                      , "hoverLift", "hoverBorder", "hdrBg", "hdrText", "hdrLine", "selBg", "selText", "selHoverLift", "selHoverText", "rowBg", "rowText", "rowHoverLift", "rowHoverText"
                      , "ovrRowText", "ovrRowHoverLift", "ovrRowHoverText", "selOvrText", "selOvrStrip", "gridLine", "gridLineV", "sepLine", "frame", "frameTitle", "appTitle"
                      , "checkBg", "checkBorder", "checkOnBg", "checkMark"
                      , "btnText", "btnTextLight", "ddlBg", "ddlText", "ddlListBg"]
ThemeColors         := Map()

; Hotkey Capture State (supports keyboard + mouse buttons)
HotkeyBoxMeta       := Map()    ; hwnd -> {ctrl, kind, key, pendingHk}
ActiveCaptureHwnd   := 0
ActiveCaptureHook   := ""
HkOwnerCache        := Map()    ; shortcut key -> who else uses it ("" = free), filled by HotkeyTakenBy()
HkTakenShown        := Map()    ; shortcuts already reported as taken (not repeated at startup), saved in the INI

; Custom Button Color State
BtnColorMap         := Map()    ; hwnd -> {ctrl, isDefault, bg, fg, border}
HoveredBtnHwnd      := 0

; Window-event tracking (see InstallWinEventHooks)
UseWinEvents        := true
FallbackPollMs      := 2000     ; safety-net poll while the event hooks are active
EventsActive        := false
WinEventHooks       := []
WinEventCb          := 0
IsRebuildingGui     := false
IsPopulatingTracked := false
LastTrackedSnapshot := ""

; GUI References
MainGui              := ""
BtnToggleRouting     := ""
AppLV                := ""
StatusLV             := ""
BtnRemoveApp         := ""
ChkStartMin          := ""
EdtPollMs            := ""
ChkAutoStart         := ""
ReplaceDlg           := ""
DevicesDlg           := ""
DeviceAliases        := Map()   ; device key -> display name used by this app
DeviceHideMap        := Map()   ; device key -> lists it is hidden from: o output, m monitor ovr, a app ovr, t temp ovr
DeviceAliases.CaseSense := false, DeviceHideMap.CaseSense := false
ChkFollowFocus       := ""
DdlAppFollowFocus    := ""
DdlTitleBarKey       := ""

; Selected App Per-App Override Controls
LblSelAppName        := ""
DdlAppOverrideDevice := ""
ChkAppFollowMon      := ""
DdlAppFixedDevice    := ""
ChkAppSystemMic      := ""
ChkAppHideTray       := ""
ChkAppMicOn          := ""
DdlAppMic            := ""
AppMicDdlIds         := []
AppFixedDeviceIds    := []
AppOverrideDeviceIds := []
BtnToggleAppOvr      := ""
BtnResetAppOvr       := ""
HkCtrlApp            := ""
BtnSetAppHk          := ""
BtnClrAppHk          := ""
BtnRstAppHk          := ""

; Routing Controls & Options
ChkDisableAll        := ""
ChkDisableMon        := ""
ChkDisableApp        := ""
ChkTitleBarMenu      := ""
ChkAllTitleBarMenu   := ""
LblRoutingModeNote   := ""

; Reset Controls & Apply/Close Bar
BtnResetAppOverrides := ""
BtnResetMonOverrides := ""
BtnResetAllOverrides := ""
BtnResetWinMixer     := ""
BtnApplyChanges      := ""
BtnCloseGui          := ""

; Bottom Status Bar
LblStatusBar         := ""
LblConflictBar       := ""

; Detection Popup Window
DetectWindow         := ""
DetectedLV           := ""
EdtFilter            := ""
ChkShowAllProcs      := ""

; OSD Toast Window
OsdGui               := ""
OsdTextCtrl          := ""

; Monitor Controls
MonDropdowns         := Map()
MonDropdownIds       := Map()
MonOvrLabels         := Map()
MonOvrDropdowns      := Map()
MonOvrDropdownIds    := Map()
MonOvrButtons        := Map()
MonHkLabels          := Map()
MonHkControls        := Map()
MonHkSetButtons      := Map()
MonHkClrButtons      := Map()
MonHkRstButtons      := Map()
MonMicChecks         := Map()    ; monitor -> its Mic override checkbox
MonMicDropdowns      := Map()    ; monitor -> its microphone list
MonMicDropdownIds    := Map()    ; monitor -> ids behind that list
MonEnableChecks      := Map()    ; monitor -> its "Enabled" checkbox

; Global Override Settings & Conflict Guard Controls
LblOvrAllHeader      := ""
DdlAllAppsDevice     := ""
AllAppsDeviceIds     := []

LblOvrAllMonsHeader  := ""
DdlAllMonsDevice     := ""
AllMonsDeviceIds     := []

ChkAvoidConflicts    := ""
BtnFixConflicts      := ""
LblConflictStatus    := ""

; Global Hotkey Controls
BtnHkFocused         := ""
HkCtrlFocused        := ""

BtnHkAllMons         := ""
HkCtrlAllMons        := ""

BtnHkAll             := ""
HkCtrlAll            := ""

BtnHkReapply         := ""
HkCtrlReapply        := ""

; ------------------------------- STARTUP ------------------------------------
EnsureSingleInstance()
if iconSrc := IconSource(101)              ; replaced by the state icon in UpdateTrayIndicators()
    try TraySetIcon(iconSrc.file, iconSrc.num)

InitThemeDefaults()
BackupSettingsOnNewVersion()
LoadConfig()
LoadState()
ApplyTheme()
SyncAutoStartPath()
RefreshEndpointState()               ; playback devices from the registry (fast)
DevicesStale := true                 ; first device scan happens in LoadDevicesDeferred()
if NativeAudio {                      ; native list takes milliseconds: load it before routing starts
    try {
        CachedDevices := GetDevices()
        DevicesStale := !CachedDevices.Length
    }
}
SetTimer(LoadDevicesDeferred, -2000)

InitAllHotkeys()
OnMessage(0x007E, OnWmDisplayChange) ; WM_DISPLAYCHANGE
OnMessage(0x0201, OnWmLButtonDown)   ; WM_LBUTTONDOWN (activates hotkey capture boxes)
OnMessage(0x0007, OnWmSetFocus)      ; WM_SETFOCUS
OnMessage(0x0008, OnWmKillFocus)     ; WM_KILLFOCUS
OnMessage(0x0219, OnWmDeviceChange)  ; WM_DEVICECHANGE (just flags the device list as stale)
OnMessage(0x0218, OnWmPowerBroadcast) ; WM_POWERBROADCAST (wake from sleep)
OnMessage(0x004E, OnWmNotify)        ; WM_NOTIFY (NM_CUSTOMDRAW for the colored buttons)
OnMessage(0x0200, OnWmMouseMove)     ; WM_MOUSEMOVE (colored button hover)
OnMessage(0x02A3, OnWmMouseLeave)    ; WM_MOUSELEAVE (colored button hover clear)
OnMessage(0x0111, OnDdlCommand)      ; WM_COMMAND (painted drop-downs: repaint after a choice)

SetupTrayMenu()
; The main window is built lazily by ShowMainGui() the first time it is opened.

OnExit(FlushPendingSave)             ; write any pending INI changes on every exit path
ApplyTitleBarHotkey()
OnMessage(TRAY_CB_MSG, OnExtraTrayIcon)
OnMessage(DllCall("RegisterWindowMessageW", "Str", "TaskbarCreated", "UInt"), OnTaskbarCreated)
OnExit(RemoveExtraTrayIcons)
OnExit(UnhookDarkChecks)             ; before the windows are destroyed
UpdateTrayIndicators()
InstallWinEventHooks()
ApplyPollTimer()
SetTimer(SessionWatchTick, 1000)     ; where tracked apps are actually heard (see SessionWatchTick)
;SetTimer(RefreshTrackedStatusOnly, 1000)
SetTimer(FinishStartupPhase, -1500)
SetTimer(StartupHotkeyCheck, HasStartupArg() ? -25000 : -5000)   ; other apps register their shortcuts first

if ShowWindowOnce || (!StartMinimized && !HasStartupArg()) {
    ShowMainGui()
} else {
    Tip("Screen Audio Router running in tray")
}

FinishStartupPhase() {
    global IsStartingUp
    IsStartingUp := false
}

; ------------------------------- HOTKEYS ------------------------------------

; Win+Shift+Left/Right moves a window to the neighbouring monitor without any
; drag event, so re-check shortly after the keys are pressed.
~#+Left::KeySnapSettle()
~#+Right::KeySnapSettle()

; ------------------------------- CODE FILES ---------------------------------
; The rest of the program lives in the src folder. Ahk2Exe merges these files into
; the exe when compiling, so the compiled exe does not need the src folder.
#Include %A_ScriptDir%\src\Gui.ahk
#Include %A_ScriptDir%\src\Routing.ahk
#Include %A_ScriptDir%\src\Audio.ahk
#Include %A_ScriptDir%\src\Tray.ahk
#Include %A_ScriptDir%\src\Theme.ahk
#Include %A_ScriptDir%\src\Hotkeys.ahk
#Include %A_ScriptDir%\src\Settings.ahk
