; Screen Audio Router - Copyright (C) 2026 panoc
; Licensed under the GNU GPL v3 or later. See LICENSE.
; ============================================================================
; Screen Audio Router  -  src\Settings.ahk
; INI load / save, settings backup, debug log, single instance, start with Windows
; Part of ScreenAudioRouter.ahk (included at its end). Functions only.
; ============================================================================

; ------------------------------ SETTINGS BACKUP -----------------------------
; The first start of a new version keeps a copy of the settings it found, e.g.
; "ScreenAudioRouter.ini.1.4.39b.bak", so going back to an older version is easy.
BackupSettingsOnNewVersion() {
    if !FileExist(IniFile)
        return
    last := IniRead(IniFile, "Settings", "LastVersion", "")
    if last = APP_VERSION || (last = "" && IniRead(IniFile, "Settings", "ShowWindowOnce", "") = "1")   ; fresh after Reset all
        return
    try FileCopy(IniFile, IniFile "." (last != "" ? last : "old") ".bak", true)
}

ExportSettings(*) {
    FlushPendingSave()
    if !FileExist(IniFile) {
        Tip("No settings saved yet")
        return
    }
    dest := FileSelect("S16", A_Desktop "\ScreenAudioRouter-settings.ini", "Export settings", "Settings (*.ini)")
    if dest = ""
        return
    try {
        FileCopy(IniFile, dest, true)
        Tip("Settings exported")
    } catch {
        Tip("Could not write " dest)
    }
}

; ------------------------------ RESETS --------------------------------------
; Every override setting back to its first-start default: all overrides off, every override
; device back to Windows Default, every Mic override off (and back to "Paired").
; Tracked apps, monitor outputs, Follow monitor, hotkeys, names, microphone pairs and the
; options are kept. A copy of the settings is saved first.
ResetOverridesToDefaults(*) {
    global AllMode, AllMonitorsMode, AllDevice, AllMonitorsDevice
    try MainGui.Opt("+OwnDialogs")
    if MsgBox("Set every override back to its default?`n`n"
        . "  •  all overrides off (app, temporary, All-Apps, monitor, All-Monitors)`n"
        . "  •  all override devices back to Windows Default`n"
        . "  •  all Mic overrides off (back to Paired)`n`n"
        . "Tracked apps, monitor outputs, hotkeys, device names, microphone pairs and options stay as they are.`n"
        . "A copy of the current settings is saved as ScreenAudioRouter.ini.before-reset-overrides.bak."
        , "Reset overrides", "YesNo Icon? Default2") != "Yes"
        return
    FlushPendingSave()
    try FileCopy(IniFile, IniFile ".before-reset-overrides.bak", true)
    AppOverrideActive.Clear(), AppOverrideRules.Clear(), AppTempOverride.Clear(), Released.Clear()
    AllMode := false, AllDevice := DEFAULT_DEVICE
    Loop MAX_MONITORS
        MonitorOverrideActive[A_Index] := false
    MonitorOverrideRules.Clear(), PrevMonitorOverrideActive.Clear()
    AllMonitorsMode := false, AllMonitorsDevice := DEFAULT_DEVICE
    AppMicOn.Clear(), AppMicDevice.Clear(), MonMicOn.Clear(), MonMicDevice.Clear()
    SaveConfig()
    SaveState()
    SetupTrayMenu()
    ReapplyAll(false, true)
    try {
        if IsObject(MainGui) && DllCall("IsWindowVisible", "Ptr", MainGui.Hwnd) {
            PopulateMonitorDropdowns()
            PopulateOverrideDeviceDropdowns()
            RefreshSelectedAppPanel()
            UpdateOverrideBanner()
        }
    }
    ShowOsdToast("All overrides are back to their defaults", 1)
}

; Back to the first-start settings: the tracked apps go back to the Windows default device,
; the settings file is replaced by an empty one (a dated copy is kept) and the app restarts
; with its window open. "Start with Windows" (a Windows setting) is left as it is.
ResetAllSettings(*) {
    global SkipExitSave
    try MainGui.Opt("+OwnDialogs")
    if MsgBox("Return Screen Audio Router to its first-start settings?`n`n"
        . "Tracked apps, monitor outputs, overrides, hotkeys, device names, microphone pairs and all options are cleared, "
        . "and every tracked app goes back to the Windows default device.`n`n"
        . "Your current settings are kept as a dated .bak copy next to the program (Import settings brings them back). "
        . "The app restarts."
        , "Reset all settings", "YesNo Icon! Default2") != "Yes"
        return
    FlushPendingSave()
    for app, enabled in Apps {
        if enabled
            try SetDevice(app, DEFAULT_DEVICE)
    }
    try FileCopy(IniFile, IniFile ".before-reset-" FormatTime(, "yyyyMMdd-HHmmss") ".bak", true)
    SkipExitSave := true                           ; nothing of the old settings is written on the way out
    try FileDelete(IniFile)
    try IniWrite("1", IniFile, "Settings", "ShowWindowOnce")
    Reload()
}

