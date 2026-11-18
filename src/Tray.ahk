; Screen Audio Router - Copyright (C) 2026 panoc
; Licensed under the GNU GPL v3 or later. See LICENSE.
; ============================================================================
; Screen Audio Router  -  src\Tray.ahk
; Tray menu and icons, title-bar menu, on-screen notifications
; Part of ScreenAudioRouter.ahk (included at its end). Functions only.
; ============================================================================

; ------------------------------ TITLE-BAR MENU (mouse combination) ----------
; Registered at run time: the mouse hook only exists while a title-bar option is
; enabled, and the combination can be changed in Routing Controls & Options.
ApplyTitleBarHotkey() {
    static active := ""
    want := (EnableTitleBarMenu || EnableAllAppsTitleBarMenu) ? TitleBarMenuKey : ""
    if want = active
        return
    HotIf(TitleBarHotIfCheck)
    if active != ""
        try Hotkey(active, "Off")
    if want != ""
        try Hotkey(want, TitleBarMenuHotkey, "On")
    HotIf()
    active := want
}

TitleBarHotIfCheck(thisHotkey) {
    return IsMouseOverTitleBar()
}

TitleBarMenuHotkey(thisHotkey) {
    OpenTitleBarContextMenu()
}

TitleBarMenuButton() {
    return InStr(TitleBarMenuKey, "MButton") ? "MButton" : "RButton"
}

TitleBarKeyLabels() {
    arr := []
    for c in TitleBarKeyChoices
        arr.Push(c[1])
    return arr
}

TitleBarKeyIndex(key) {
    for i, c in TitleBarKeyChoices {
        if c[2] == key
            return i
    }
    return 0
}

; Asks the window what is under the cursor (WM_NCHITTEST, 50 ms, skipped if the window
; is hung). Returns the hit code, or 0 when there is no usable answer.
TitleBarHitCode(hwnd) {
    pt := Buffer(8, 0)
    if !DllCall("GetPhysicalCursorPos", "Ptr", pt)
        DllCall("GetCursorPos", "Ptr", pt)
    lp := (NumGet(pt, 0, "Int") & 0xFFFF) | ((NumGet(pt, 4, "Int") & 0xFFFF) << 16)
    res := 0
    if !DllCall("SendMessageTimeoutW", "Ptr", hwnd, "UInt", 0x84, "Ptr", 0, "Ptr", lp
        , "UInt", 0x2, "UInt", 50, "Ptr*", &res, "Ptr")      ; SMTO_ABORTIFHUNG
        return 0
    return res > 0 ? res : 0
}

IsIgnoredShellProcess(exe) {
    static ignored := ""
    if !IsObject(ignored) {
        ignored := Map()
        ignored.CaseSense := false
        ignored.Set(
            "SearchHost.exe", 1,
            "StartMenuExperienceHost.exe", 1,
            "ShellExperienceHost.exe", 1,
            "TextInputHost.exe", 1,
            "LockApp.exe", 1,
            "dwm.exe", 1,
            "csrss.exe", 1,
            "sihost.exe", 1
        )
    }
    return ignored.Has(exe)
}

GetRootWindowHwnd(hwnd) {
    if !hwnd
        return 0
    root := DllCall("GetAncestor", "Ptr", hwnd, "UInt", 2, "Ptr") ; GA_ROOT = 2
    return root ? root : hwnd
}

GetEffectiveWindowExe(winHwnd) {
    winHwnd := GetRootWindowHwnd(winHwnd)
    if !winHwnd
        return ""
    try {
        pid := WinGetPID("ahk_id " winHwnd)
        exe := GetProcessExeName(pid)
        if exe = "ApplicationFrameHost.exe" {
            for childHwnd in WinGetControlsHwnd("ahk_id " winHwnd) {
                cpid := WinGetPID("ahk_id " childHwnd)
                if cpid && cpid != pid {
                    cexe := GetProcessExeName(cpid)
                    if cexe != "" && cexe != "ApplicationFrameHost.exe"
                        return cexe
                }
            }
        }
        return exe
    }
    return ""
}