ImportSettings(*) {
    global SkipExitSave
    src := FileSelect(1, A_Desktop, "Import settings", "Settings (*.ini)")
    if src = ""
        return
    if MsgBox("Replace the current settings with:`n" src "`n`nThe current settings are kept as a .bak copy, and the app restarts."
        , "Import settings", "OKCancel Icon?") != "OK"
        return
    FlushPendingSave()
    try FileCopy(IniFile, IniFile ".before-import.bak", true)
    try {
        FileCopy(src, IniFile, true)
    } catch {
        Tip("Could not read " src)
        return
    }
    SkipExitSave := true                           ; keep the imported file as it is
    Reload()
}

; ------------------------------ DEBUG LOG -----------------------------------
LogLine(msg) {
    if !DebugLog
        return
    try {
        if FileExist(LogFile) && FileGetSize(LogFile) > 1048576 {   ; keep it under 1 MB
            try FileDelete(LogFile ".old")
            FileMove(LogFile, LogFile ".old")
        }
        FileAppend(FormatTime(, "yyyy-MM-dd HH:mm:ss") "." Format("{:03}", A_MSec) "  " msg "`n", LogFile, "UTF-8")
    }
}

ToggleDebugLog(*) {
    global DebugLog
    DebugLog := !DebugLog
    if DebugLog
        LogLine("---- Debug log on (v" APP_VERSION ", Windows " A_OSVersion ", native audio " (NativeAudio ? "on" : "off") ")")
    SaveSettings()
    SetupTrayMenu()
    Tip("Debug log : " (DebugLog ? "ON  (" LogFile ")" : "OFF"))
}

OpenDebugLog(*) {
    if FileExist(LogFile)
        Run('notepad.exe "' LogFile '"')
    else
        Tip("No log yet - turn on Debug log first")
}

ToggleNativeAudio(*) {
    global NativeAudio, CachedDevices, DevicesStale
    NativeAudio := !NativeAudio
    SaveSettings()
    CachedDevices := GetDevices()
    DevicesStale := false
    SetupTrayMenu()
    ReapplyAll(false, true)
    Tip("Native audio (beta) : " (NativeAudio ? "ON" : "OFF - using SoundVolumeView"))
}

; Beta check: the native device ids must match SoundVolumeView's, or saved settings
; would not find their devices. Lists any difference.
CompareNativeWithSvv(*) {
    nat := [], err := ""
    try nat := NativeEnumDevices()
    catch as e
        err := e.Message
    svvList := FileExist(SVV) ? SvvEnumDevices() : []
    rpt := "Windows build " OsBuild() "`n"
    rpt .= "Native routing : " (IsObject(AudioPolicyFactory()) ? "available" : "NOT available") "`n"
    if NativeNote != ""
        rpt .= "Last note : " NativeNote "`n"
    if err != ""
        rpt .= "Native device list failed : " err "`n"
    rpt .= "`nNative devices : " nat.Length "    SoundVolumeView devices : " (FileExist(SVV) ? svvList.Length : "(SoundVolumeView.exe not found)") "`n`n"
    if FileExist(SVV) {
        diff := 0
        for a in nat {
            found := false
            for b in svvList {
                if a.id = b.id {
                    found := true
                    break
                }
            }
            if !found
                rpt .= "Only native :  " a.id "`n", diff++
        }
        for b in svvList {
            found := false
            for a in nat {
                if a.id = b.id {
                    found := true
                    break
                }
            }
            if !found
                rpt .= "Only SoundVolumeView :  " b.id "`n", diff++
        }
        rpt .= diff ? "`n" diff " difference(s) - please send this text." : "All device ids match."
    } else {
        for a in nat
            rpt .= a.id "`n"
    }
    A_Clipboard := rpt
    MsgBox(rpt "`n`n(copied to the clipboard)", "Native audio (beta) check")
}

; ------------------------------ SINGLE INSTANCE -----------------------------
; #SingleInstance Force only replaces another copy of the SAME script. This named
; mutex also stops the .ahk and the compiled .exe from running side by side and
; fighting over the same apps. When a copy is being replaced (reload / Force) its
; mutex is released as it exits, so we wait briefly before giving up.
EnsureSingleInstance() {
    static hMutex := 0
    hMutex := DllCall("CreateMutexW", "Ptr", 0, "Int", 1, "WStr", "Local\ScreenAudioRouter.SingleInstance", "Ptr")
    if !hMutex
        return
    if A_LastError != 183                ; ERROR_ALREADY_EXISTS -> we own it
        return
    r := DllCall("WaitForSingleObject", "Ptr", hMutex, "UInt", 3000, "UInt")
    if r = 0 || r = 0x80                 ; WAIT_OBJECT_0 / WAIT_ABANDONED -> previous owner is gone
        return
    MsgBox("Screen Audio Router is already running.`n`n"
        . "The .ahk script and the compiled .exe cannot run at the same time.",
        "Screen Audio Router", "Iconi")
    ExitApp
}

; ------------------------------ START WITH WINDOWS --------------------------
; A per-user Run value: works for the .ahk and for the compiled exe, needs no
; admin rights, and shows up in Task Manager > Startup. The registry is the
; source of truth, so enabling/disabling there is respected by the checkboxes.
AutoStartCommand() {
    if A_IsCompiled
        return '"' A_ScriptFullPath '" /startup'
    return '"' A_AhkPath '" "' A_ScriptFullPath '" /startup'
}

IsAutoStartEnabled() {
    try {
        if RegRead(AUTOSTART_RUN_KEY, AUTOSTART_NAME, "") = ""
            return false
    } catch {
        return false
    }
    try {
        ; Task Manager keeps a flag here; an odd first byte means "Disabled".
        flag := RegRead(AUTOSTART_APPROVED_KEY, AUTOSTART_NAME, "")
        if flag != "" && (Integer("0x" SubStr(flag, 1, 2)) & 1)
            return false
    }
    return true
}

SetAutoStart(enable) {
    try {
        if enable {
            RegWrite(AutoStartCommand(), "REG_SZ", AUTOSTART_RUN_KEY, AUTOSTART_NAME)
            try RegDelete(AUTOSTART_APPROVED_KEY, AUTOSTART_NAME)   ; clear a "Disabled" flag
        } else {
            try RegDelete(AUTOSTART_RUN_KEY, AUTOSTART_NAME)
            try RegDelete(AUTOSTART_APPROVED_KEY, AUTOSTART_NAME)
        }
        return true
    } catch {
        return false
    }
}

; If the registered files were moved or deleted, point the entry at what is running now.
; An entry whose files still exist is left alone, so starting the .ahk for a test
; never silently replaces a registered exe.
SyncAutoStartPath() {
    try {
        cur := RegRead(AUTOSTART_RUN_KEY, AUTOSTART_NAME, "")
        if cur != "" && !AutoStartTargetsExist(cur)
            RegWrite(AutoStartCommand(), "REG_SZ", AUTOSTART_RUN_KEY, AUTOSTART_NAME)
    }
}

AutoStartTargetsExist(cmd) {
    pos := 1
    while pos := RegExMatch(cmd, '"([^"]+)"', &m, pos) {
        if !FileExist(m[1])
            return false
        pos += m.Len
    }
    return true
}

HasStartupArg() {
    for a in A_Args {
        if a = "/startup"
            return true
    }
    return false
}

RefreshAutoStartUi() {
    if IsObject(ChkAutoStart)
        ChkAutoStart.Value := IsAutoStartEnabled() ? 1 : 0
}

OnAutoStartChanged(*) {
    ok := SetAutoStart(ChkAutoStart.Value = 1)
    SetupTrayMenu()
    RefreshAutoStartUi()                 ; show the real state, e.g. if the write was blocked
    Tip(ok ? "Start with Windows : " (IsAutoStartEnabled() ? "ON" : "OFF")
           : "Could not change the Windows startup entry")
}

ToggleAutoStartFromTray(*) {
    ok := SetAutoStart(!IsAutoStartEnabled())
    SetupTrayMenu()
    RefreshAutoStartUi()
    Tip(ok ? "Start with Windows : " (IsAutoStartEnabled() ? "ON" : "OFF")
           : "Could not change the Windows startup entry")
}