; Title-bar check: asks the window (WM_NCHITTEST, short timeout) and falls back to
; the top 50 px of the window when there is no usable answer.
IsMouseOverTitleBar() {
    static shellCls := Map("Progman", 1, "WorkerW", 1, "Shell_TrayWnd", 1, "Shell_SecondaryTrayWnd", 1)
    if !EnableTitleBarMenu && !EnableAllAppsTitleBarMenu
        return false
    try {
        MouseGetPos(&mx, &my, &rawHwnd)
        winHwnd := GetRootWindowHwnd(rawHwnd)
        if !winHwnd
            return false
        if IsObject(MainGui) && winHwnd = MainGui.Hwnd
            return false
        if IsObject(DetectWindow) && winHwnd = DetectWindow.Hwnd
            return false
        if IsObject(OsdGui) && winHwnd = OsdGui.Hwnd
            return false

        if shellCls.Has(WinGetClass("ahk_id " winHwnd))
            return false
        WinGetPos(&wx, &wy, &ww, &wh, "ahk_id " winHwnd)
        if ww <= 0 || wh <= 0
            return false
        if mx < wx || mx > (wx + ww) || my < wy || my > (wy + wh)
            return false

        ht := TitleBarHitTest ? TitleBarHitCode(winHwnd) : 0
        if ht > 0 {
            if ht != 2                               ; HTCAPTION only: not tabs, buttons, menus or borders
                return false
        } else {
            dpi := 96
            try dpi := DllCall("GetDpiForWindow", "Ptr", winHwnd, "UInt")
            if !dpi
                dpi := 96
            capH := Round(50 * (dpi / 96.0))
            if (my - wy) < 0 || (my - wy) > capH
                return false
        }

        if !EnableAllAppsTitleBarMenu {
            exe := GetEffectiveWindowExe(winHwnd)
            if exe = "" || !Apps.Has(exe)
                return false
        }
        return true
    }
    return false
}