; Runs ~2 s after launch so the blocking device scan does not delay the tray icon / hooks.
; If the window or a title-bar menu needed the devices earlier, they were already loaded.
LoadDevicesDeferred() {
    global CachedDevices, DevicesStale, AudioEndpointSig, DeviceWarnReadyAt
    RefreshEndpointState()
    if DevicesStale {
        CachedDevices := GetDevices()
        DevicesStale := false
    }
    if AvoidConflicts
        SanitizeConfigConflicts(true)
    SetupTrayMenu()
    ; started with Windows: USB / HDMI audio can take a while to appear, so wait before warning
    delay := HasStartupArg() ? 20000 : 3000
    DeviceWarnReadyAt := A_TickCount + delay
    SetTimer(StartupMissingCheck, -delay)
}

; Warns once about assigned devices that are still missing after startup has settled.
StartupMissingCheck() {
    RefreshEndpointState()
    if DeviceWarnings {
        msg := "", mon := 0
        for n, u in AssignedDeviceUses() {
            if !DevicePresent(u.id) && !WarnedMissing.Has(n) {
                WarnedMissing[n] := u.id
                msg .= (msg = "" ? "" : "`n`n") Chr(0x26A0) " " ShortDeviceName(u.id) " is not connected`nUsed by : " u.text
                mon := mon ? mon : u.mon
            }
        }
        if msg != "" {
            ShowOsdToast(msg, mon, "warn")
            LogLine("Startup: " StrReplace(msg, "`n", " / "))
        }
    }
    ReapplyAll(false, true)                        ; devices that appeared late get their apps
}

; ------------------------------ PERSISTENCE ---------------------------------
LoadConfig() {
    global PollMs, StartMinimized, AvoidConflicts, EnableTitleBarMenu, EnableAllAppsTitleBarMenu
    global UseWinEvents, FallbackPollMs, FollowFocusGlobal, TitleBarMenuKey, TitleBarHitTest
    global MainWinX, MainWinY, ToastSec, DeviceWarnings, WarningSound, NativeAudio, DebugLog
    global DisableAllRouting, DisableMonitorRouting, DisableAppRouting
    global HkOverrideFocused, HkOverrideAllMons, HkOverrideAll, HkReapply
    global MicsFollowOutput, ShowWindowOnce

    pollRaw := IniRead(IniFile, "Settings", "PollMs", "500")
    PollMs  := IsInteger(pollRaw) ? Max(150, Min(Integer(pollRaw), 10000)) : 500
    UseWinEvents := (IniRead(IniFile, "Settings", "UseWinEvents", "1") = "1")
    fbRaw := IniRead(IniFile, "Settings", "FallbackPollMs", "2000")
    FallbackPollMs := IsInteger(fbRaw) ? Max(500, Min(Integer(fbRaw), 10000)) : 2000
    StartMinimized            := (IniRead(IniFile, "Settings", "StartMinimized", "1") = "1")
    AvoidConflicts            := (IniRead(IniFile, "Settings", "AvoidConflicts", "1") = "1")
    EnableTitleBarMenu        := (IniRead(IniFile, "Settings", "EnableTitleBarMenu", "1") = "1")
    EnableAllAppsTitleBarMenu := (IniRead(IniFile, "Settings", "EnableAllAppsTitleBarMenu", "1") = "1")
    DisableAllRouting         := (IniRead(IniFile, "Settings", "DisableAllRouting", "0") = "1")
    DisableMonitorRouting     := (IniRead(IniFile, "Settings", "DisableMonitorRouting", "0") = "1")
    DisableAppRouting         := (IniRead(IniFile, "Settings", "DisableAppRouting", "0") = "1")
    FollowFocusGlobal         := (IniRead(IniFile, "Settings", "FollowFocusedWindow", "0") = "1")
    tbKey                     := IniRead(IniFile, "Settings", "TitleBarMenuKey", "^RButton")
    TitleBarMenuKey           := TitleBarKeyIndex(tbKey) ? tbKey : "^RButton"
    TitleBarHitTest           := (IniRead(IniFile, "Settings", "TitleBarHitTest", "1") = "1")
    ts := IniRead(IniFile, "Settings", "ToastSec", "3")
    ToastSec := IsInteger(ts) ? Max(1, Min(Integer(ts), 30)) : 3
    DeviceWarnings := (IniRead(IniFile, "Settings", "DeviceWarnings", "1") = "1")
    NativeAudio := (IniRead(IniFile, "Settings", "NativeAudio", "1") = "1")
    DebugLog := (IniRead(IniFile, "Settings", "DebugLog", "0") = "1")
    WarningSound := (IniRead(IniFile, "Settings", "WarningSound", "1") = "1")
    MicsFollowOutput := (IniRead(IniFile, "Settings", "MicsFollowOutput", "1") = "1")
    if IniRead(IniFile, "Settings", "ShowWindowOnce", "") = "1" {   ; set by Reset all settings
        ShowWindowOnce := true
        try IniDelete(IniFile, "Settings", "ShowWindowOnce")
    }
    wx := IniRead(IniFile, "Settings", "WindowX", ""), wy := IniRead(IniFile, "Settings", "WindowY", "")
    HkTakenShown.Clear()
    for k in StrSplit(IniRead(IniFile, "Settings", "TakenShortcuts", ""), ",", " ")
        if k != ""
            HkTakenShown[k] := true
    MainWinX := IsInteger(wx) ? Integer(wx) : "", MainWinY := IsInteger(wy) ? Integer(wy) : ""

    HkOverrideFocused := IniRead(IniFile, "Hotkeys", "OverrideFocused", DEFAULT_HK_FOCUSED)
    HkOverrideAllMons := IniRead(IniFile, "Hotkeys", "OverrideAllMonitors", DEFAULT_HK_ALL_MONS)
    HkOverrideAll     := IniRead(IniFile, "Hotkeys", "OverrideAll", DEFAULT_HK_ALL)
    HkReapply         := IniRead(IniFile, "Hotkeys", "Reapply", DEFAULT_HK_REAPPLY)

    MonHotkeys.Clear()
    for key, val in ReadSection("Hotkeys") {
        if RegExMatch(key, "^Monitor(\d+)$", &m) && val != "" {
            MonHotkeys[Integer(m[1])] := val
        }
    }

    AppHotkeys.Clear()
    for app, val in ReadSection("AppHotkeys") {
        if app != "" && val != ""
            AppHotkeys[app] := val
    }

    Apps.Clear()
    for app, val in ReadSection("TrackedApps") {
        Apps[app] := (val != "0")
    }

    MonitorRules.Clear(), MonitorOff.Clear()
    for monStr, devId in ReadSection("MonitorRules") {
        if !IsInteger(monStr) || devId = "" || devId = DEFAULT_DEVICE
            continue
        if devId = DISABLED_MONITOR                 ; older versions: "Disabled" was an Output choice
            MonitorOff[Integer(monStr)] := true
        else
            MonitorRules[Integer(monStr)] := devId
    }
    for monStr, v in ReadSection("MonitorsOff") {   ; monitors with "Enabled" unticked
        if IsInteger(monStr) && v = "1"
            MonitorOff[Integer(monStr)] := true
    }

    MonitorOverrideRules.Clear()
    for monStr, devId in ReadSection("MonitorOverrideRules") {
        if IsInteger(monStr) && devId != "" && devId != DEFAULT_DEVICE
            MonitorOverrideRules[Integer(monStr)] := devId
    }

    AppOverrideRules.Clear()
    for app, devId in ReadSection("AppOverrideRules") {
        if app != "" && devId != "" && devId != DEFAULT_DEVICE
            AppOverrideRules[app] := devId
    }

    AppFixedDevice.Clear()
    for app, devId in ReadSection("AppFixedDevice") {        ; apps that do not follow their monitor
        if app != "" && devId != ""
            AppFixedDevice[app] := devId
    }

    MultiDevNames.Clear()
    for k, v in ReadSection("IdenticalDevices") {
        if v != ""
            MultiDevNames[v] := true
    }

    DeviceAliases.Clear(), DeviceHideMap.Clear()
    for k, v in ReadSection("DeviceNames") {          ; N1=<device>|<display name>
        if (p := InStr(v, "|", , -1)) && SubStr(v, p + 1) != ""
            DeviceAliases[SubStr(v, 1, p - 1)] := SubStr(v, p + 1)
    }
    for k, v in ReadSection("DeviceLists") {          ; H1=<device>|<lists it is hidden from>
        if (p := InStr(v, "|", , -1)) && SubStr(v, p + 1) != ""
            DeviceHideMap[SubStr(v, 1, p - 1)] := SubStr(v, p + 1)
    }
    DeviceMics.Clear()
    for k, v in ReadSection("DeviceMics") {           ; M1=<playback device>|<its microphone>
        if (p := InStr(v, "|")) && SubStr(v, p + 1) != ""
            DeviceMics[SubStr(v, 1, p - 1)] := SubStr(v, p + 1)
    }
    DevicePairOff.Clear()
    for k, v in ReadSection("DevicePairOff") {        ; P1=<playback device whose pair is paused>
        if v != "" && DeviceMics.Has(v)
            DevicePairOff[v] := true
    }
    AppSystemMic.Clear()
    for app, val in ReadSection("AppSystemMic") {     ; apps whose microphone also becomes the Windows default
        if app != "" && val = "1"
            AppSystemMic[app] := true
    }
    AppHideTrayIcon.Clear()
    for app, val in ReadSection("AppHideTrayIcon") {  ; apps without a tray icon while their override is on
        if app != "" && val = "1"
            AppHideTrayIcon[app] := true
    }
    AppMicOn.Clear(), AppMicDevice.Clear()
    for app, val in ReadSection("AppMicOverride") {   ; <app>=<1 ticked / 0>|<microphone, empty = paired>
        if app = "" || !(p := InStr(val, "|"))
            continue
        if SubStr(val, 1, 1) = "1"
            AppMicOn[app] := true
        if SubStr(val, p + 1) != ""
            AppMicDevice[app] := SubStr(val, p + 1)
    }
    MonMicOn.Clear(), MonMicDevice.Clear()
    for k, val in ReadSection("MonitorMicOverride") { ; <monitor>=<1 / 0>|<microphone, empty = paired>
        if !IsInteger(k) || !(p := InStr(val, "|"))
            continue
        if SubStr(val, 1, 1) = "1"
            MonMicOn[Integer(k)] := true
        if SubStr(val, p + 1) != ""
            MonMicDevice[Integer(k)] := SubStr(val, p + 1)
    }

    AppFollowFocus.Clear()
    for app, val in ReadSection("AppFollowFocus") {
        if app != "" && (val = "0" || val = "1")
            AppFollowFocus[app] := Integer(val)
    }
}