OpenTitleBarContextMenu() {
    global CachedDevices, DevicesStale
    CoordMode("Mouse", "Screen")
    MouseGetPos(&mx, &my, &rawHwnd)
    winHwnd := GetRootWindowHwnd(rawHwnd)
    if !winHwnd
        return

    KeyWait(TitleBarMenuButton(), "T0.35")

    exe := GetEffectiveWindowExe(winHwnd)
    if exe = "" || IsIgnoredShellProcess(exe)
        return

    if !Apps.Has(exe) && !EnableAllAppsTitleBarMenu
        return

    CheckAudioEndpointsNow()
    if DevicesStale {
        CachedDevices := GetDevices()
        DevicesStale := false
    }

    ctx := Menu()

    if Apps.Has(exe) {
        isEnabled := Apps.Get(exe, false)
        isOvrOn   := AppOverrideActive.Get(exe, false)
        ovrDevId  := AppOverrideRules.Get(exe, DEFAULT_DEVICE)
        ovrName   := ShortDeviceName(ovrDevId)

        tmpDev := (isOvrOn && AppTempOverride.Has(exe)) ? AppTempOverride[exe] : ""
        itemOvr := tmpDev != "" ? Format("Override {1} ({2}, temporary)", exe, ShortDeviceName(tmpDev))
                                : Format("Override {1} ({2})", exe, ovrName)
        ctx.Add(itemOvr, (*) => ToggleAppOverrideByName(exe))
        if isOvrOn
            ctx.Check(itemOvr)
        if !isEnabled || DisableAllRouting
            ctx.Disable(itemOvr)

        devSub := Menu()
        devSub.Add("Windows Default Device", (*) => SetAndActivateAppOverrideFromMenu(exe, DEFAULT_DEVICE))
        if ovrDevId = DEFAULT_DEVICE
            devSub.Check("Windows Default Device")
        for d in CachedDevices {
            devLabel := d.label
            devId := d.id
            if DeviceHidden(devId, "a") && devId != ovrDevId
                continue
            devSub.Add(devLabel, SetAndActivateAppOverrideFromMenu.Bind(exe, devId))
            if ovrDevId = devId
                devSub.Check(devLabel)
        }
        ctx.Add("Select Override Device", devSub)
        if !isEnabled || DisableAllRouting
            ctx.Disable("Select Override Device")

        ; Temporary device: used until the override ends; the saved device is untouched
        tmpSub := Menu()
        tmpSub.Add("Windows Default Device", SetTempAppOverride.Bind(exe, DEFAULT_DEVICE))
        if tmpDev = DEFAULT_DEVICE
            tmpSub.Check("Windows Default Device")
        for d in CachedDevices {
            if DeviceHidden(d.id, "t") && d.id != tmpDev
                continue
            tmpSub.Add(d.label, SetTempAppOverride.Bind(exe, d.id))
            if tmpDev = d.id
                tmpSub.Check(d.label)
        }
        ctx.Add("Temporarily Override", tmpSub)
        if !isEnabled || DisableAllRouting || DisableAppRouting
            ctx.Disable("Temporarily Override")

        ctx.Add()
        if AppFollowsFocus(exe) {
            itemAnchor := "Audio follows the focused window"
            ctx.Add(itemAnchor, (*) => 0)
            ctx.Disable(itemAnchor)
        } else {
            itemAnchor := "Audio follows this window"
            ctx.Add(itemAnchor, SetAnchorWindow.Bind(exe, winHwnd))
            if AnchorHwnd.Get(exe, 0) = winHwnd && !AnchorPending.Has(exe)
                ctx.Check(itemAnchor)
            if !isEnabled || DisableAllRouting
                ctx.Disable(itemAnchor)
        }

        ctx.Add()
        itemEn := "Enable Audio Routing for " exe
        ctx.Add(itemEn, (*) => ToggleAppRoutingEnabledByName(exe))
        if isEnabled
            ctx.Check(itemEn)

        ctx.Add()
        itemRem := Format("Remove `"{1}`" from Script", exe)
        ctx.Add(itemRem, (*) => RemoveAppByName(exe))
    } else {
        itemAdd := Format("Add `"{1}`" to Tracked Apps (Screen Rules)", exe)
        ctx.Add(itemAdd, (*) => QuickAddAppFromTitleBar(exe, winHwnd, false, DEFAULT_DEVICE))

        addOvrSub := Menu()
        addOvrSub.Add("Windows Default Device", (*) => QuickAddAppFromTitleBar(exe, winHwnd, true, DEFAULT_DEVICE))
        for d in CachedDevices {
            devLabel := d.label
            devId := d.id
            if DeviceHidden(devId, "a")
                continue
            addOvrSub.Add(devLabel, QuickAddAppFromTitleBar.Bind(exe, winHwnd, true, devId))
        }
        ctx.Add(Format("Add `"{1}`" && Override Audio", exe), addOvrSub)
    }

    CoordMode("Menu", "Screen")
    ctx.Show(mx, my)
}

; Device an app's override uses: the temporary device while one is set, else the
; device chosen in the GUI / "Select Override Device".
AppOverrideDevice(app) {
    return AppTempOverride.Has(app) ? AppTempOverride[app] : AppOverrideRules.Get(app, DEFAULT_DEVICE)
}

; A temporary device lives only while the app's override stays on: ending the override
; (title-bar menu, hotkey, tray, GUI or a reset) forgets it, and the next override uses
; the saved device again. Not kept across restarts.
PurgeTempOverrides() {
    for app in AppTempOverride.Clone() {
        if !Apps.Has(app) || !AppOverrideActive.Get(app, false)
            AppTempOverride.Delete(app)
    }
}

SetTempAppOverride(app, devId, *) {
    if !Apps.Get(app, false) || DisableAllRouting || DisableAppRouting
        return
    AppTempOverride[app] := devId
    if AllMode
        Released[app] := true
    AppOverrideActive[app] := true
    SaveState()
    SetupTrayMenu()
    RouteAppNow(app, true)
    PopulateAppList(true)
    RefreshSelectedAppPanel()
    UpdateOverrideBanner()

    mon := LastSeen.Get(app, 1)
    ShowOsdToast(Format("{1} plays on {2} (temporary)", FormatAppDisplayName(app), ShortDeviceName(devId)), mon)
}

SetAndActivateAppOverrideFromMenu(app, devId, *) {
    if !Apps.Has(app)
        return
    MapDel(AppTempOverride, app)
    if devId = DEFAULT_DEVICE
        MapDel(AppOverrideRules, app)
    else
        AppOverrideRules[app] := devId

    if AvoidConflicts
        SanitizeConfigConflicts(true)

    SaveConfig()
    if Apps.Get(app, false) && !DisableAllRouting && !DisableAppRouting {
        if AllMode
            Released[app] := true
        AppOverrideActive[app] := true
        SaveState()
    }
    SetupTrayMenu()
    RouteAppNow(app, true)
    PopulateAppList(true)
    RefreshSelectedAppPanel()
    UpdateOverrideBanner()

    mon := LastSeen.Get(app, 1)
    effDev := GetEffectiveDeviceForApp(app, mon)
    ShowOsdToast(Format("{1} plays on {2}", FormatAppDisplayName(app), ShortDeviceName(effDev)), mon)
}

QuickAddAppFromTitleBar(exe, winHwnd, activateOverride := false, overrideDevId := DEFAULT_DEVICE, *) {
    global SelectedApp
    if exe = ""
        return

    Apps[exe] := true
    SelectedApp := exe

    mon := 0
    try {
        if winHwnd && WinExist("ahk_id " winHwnd) {
            WinGetPos(&wx, &wy, &ww, &wh, "ahk_id " winHwnd)
            mon := MonitorAt(wx + ww // 2, wy + wh // 2)
            if mon > 0
                LastSeen[exe] := mon
        }
    }
    if !mon
        mon := LastSeen.Get(exe, MonitorGetPrimary())

    if activateOverride {
        if overrideDevId = DEFAULT_DEVICE
            MapDel(AppOverrideRules, exe)
        else
            AppOverrideRules[exe] := overrideDevId

        if AvoidConflicts
            SanitizeConfigConflicts(true)

        if !DisableAllRouting && !DisableAppRouting {
            if AllMode
                Released[exe] := true
            AppOverrideActive[exe] := true
        }
    }

    SaveConfig()
    SaveState()
    SetupTrayMenu()
    RenderDetectedList()
    PopulateAppList(true)
    RefreshSelectedAppPanel()
    UpdateOverrideBanner()

    RouteAppNow(exe, true)

    effDev := GetEffectiveDeviceForApp(exe, mon)
    ShowOsdToast(Format("{1} plays on {2}", FormatAppDisplayName(exe), ShortDeviceName(effDev)), mon)
}

ToggleAppRoutingEnabledByName(app) {
    if !Apps.Has(app)
        return
    newState := !Apps[app]
    Apps[app] := newState
    SaveConfig()

    if newState {
        MapDel(LastRouted, app)
        RouteAppNow(app, true)
        Tip(app " : routing enabled")
    } else {
        MapDel(AppOverrideActive, app)
        MapDel(LastRouted, app)
        SaveState()
        SetDevice(app, DEFAULT_DEVICE)
        SetupTrayMenu()
        UpdateOverrideBanner()
        Tip(app " : routing disabled")
    }
    PopulateAppList(true)
    RefreshSelectedAppPanel()
}

; ------------------------------ OSD NOTIFICATION ----------------------------
ShowOsdToast(text, targetMon := 1, kind := "") {
    global OsdGui, OsdTextCtrl
    if IsStartingUp
        return
    ; The previous toast's hide timer could fire between lines and destroy the toast
    ; being built (crash on GetPos), so stop it and build the new one uninterrupted.
    Critical
    SetTimer(HideOsdToast, 0)

    cnt := Max(MonitorGetCount(), 1)
    if targetMon < 1 || targetMon > cnt
        targetMon := MonitorGetPrimary()

    MonitorGetWorkArea(targetMon, &wl, &wt, &wr, &wb)

    try {
        if IsObject(OsdGui)
            OsdGui.Destroy()
    }
    OsdGui := ""

    g := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20 +Border")
    g.BackColor := kind = "warn" ? "7C2D12" : "18181B"
    g.MarginX := 16
    g.MarginY := 10
    g.SetFont("s10 Bold cF9FAFB", "Segoe UI")
    OsdTextCtrl := g.AddText("", text)

    ; Show off-screen first to measure exact DPI-scaled dimensions
    g.Show("NoActivate x-32000 y-32000 AutoSize")
    g.GetPos(, , &osdW, &osdH)

    posX := wr - osdW - 18
    posY := wt + 18
    if posX < wl + 10
        posX := wl + 10

    g.Show(Format("NoActivate x{1} y{2}", posX, posY))
    OsdGui := g
    SetTimer(HideOsdToast, -1000 * (kind = "warn" ? Max(ToastSec * 2, 6) : ToastSec))
    Critical("Off")
    if kind = "warn" && WarningSound
        try SoundPlay("*48")                       ; Windows "exclamation" sound
}
HideOsdToast() {
    global OsdGui
    try {
        if IsObject(OsdGui) {
            OsdGui.Destroy()
            OsdGui := ""
        }
    }
}

FormatAppDisplayName(exe) {
    name := RegExReplace(exe, "i)\.exe$", "")
    if name = ""
        return exe
    if name == StrLower(name)
        return StrUpper(SubStr(name, 1, 1)) . SubStr(name, 2)
    return name
}

; ------------------------------ TRAY MENU -----------------------------------
SetupTrayMenu() {
    A_TrayMenu.Delete()
    A_TrayMenu.Add("Open Screen Audio Router", ShowMainGui)

    itemRouting := "Routing Active"
    A_TrayMenu.Add(itemRouting, ToggleMasterRouting)
    if !DisableAllRouting
        A_TrayMenu.Check(itemRouting)

    A_TrayMenu.Add()

    Loop MAX_MONITORS {
        mIdx := A_Index
        isConnected := (mIdx <= DetectedMonCount)
        if isConnected && !IsMonitorDisabled(mIdx) {
            ovrDev := ShortDeviceName(MonitorOverrideRules.Get(mIdx, DEFAULT_DEVICE))
            mHk := MonHotkeys.Get(mIdx, "")
            mLabel := Format("Toggle Monitor {1} Override ({2})", mIdx, ovrDev) . (mHk != "" ? "`t" FormatHotkeyDisplay(mHk) : "")
            A_TrayMenu.Add(mLabel, ToggleMonitorOverrideByIndex.Bind(mIdx))
            if MonitorOverrideActive.Get(mIdx, false)
                A_TrayMenu.Check(mLabel)
            if DisableAllRouting || DisableMonitorRouting
                A_TrayMenu.Disable(mLabel)
        } else if isConnected {
            mLabel := Format("Toggle Monitor {1} Override (Routing Disabled)", mIdx)
            A_TrayMenu.Add(mLabel, (*) => 0)
            A_TrayMenu.Disable(mLabel)
        } else {
            mLabel := Format("Toggle Monitor {1} Override (Not Detected)", mIdx)
            A_TrayMenu.Add(mLabel, (*) => 0)
            A_TrayMenu.Disable(mLabel)
        }
    }

    lblAllMons := Format("Toggle All-Monitors Override ({1})", ShortDeviceName(AllMonitorsDevice)) . (HkOverrideAllMons != "" ? "`t" FormatHotkeyDisplay(HkOverrideAllMons) : "")
    A_TrayMenu.Add(lblAllMons, ToggleAllMonitorsOverride)
    if AllMonitorsMode
        A_TrayMenu.Check(lblAllMons)
    if DisableAllRouting || DisableMonitorRouting
        A_TrayMenu.Disable(lblAllMons)

    A_TrayMenu.Add()

    activeCount := 0
    if AllMode {
        lbl := Format("Reset Override : All-Apps ({1})", ShortDeviceName(AllDevice))
        A_TrayMenu.Add(lbl, ResetAllAppsOverrideFromTray)
        A_TrayMenu.Check(lbl)
        activeCount++
    }

    if AllMonitorsMode {
        lbl := Format("Reset Override : All-Monitors ({1})", ShortDeviceName(AllMonitorsDevice))
        A_TrayMenu.Add(lbl, ResetAllMonitorsOverrideFromTray)
        A_TrayMenu.Check(lbl)
        activeCount++
    }

    Loop DetectedMonCount {
        mIdx := A_Index
        if MonitorOverrideActive.Get(mIdx, false) {
            ovrDev := ShortDeviceName(MonitorOverrideRules.Get(mIdx, DEFAULT_DEVICE))
            lbl := Format("Reset Override : Monitor {1} ({2})", mIdx, ovrDev)
            A_TrayMenu.Add(lbl, ResetSingleMonitorOverride.Bind(mIdx))
            A_TrayMenu.Check(lbl)
            activeCount++
        }
    }

    for app in GetSortedApps() {
        if Apps.Get(app, false) && AppOverrideActive.Get(app, false) {
            ovrDev := ShortDeviceName(AppOverrideDevice(app)) (AppTempOverride.Has(app) ? ", temporary" : "")
            lbl := Format("Reset Override : {1} ({2})", app, ovrDev)
            A_TrayMenu.Add(lbl, ResetSingleAppOverride.Bind(app))
            A_TrayMenu.Check(lbl)
            activeCount++
        }
    }

    if activeCount = 0 {
        A_TrayMenu.Add("(No active overrides)", (*) => 0)
        A_TrayMenu.Disable("(No active overrides)")
    }

    A_TrayMenu.Add()
    A_TrayMenu.Add("End All App Overrides", ResetAllAppOverrides)
    A_TrayMenu.Add("End All Monitor Overrides", ResetAllMonitorOverrides)
    A_TrayMenu.Add("End All Overrides (Apps && Monitors)", ResetAllOverridesEverything)
    A_TrayMenu.Add()
    A_TrayMenu.Add("Replace Device...", ShowReplaceDeviceDialog)
    betaSub := Menu()
    betaSub.Add("Native audio (no SoundVolumeView)", ToggleNativeAudio)
    if NativeAudio
        betaSub.Check("Native audio (no SoundVolumeView)")
    betaSub.Add("Compare device IDs with SoundVolumeView", CompareNativeWithSvv)
    betaSub.Add()
    betaSub.Add("Debug log", ToggleDebugLog)
    if DebugLog
        betaSub.Check("Debug log")
    betaSub.Add("Open debug log", OpenDebugLog)
    A_TrayMenu.Add("Beta", betaSub)

    setSub := Menu()
    setSub.Add("Export settings...", ExportSettings)
    setSub.Add("Import settings...", ImportSettings)
    setSub.Add("Open settings folder", (*) => Run('explorer.exe "' A_ScriptDir '"'))
    setSub.Add()
    setSub.Add("Reset overrides to defaults...", ResetOverridesToDefaults)
    setSub.Add("Reset all settings...", ResetAllSettings)
    A_TrayMenu.Add("Settings", setSub)
    A_TrayMenu.Add("Start with Windows", ToggleAutoStartFromTray)
    if IsAutoStartEnabled()
        A_TrayMenu.Check("Start with Windows")
    A_TrayMenu.Add("Exit", ExitAppHandler)
    A_TrayMenu.Default := "Open Screen Audio Router"
    SetTimer(UpdateTrayIndicators, -60)
}

ResetAllAppsOverrideFromTray(*) {
    global AllMode
    if !AllMode
        return
    AllMode := false
    Released.Clear()
    SaveState()
    SetupTrayMenu()
    ReapplyAll(false, false)
    UpdateOverrideBanner()
    ShowOsdToast("All-Apps Override OFF", 1)
}

ResetAllMonitorsOverrideFromTray(*) {
    global AllMonitorsMode
    if !AllMonitorsMode
        return
    AllMonitorsMode := false
    PrevMonitorOverrideActive.Clear()
    SaveState()
    SetupTrayMenu()
    ReapplyAll(false, false)
    UpdateOverrideBanner()
    ShowOsdToast("All-Monitors Override OFF", 1)
}

ResetSingleMonitorOverride(mIdx, *) {
    global AllMonitorsMode
    if !MonitorOverrideActive.Get(mIdx, false)
        return
    MonitorOverrideActive[mIdx] := false
    if AllMonitorsMode {
        AllMonitorsMode := false
        PrevMonitorOverrideActive.Clear()
    }
    SaveState()
    SetupTrayMenu()
    ReapplyAll(false, false)
    UpdateOverrideBanner()
    normDev := MonitorRules.Get(mIdx, DEFAULT_DEVICE)
    ShowOsdToast(Format("Monitor {1} plays on {2}", mIdx, ShortDeviceName(normDev)), mIdx)
}

ResetSingleAppOverride(app, *) {
    if !AppOverrideActive.Get(app, false)
        return
    MapDel(AppOverrideActive, app)
    if AllMode
        MapDel(Released, app)
    SaveState()
    SetupTrayMenu()
    RouteAppNow(app, true)
    PopulateAppList(true)
    RefreshSelectedAppPanel()
    UpdateOverrideBanner()
    mon := LastSeen.Get(app, 1)
    effDev := GetEffectiveDeviceForApp(app, mon)
    ShowOsdToast(Format("{1} plays on {2}", FormatAppDisplayName(app), ShortDeviceName(effDev)), mon)
}

ResetAllAppOverrides(*) {
    global AllMode
    hadAny := AllMode || AppOverrideActive.Count > 0
    AppOverrideActive.Clear()
    AllMode := false
    Released.Clear()
    SaveState()
    SetupTrayMenu()
    ReapplyAll(false, false)
    RefreshSelectedAppPanel()
    UpdateOverrideBanner()
    if hadAny
        ShowOsdToast("All App Overrides Reset", 1)
    else
        Tip("No active app overrides to reset")
}

ResetAllMonitorOverrides(*) {
    global AllMonitorsMode
    hadAny := AllMonitorsMode || AnyMonitorOverrideActive()
    Loop MAX_MONITORS
        MonitorOverrideActive[A_Index] := false
    AllMonitorsMode := false
    PrevMonitorOverrideActive.Clear()
    SaveState()
    SetupTrayMenu()
    ReapplyAll(false, false)
    RefreshSelectedAppPanel()
    UpdateOverrideBanner()
    if hadAny
        ShowOsdToast("All Monitor Overrides Reset", 1)
    else
        Tip("No active monitor overrides to reset")
}

ResetAllOverridesEverything(*) {
    global AllMode, AllMonitorsMode
    hadAny := AllMode || AllMonitorsMode || AppOverrideActive.Count > 0 || AnyMonitorOverrideActive()
    AppOverrideActive.Clear()
    AllMode := false
    Released.Clear()
    Loop MAX_MONITORS
        MonitorOverrideActive[A_Index] := false
    AllMonitorsMode := false
    PrevMonitorOverrideActive.Clear()
    SaveState()
    SetupTrayMenu()
    ReapplyAll(false, false)
    RefreshSelectedAppPanel()
    UpdateOverrideBanner()
    if hadAny
        ShowOsdToast("All App & Monitor Overrides Reset", 1)
    else
        Tip("No active overrides to reset")
}

ExitAppHandler(*) {
    SaveAllNow()
    ExitApp()
}

; ------------------------------ TRAY STATE & OVERRIDE ICONS ----------------
; Main tray icon: 101 routing active, 102 partly disabled, 103 disabled (sor-icons.dll),
; with a tooltip naming the state. One extra tray icon per override that is actually
; in effect: monitor 1-4 (104-107), all monitors (108), each app and all apps (109).
; When every usable monitor (detected, not set to Disabled) is overridden, one 108 icon
; replaces the separate monitor icons, and its tooltip lists each monitor's device.
; Left-click an extra icon opens the window; right-click offers to end that override.
UpdateTrayIndicators() {
    global TrayMainState, NextAppTrayId
    reasons := []
    if DisableAllRouting {
        state := 103, status := "Routing disabled"
    } else {
        if DisableMonitorRouting
            reasons.Push("monitor routing off")
        if DisableAppRouting
            reasons.Push("app routing off")
        Loop DetectedMonCount {
            if IsMonitorDisabled(A_Index)
                reasons.Push("monitor " A_Index " disabled")
        }
        for nm in MissingAssignedNames()
            reasons.Push(nm " not connected")
        state := reasons.Length ? 102 : 101
        status := "Routing active"
        if reasons.Length {
            status := "Partly active : "
            for i, r in reasons
                status .= (i > 1 ? ", " : "") r
        }
    }

    want := Map()
    if !DisableAllRouting {
        if !DisableMonitorRouting {
            if AllMonitorsMode {
                want[2010] := {res: 108, kind: "allmons", key: 0
                    , tip: "All-Monitors override`n→ " TrayDevName(AllMonitorsDevice)}
            } else {
                ; Monitors that exist and are not set to Disabled; if all of them are
                ; overridden, one All-Monitors icon replaces the separate ones.
                active := [], usable := 0
                Loop Min(DetectedMonCount, 4) {
                    if IsMonitorDisabled(A_Index)
                        continue
                    usable++
                    if MonitorOverrideActive.Get(A_Index, false)
                        active.Push(A_Index)
                }
                if active.Length && active.Length = usable {
                    lines := []
                    for m in active
                        lines.Push("Monitor " m " → " TrayDevName(MonitorOverrideRules.Get(m, DEFAULT_DEVICE)))
                    want[2010] := {res: 108, kind: "monsall", key: active
                        , tip: TrayTipLines("All monitors overridden", lines)}
                } else {
                    for m in active
                        want[2000 + m] := {res: 103 + m, kind: "mon", key: m
                            , tip: "Monitor " m " override`n→ " TrayDevName(MonitorOverrideRules.Get(m, DEFAULT_DEVICE))}
                }
            }
        }
        if !DisableAppRouting {
            if AllMode
                want[2011] := {res: 109, kind: "allapps", key: ""
                    , tip: "All-Apps override`n→ " TrayDevName(AllDevice)}
            for app, on in AppOverrideActive {
                if !on || !Apps.Get(app, false) || AppHideTrayIcon.Has(app)   ; "Hide tray icon" ticked
                    continue
                if !AppTrayIds.Has(app)
                    AppTrayIds[app] := NextAppTrayId++
                want[AppTrayIds[app]] := {res: 109, kind: "app", key: app
                    , tip: app (AppTempOverride.Has(app) ? " temporary override" : " override") "`n→ " TrayDevName(AppOverrideDevice(app))}
            }
        }
    }

    n := want.Count
    A_IconTip := SubStr("Screen Audio Router v" APP_VERSION "`n" status (n ? "`n" n " override" (n = 1 ? "" : "s") " on" : ""), 1, 127)
    if state != TrayMainState {
        src := IconSource(state)
        if !src && state != 101
            src := IconSource(101)                   ; no state icon: normal icon
        try {
            if src
                TraySetIcon(src.file, src.num)
            else
                TraySetIcon("*")                     ; no icon files at all: default icon
            TrayMainState := state
        }
    }

    for id in ExtraIcons.Clone() {
        if !want.Has(id) {
            TrayIconCall(2, id)                      ; NIM_DELETE
            ExtraIcons.Delete(id)
        }
    }
    for id, w in want {
        if !ExtraIcons.Has(id) {
            if TrayIconCall(0, id, TrayIconHandle(w.res), w.tip)       ; NIM_ADD
                ExtraIcons[id] := w
        } else {
            cur := ExtraIcons[id]
            if cur.res != w.res || cur.tip != w.tip
                TrayIconCall(1, id, TrayIconHandle(w.res), w.tip)      ; NIM_MODIFY
            ExtraIcons[id] := w
        }
    }
}

; Device name without the "[driver]" part, to keep tray tooltips short.
TrayDevName(devId) {
    return RegExReplace(ShortDeviceName(devId), "\s*\[.*$")
}

; Header plus one line each, shortened evenly so the whole tooltip fits Windows' 127 characters.
TrayTipLines(header, lines) {
    per := lines.Length ? (127 - StrLen(header)) // lines.Length - 1 : 0
    t := header
    for l in lines
        t .= "`n" (StrLen(l) > per ? SubStr(l, 1, Max(1, per - 1)) Chr(0x2026) : l)
    return t
}

TrayIconCall(action, id, hIcon := 0, tip := "") {
    x64 := (A_PtrSize = 8)
    nid := Buffer(x64 ? 976 : 956, 0)                ; NOTIFYICONDATAW
    NumPut("UInt", nid.Size, nid, 0)
    NumPut("Ptr", A_ScriptHwnd, nid, x64 ? 8 : 4)
    NumPut("UInt", id, nid, x64 ? 16 : 8)
    if action != 2 {
        NumPut("UInt", 0x7, nid, x64 ? 20 : 12)      ; NIF_MESSAGE | NIF_ICON | NIF_TIP
        NumPut("UInt", TRAY_CB_MSG, nid, x64 ? 24 : 16)
        NumPut("Ptr", hIcon, nid, x64 ? 32 : 20)
        StrPut(SubStr(tip, 1, 127), nid.Ptr + (x64 ? 40 : 24), 128, "UTF-16")
    }
    return DllCall("shell32\Shell_NotifyIconW", "UInt", action, "Ptr", nid, "Int")
}

; Where icon resId (101-109) comes from: {file, num} for TraySetIcon / LoadPicture,
; or "" when there is no source (callers then use the default icon).
IconSource(resId) {
    static embedded := ""
    if embedded = "" {
        embedded := A_IsCompiled && DllCall("FindResourceW", "Ptr", DllCall("GetModuleHandleW", "Ptr", 0, "Ptr")
            , "Ptr", 101, "Ptr", 14, "Ptr") != 0            ; RT_GROUP_ICON 101 built into the exe
    }
    if embedded
        return {file: A_ScriptFullPath, num: -resId}
    if FileExist(IconDll)
        return {file: IconDll, num: -resId}
    for dir in [A_ScriptDir "\res\", A_ScriptDir "\"] {           ; res folder first, then next to the script
        f := dir IconFiles.Get(resId, "")
        if IconFiles.Has(resId) && FileExist(f)
            return {file: f, num: 1}
    }
    return ""
}

; Small icon at the size the tray wants (DPI aware), cached. Falls back to the
; exe's / AutoHotkey's own icon when icon resId has no source.
TrayIconHandle(resId) {
    static cache := Map()
    if cache.Has(resId)
        return cache[resId]
    cx := DllCall("GetSystemMetrics", "Int", 49), cy := DllCall("GetSystemMetrics", "Int", 50)
    h := 0
    src := IconSource(resId)
    if src && src.num = 1 {                                  ; a single .ico file
        h := DllCall("LoadImageW", "Ptr", 0, "Str", src.file, "UInt", 1, "Int", cx, "Int", cy, "UInt", 0x10, "Ptr")
    } else {
        id := src ? -src.num : 159                           ; 159 = the exe's / AutoHotkey's main icon
        hMod := (src && src.file != A_ScriptFullPath) ? TrayIconModule(src.file)
              : A_IsCompiled ? DllCall("GetModuleHandleW", "Ptr", 0, "Ptr") : TrayIconModule(A_AhkPath)
        if hMod {
            try DllCall("comctl32\LoadIconMetric", "Ptr", hMod, "Ptr", id, "Int", 0, "Ptr*", &h)   ; LIM_SMALL
            if !h
                h := DllCall("LoadImageW", "Ptr", hMod, "Ptr", id, "UInt", 1, "Int", cx, "Int", cy, "UInt", 0, "Ptr")
        }
    }
    cache[resId] := h
    return h
}

TrayIconModule(path) {
    static mods := Map()
    if !mods.Has(path)
        mods[path] := DllCall("LoadLibraryExW", "Str", path, "Ptr", 0, "UInt", 0x22, "Ptr")   ; AS_DATAFILE | AS_IMAGE_RESOURCE
    return mods[path]
}

OnExtraTrayIcon(wParam, lParam, msg, hwnd) {
    if !ExtraIcons.Has(wParam)
        return
    ev := lParam & 0xFFFF
    if ev = 0x202 {                                  ; WM_LBUTTONUP
        SetTimer(ShowMainGui, -10)
        return 0
    }
    if ev = 0x205 {                                  ; WM_RBUTTONUP
        info := ExtraIcons[wParam]
        SetTimer(() => ShowExtraTrayMenu(info), -10)
        return 0
    }
}

ShowExtraTrayMenu(info) {
    m := Menu()
    switch info.kind {
        case "mon":     m.Add("End Monitor " info.key " override", ResetSingleMonitorOverride.Bind(info.key))
        case "allmons": m.Add("End All-Monitors override", ResetAllMonitorsOverrideFromTray)
        case "monsall":
            m.Add("End all monitor overrides", ResetAllMonitorOverrides)
            m.Add()
            for mon in info.key
                m.Add("End Monitor " mon " override", ResetSingleMonitorOverride.Bind(mon))
        case "allapps": m.Add("End All-Apps override", ResetAllAppsOverrideFromTray)
        case "app":     m.Add("End override for " info.key, ResetSingleAppOverride.Bind(info.key))
    }
    m.Add()
    m.Add("Open Screen Audio Router", ShowMainGui)
    DllCall("SetForegroundWindow", "Ptr", A_ScriptHwnd)
    m.Show()
}

; Explorer restarted: every tray icon is gone, so add ours again.
OnTaskbarCreated(wParam, lParam, msg, hwnd) {
    global TrayMainState
    ExtraIcons.Clear()
    TrayMainState := 0
    SetTimer(UpdateTrayIndicators, -500)
}

RemoveExtraTrayIcons(*) {
    for id in ExtraIcons
        TrayIconCall(2, id)
    ExtraIcons.Clear()
}

; Removes entries of controls that no longer exist (GUI rebuilt or closed), so the maps
; do not grow and a reused window handle never picks up an old color or tooltip.
PurgeDeadControlMaps() {
    for m in [BtnColorMap, HoverTips, ThemedLVs, LvRowColors, ListHotRow, ListRowTips, CtrlColorCache, DdlItemCache, DarkChecks] {
        for h in m.Clone() {
            if !DllCall("IsWindow", "Ptr", h)
                m.Delete(h)
        }
    }
}

; ------------------------------ TRAY & OSD HELPERS --------------------------
ShowMonitorNumbers(*) {
    Loop Min(MonitorGetCount(), MAX_MONITORS) {
        MonitorGet(A_Index, &l, &t, &r, &b)
        ToolTip("Monitor " A_Index, (l + r) // 2 - 40, (t + b) // 2 - 15, 10 + A_Index)
    }
    SetTimer(ClearMonitorTips, -3000)
}

ClearMonitorTips() {
    Loop 10 {
        ToolTip(, , , 10 + A_Index)
    }
}

Tip(msg) {
    ToolTip(msg)
    SetTimer(ClearTip, -2500)
}

ClearTip() {
    ToolTip()
}