; ------------------------------ INI WRITER (batched) ------------------------
; Every Save*() call only marks the INI dirty. One timer writes the whole file
; ~300 ms after the last change: built in memory, written once as UTF-16 (so
; non-ASCII device names survive) to a temp file, then swapped in. A crash can no
; longer leave a half-written INI, and a burst of changes costs a single write.
SaveConfig()   {
    ScheduleSave()
}
SaveSettings() {
    ScheduleSave()
}
SaveHotkeys()  {
    ScheduleSave()
}
SaveState()    {
    ScheduleSave()
}

ScheduleSave() {
    global SavePending
    PurgeTempOverrides()
    SavePending := true
    SetTimer(FlushSave, -300)
    SetTimer(UpdateTrayIndicators, -60)
}

SaveAllNow() {
    global SavePending
    SavePending := true
    FlushSave()
}

FlushPendingSave(*) {
    global SavePending
    if SkipExitSave
        return
    if RememberMainWindowPos()           ; window still open at exit: keep where it is
        SavePending := true
    if SavePending
        FlushSave()
}

; Stores the main window's position while it is visible and not minimized.
; Returns true when it changed.
RememberMainWindowPos() {
    global MainWinX, MainWinY
    try {
        if !IsObject(MainGui) || !DllCall("IsWindowVisible", "Ptr", MainGui.Hwnd) || DllCall("IsIconic", "Ptr", MainGui.Hwnd)
            return false
        WinGetPos(&x, &y, , , MainGui.Hwnd)
        if x = MainWinX && y = MainWinY
            return false
        MainWinX := x, MainWinY := y
        return true
    }
    return false
}

; Show options for the saved position, or "" when there is none or its screen is gone
; (the title bar must land on a connected monitor's work area).
SavedMainWindowPos() {
    if !IsInteger(MainWinX) || !IsInteger(MainWinY)
        return ""
    px := MainWinX + 120, py := MainWinY + 12
    Loop MonitorGetCount() {
        MonitorGetWorkArea(A_Index, &l, &t, &r, &b)
        if px >= l && px < r && py >= t && py < b
            return Format("x{1} y{2} ", MainWinX, MainWinY)
    }
    return ""
}

FlushSave() {
    global SavePending
    if !SavePending
        return
    SavePending := false
    WriteIniNow()
}

IniSection(L, name) {
    if L.Length
        L.Push("")
    L.Push("[" name "]")
}

IniKv(L, key, val) {
    L.Push(key "=" val)
}

WriteIniNow() {
    L := []

    IniSection(L, "Settings")
    IniKv(L, "PollMs", PollMs)
    IniKv(L, "UseWinEvents", UseWinEvents ? "1" : "0")
    IniKv(L, "FallbackPollMs", FallbackPollMs)
    IniKv(L, "StartMinimized", StartMinimized ? "1" : "0")
    IniKv(L, "AvoidConflicts", AvoidConflicts ? "1" : "0")
    IniKv(L, "EnableTitleBarMenu", EnableTitleBarMenu ? "1" : "0")
    IniKv(L, "EnableAllAppsTitleBarMenu", EnableAllAppsTitleBarMenu ? "1" : "0")
    IniKv(L, "DisableAllRouting", DisableAllRouting ? "1" : "0")
    IniKv(L, "DisableMonitorRouting", DisableMonitorRouting ? "1" : "0")
    IniKv(L, "DisableAppRouting", DisableAppRouting ? "1" : "0")
    IniKv(L, "FollowFocusedWindow", FollowFocusGlobal ? "1" : "0")
    IniKv(L, "TitleBarMenuKey", TitleBarMenuKey)
    IniKv(L, "TitleBarHitTest", TitleBarHitTest ? "1" : "0")
    IniKv(L, "ToastSec", ToastSec)
    IniKv(L, "DeviceWarnings", DeviceWarnings ? "1" : "0")
    IniKv(L, "NativeAudio", NativeAudio ? "1" : "0")
    IniKv(L, "DebugLog", DebugLog ? "1" : "0")
    IniKv(L, "LastVersion", APP_VERSION)
    IniKv(L, "WarningSound", WarningSound ? "1" : "0")
    IniKv(L, "MicsFollowOutput", MicsFollowOutput ? "1" : "0")
    taken := ""
    for k in HkTakenShown
        taken .= (taken = "" ? "" : ",") k
    if taken != ""
        IniKv(L, "TakenShortcuts", taken)
    if IsInteger(MainWinX) && IsInteger(MainWinY) {
        IniKv(L, "WindowX", MainWinX)
        IniKv(L, "WindowY", MainWinY)
    }

    IniSection(L, "Hotkeys")
    IniKv(L, "OverrideFocused", HkOverrideFocused)
    IniKv(L, "OverrideAllMonitors", HkOverrideAllMons)
    IniKv(L, "OverrideAll", HkOverrideAll)
    IniKv(L, "Reapply", HkReapply)
    for mIdx, hk in MonHotkeys {
        if hk != ""
            IniKv(L, "Monitor" mIdx, hk)
    }

    IniSection(L, "AppHotkeys")
    for app, hk in AppHotkeys {
        if hk != ""
            IniKv(L, app, hk)
    }

    IniSection(L, "TrackedApps")
    for app, enabled in Apps {
        IniKv(L, app, enabled ? "1" : "0")
    }

    IniSection(L, "MonitorRules")
    for mon, devId in MonitorRules {
        if devId != "" && devId != DEFAULT_DEVICE && devId != DISABLED_MONITOR
            IniKv(L, mon, devId)
    }

    IniSection(L, "MonitorsOff")                  ; monitors with "Enabled" unticked
    for mon in MonitorOff
        IniKv(L, mon, "1")

    IniSection(L, "MonitorOverrideRules")
    for mon, devId in MonitorOverrideRules {
        if devId != "" && devId != DEFAULT_DEVICE
            IniKv(L, mon, devId)
    }

    IniSection(L, "AppOverrideRules")
    for app, devId in AppOverrideRules {
        if devId != "" && devId != DEFAULT_DEVICE
            IniKv(L, app, devId)
    }

    IniSection(L, "AppFixedDevice")               ; apps that do not follow their monitor
    for app, devId in AppFixedDevice
        IniKv(L, app, devId)

    IniSection(L, "AppFollowFocus")
    for app, v in AppFollowFocus {
        IniKv(L, app, v ? "1" : "0")
    }

    IniSection(L, "IdenticalDevices")             ; devices you own two or more of (learned)
    i := 0
    for n in MultiDevNames
        IniKv(L, "D" (++i), n)

    IniSection(L, "DeviceNames")                  ; display names used by this app
    i := 0
    for k, v in DeviceAliases
        IniKv(L, "N" (++i), k "|" v)

    IniSection(L, "DeviceLists")                  ; o output, m monitor override, a app override, t temp override
    i := 0
    for k, v in DeviceHideMap
        IniKv(L, "H" (++i), k "|" v)

    IniSection(L, "DeviceMics")                   ; the microphone paired with each playback device
    i := 0
    for k, v in DeviceMics
        IniKv(L, "M" (++i), k "|" v)

    IniSection(L, "DevicePairOff")                ; pairs paused in the Devices window (microphone kept)
    i := 0
    for k in DevicePairOff
        IniKv(L, "P" (++i), k)

    IniSection(L, "AppSystemMic")                 ; apps whose microphone also becomes the Windows default
    for app in AppSystemMic
        IniKv(L, app, "1")

    IniSection(L, "AppHideTrayIcon")              ; apps without a tray icon while their override is on
    for app in AppHideTrayIcon
        IniKv(L, app, "1")

    IniSection(L, "AppMicOverride")               ; <1 ticked / 0>|<microphone, empty = paired with the override device>
    seenMic := Map()
    seenMic.CaseSense := false
    for app in AppMicOn
        seenMic[app] := true
    for app in AppMicDevice
        seenMic[app] := true
    for app in seenMic
        IniKv(L, app, (AppMicOn.Has(app) ? "1" : "0") "|" AppMicDevice.Get(app, ""))

    IniSection(L, "MonitorMicOverride")           ; same, per monitor
    Loop MAX_MONITORS {
        if MonMicOn.Has(A_Index) || MonMicDevice.Has(A_Index)
            IniKv(L, A_Index, (MonMicOn.Has(A_Index) ? "1" : "0") "|" MonMicDevice.Get(A_Index, ""))
    }

    IniSection(L, "All")
    IniKv(L, "Active", AllMode ? "1" : "0")
    IniKv(L, "Device", AllDevice)

    IniSection(L, "AppOverrideActive")
    for app, active in AppOverrideActive {
        if active
            IniKv(L, app, "1")
    }

    IniSection(L, "Released")
    for app in Released {
        IniKv(L, app, "1")
    }

    IniSection(L, "MonitorOverrideActive")
    for mon, active in MonitorOverrideActive {
        if active
            IniKv(L, mon, "1")
    }

    IniSection(L, "AllMonitors")
    IniKv(L, "Active", AllMonitorsMode ? "1" : "0")
    IniKv(L, "Device", AllMonitorsDevice)

    IniSection(L, "PrevMonitorOverrideActive")
    for mon, active in PrevMonitorOverrideActive {
        IniKv(L, mon, active ? "1" : "0")
    }

    text := ""
    for line in L {
        text .= line "`r`n"
    }
    tmp := IniFile ".tmp"
    try {
        f := FileOpen(tmp, "w", "UTF-16")
        f.Write(text)
        f.Close()
        FileMove(tmp, IniFile, true)
    } catch {
        try FileDelete(tmp)
    }
}

LoadState() {
    global AllMode, AllDevice, AllMonitorsMode, AllMonitorsDevice, DetectedMonCount
    DetectedMonCount := Min(Max(MonitorGetCount(), 1), MAX_MONITORS)

    AllMode := (IniRead(IniFile, "All", "Active", "0") = "1")
    AllDevice := IniRead(IniFile, "All", "Device", DEFAULT_DEVICE)
    if AllDevice = ""
        AllDevice := DEFAULT_DEVICE

    AppOverrideActive.Clear()
    for app, val in ReadSection("AppOverrideActive") {
        if Apps.Has(app) && Apps[app] && val = "1"
            AppOverrideActive[app] := true
    }

    Released.Clear()
    for app in ReadSection("Released") {
        Released[app] := true
    }

    MonitorOverrideActive.Clear()
    for monStr, val in ReadSection("MonitorOverrideActive") {
        if IsInteger(monStr) && val = "1" && Integer(monStr) >= 1 && Integer(monStr) <= DetectedMonCount && !IsMonitorDisabled(Integer(monStr))
            MonitorOverrideActive[Integer(monStr)] := true
    }

    AllMonitorsMode := (IniRead(IniFile, "AllMonitors", "Active", "0") = "1")
    AllMonitorsDevice := IniRead(IniFile, "AllMonitors", "Device", DEFAULT_DEVICE)
    if AllMonitorsDevice = ""
        AllMonitorsDevice := DEFAULT_DEVICE

    PrevMonitorOverrideActive.Clear()
    for monStr, val in ReadSection("PrevMonitorOverrideActive") {
        if IsInteger(monStr) && Integer(monStr) >= 1 && Integer(monStr) <= DetectedMonCount
            PrevMonitorOverrideActive[Integer(monStr)] := (val = "1")
    }
}

ReadSection(name) {
    m := Map()
    try {
        for line in StrSplit(IniRead(IniFile, name), "`n", "`r") {
            p := InStr(line, "=")
            if p
                m[SubStr(line, 1, p - 1)] := SubStr(line, p + 1)
        }
    }
    return m
}

MapDel(m, key) {
    if m.Has(key)
        m.Delete(key)
}
