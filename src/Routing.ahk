; Screen Audio Router - Copyright (C) 2026 panoc
; Licensed under the GNU GPL v3 or later. See LICENSE.
; ============================================================================
; Screen Audio Router  -  src\Routing.ahk
; Routing decisions, overrides, window tracking, display and device-change handling
; Part of ScreenAudioRouter.ahk (included at its end). Functions only.
; ============================================================================

; ------------------------------ MASTER ROUTING TOGGLE -----------------------
ToggleMasterRouting(*) {
    SetMasterRoutingEnabled(DisableAllRouting, true)
}

SetMasterRoutingEnabled(enable, showOsd := true) {
    global DisableAllRouting
    DisableAllRouting := !enable

    if IsObject(ChkDisableAll)
        ChkDisableAll.Value := DisableAllRouting ? 1 : 0
    if IsObject(ChkDisableMon)
        ChkDisableMon.Enabled := !DisableAllRouting
    if IsObject(ChkDisableApp)
        ChkDisableApp.Enabled := !DisableAllRouting
    if IsObject(BtnToggleRouting) {
        BtnToggleRouting.Text := DisableAllRouting ? "Routing : OFF" : "Routing : ON"
        SetButtonColor(BtnToggleRouting, DisableAllRouting ? BtnColorRoutingOff : BtnColorRoutingOn)
    }

    SaveSettings()
    UpdateRoutingModeLabel()
    SetupTrayMenu()

    if DisableAllRouting {
        ResetTrackedAppsToDefault()
        PopulateAppList(true)
        UpdateOverrideBanner()
        if showOsd
            ShowOsdToast("Routing DEACTIVATED", 1)
    } else {
        LastRouted.Clear()
        ReapplyAll(false)
        UpdateOverrideBanner()
        if showOsd
            ShowOsdToast("Routing ACTIVATED", 1)
    }
}

; ------------------------------ CONTRADICTION DETECTION & AVOIDANCE ---------
IsMonitorDisabled(mIdx) {
    return MonitorRules.Get(mIdx, DEFAULT_DEVICE) = DISABLED_MONITOR
}

FindAlternativeDevice(excludeId) {
    if excludeId != DEFAULT_DEVICE
        return DEFAULT_DEVICE
    for d in CachedDevices {
        if d.id != excludeId
            return d.id
    }
    return DEFAULT_DEVICE
}

GetActiveMonitorDevice(mon) {
    if !mon || IsMonitorDisabled(mon)
        return DEFAULT_DEVICE
    if AllMonitorsMode
        return AllMonitorsDevice
    if MonitorOverrideActive.Get(mon, false)
        return MonitorOverrideRules.Get(mon, DEFAULT_DEVICE)
    return MonitorRules.Get(mon, DEFAULT_DEVICE)
}

SanitizeConfigConflicts(silent := false) {
    changed := false
    Loop DetectedMonCount {
        mIdx := A_Index
        normDev := MonitorRules.Get(mIdx, DEFAULT_DEVICE)
        if normDev = DISABLED_MONITOR
            continue
        ovrDev  := MonitorOverrideRules.Get(mIdx, DEFAULT_DEVICE)
        if normDev != DEFAULT_DEVICE && normDev = ovrDev {
            alt := FindAlternativeDevice(normDev)
            if alt != normDev {
                if alt = DEFAULT_DEVICE
                    MapDel(MonitorOverrideRules, mIdx)
                else
                    MonitorOverrideRules[mIdx] := alt
                changed := true
                if !silent
                    Tip("Monitor " mIdx " Ovrd auto-adjusted to avoid matching Output")
            }
        }
    }

    ; (App overrides are left alone: one may use the same device as the app's monitor,
    ;  it then keeps the app on that device wherever its window goes.)

    if changed {
        SaveConfig()
        SetupTrayMenu()
    }
    return changed
}

DetectRuleConflicts() {
    conflicts := []

    if DisableAllRouting {
        if AllMode || AllMonitorsMode || AnyMonitorOverrideActive() || HasAnyActiveAppOverride() {
            conflicts.Push({
                type: "all_routing_disabled",
                msg: "All Routing is deactivated while overrides are active"
            })
        }
    }
    if DisableMonitorRouting && (AllMonitorsMode || AnyMonitorOverrideActive()) {
        conflicts.Push({
            type: "mon_routing_disabled",
            msg: "Monitor Routing is disabled while Monitor Override(s) are ON"
        })
    }
    if DisableAppRouting && (AllMode || HasAnyActiveAppOverride()) {
        conflicts.Push({
            type: "app_routing_disabled",
            msg: "App Routing is disabled while App/All-Apps Override(s) are ON"
        })
    }

    Loop DetectedMonCount {
        mIdx := A_Index
        normDev := MonitorRules.Get(mIdx, DEFAULT_DEVICE)
        if normDev = DISABLED_MONITOR
            continue
        ovrDev  := MonitorOverrideRules.Get(mIdx, DEFAULT_DEVICE)
        isOvrOn := MonitorOverrideActive.Get(mIdx, false)

        if normDev = ovrDev && (normDev != DEFAULT_DEVICE || isOvrOn) {
            conflicts.Push({
                type: "mon_same_dev",
                mon: mIdx,
                msg: Format("Mon {1} : Output & Ovrd use the same device ({2})", mIdx, ShortDeviceName(normDev))
            })
        }
    }

    if AllMonitorsMode {
        maskedMons := []
        Loop DetectedMonCount {
            if MonitorOverrideActive.Get(A_Index, false)
                maskedMons.Push("Mon " A_Index)
        }
        if maskedMons.Length > 0 {
            conflicts.Push({
                type: "allmons_masks_mon",
                msg: "All-Monitors Override masks " JoinStrings(maskedMons, ", ") " Override"
            })
        }
    }

    if AllMode {
        if AllMonitorsMode {
            conflicts.Push({
                type: "all_masks_allmons",
                msg: "All-Apps Override masks All-Monitors Override"
            })
        }

        maskedMons := []
        Loop DetectedMonCount {
            if MonitorOverrideActive.Get(A_Index, false)
                maskedMons.Push("Mon " A_Index)
        }
        if maskedMons.Length > 0 {
            conflicts.Push({
                type: "all_masks_mon",
                msg: "All-Apps Override masks " JoinStrings(maskedMons, ", ") " Override"
            })
        }

        maskedApps := []
        for app, isOvrOn in AppOverrideActive {
            if isOvrOn && Apps.Get(app, false) && !Released.Has(app)
                maskedApps.Push(app)
        }
        if maskedApps.Length > 0 {
            conflicts.Push({
                type: "all_masks_app",
                msg: "All-Apps Override masks App Override on " JoinStrings(maskedApps, ", ")
            })
        }
    }

    ; App overrides are not contradictions: they take priority over monitor rules by
    ; design, and one using the monitor's device pins the app to it.

    return conflicts
}

ResolveAllConflicts(*) {
    global AllMonitorsMode, AllMode

    if DisableAllRouting {
        AllMode := false
        Released.Clear()
        AppOverrideActive.Clear()
        Loop MAX_MONITORS
            MonitorOverrideActive[A_Index] := false
        AllMonitorsMode := false
        PrevMonitorOverrideActive.Clear()
    } else {
        if DisableMonitorRouting {
            Loop MAX_MONITORS
                MonitorOverrideActive[A_Index] := false
            AllMonitorsMode := false
            PrevMonitorOverrideActive.Clear()
        }
        if DisableAppRouting {
            AllMode := false
            Released.Clear()
            AppOverrideActive.Clear()
        }
    }

    SanitizeConfigConflicts(true)

    if AllMode {
        for app, isOvrOn in AppOverrideActive.Clone() {
            if isOvrOn && Apps.Get(app, false)
                Released[app] := true
        }
        Loop MAX_MONITORS {
            if MonitorOverrideActive.Get(A_Index, false)
                MonitorOverrideActive[A_Index] := false
        }
        AllMonitorsMode := false
        PrevMonitorOverrideActive.Clear()
    } else if AllMonitorsMode {
        Loop MAX_MONITORS
            MonitorOverrideActive[A_Index] := false
        PrevMonitorOverrideActive.Clear()
        AppOverrideActive.Clear()
    } else {
        for app, isOvrOn in AppOverrideActive.Clone() {
            if !isOvrOn
                continue
            mon := LastSeen.Get(app, 0)
            if mon && MonitorOverrideActive.Get(mon, false)
                MapDel(AppOverrideActive, app)
        }
    }

    SaveConfig()
    SaveState()
    SetupTrayMenu()
    PopulateMonitorDropdowns()
    PopulateOverrideDeviceDropdowns()
    RefreshSelectedAppPanel()
    ReapplyAll(false, false)
    UpdateOverrideBanner()
    Tip("All override contradictions resolved")
}

HasAnyActiveAppOverride() {
    for app, isOvrOn in AppOverrideActive {
        if isOvrOn && Apps.Get(app, false)
            return true
    }
    return false
}

; ------------------------------ DISPLAY CHANGE ------------------------------
OnWmDisplayChange(wParam, lParam, msg, hwnd) {
    SetTimer(HandleDisplayChange, -600)
}

HandleDisplayChange() {
    global DetectedMonCount, GuiDirty, DevicesStale, KnownMonSignature
    sig := GetMonitorLayoutSignature()
    if sig = KnownMonSignature
        return
    KnownMonSignature := sig
    DetectedMonCount := Min(Max(MonitorGetCount(), 1), MAX_MONITORS)
    DevicesStale := true     ; HDMI/DP audio endpoints come and go with monitors
    GuiDirty := true         ; monitor states are rebuilt before the window is next shown

    Loop MAX_MONITORS {
        mIdx := A_Index
        if mIdx <= DetectedMonCount && !IsMonitorDisabled(mIdx) {
            if !RegMonHotkeys.Has(mIdx) && MonHotkeys.Has(mIdx)
                RegisterMonitorHotkey(mIdx, MonHotkeys[mIdx], true)
        } else {
            MonitorOverrideActive[mIdx] := false
            if RegMonHotkeys.Has(mIdx) {
                try Hotkey(RegMonHotkeys[mIdx], "Off")
                MapDel(RegMonHotkeys, mIdx)
            }
        }
    }
    SetupTrayMenu()
    ReapplyAll(false)

    ; Only a window the user is looking at is rebuilt now. Otherwise it waits for
    ; the next ShowMainGui(): no device re-scan and no GUI work in the background.
    try {
        if IsObject(MainGui) && DllCall("IsWindowVisible", "Ptr", MainGui.Hwnd)
            RebuildMainGuiIfNeeded(true)
    }
}

GetMonitorLayoutSignature() {
    cnt := Max(MonitorGetCount(), 1)
    pri := MonitorGetPrimary()
    sig := cnt "|" pri
    Loop cnt {
        MonitorGet(A_Index, &l, &t, &r, &b)
        sig .= "|" A_Index ":" l "," t "," r "," b
    }
    return sig
}

RebuildMainGuiIfNeeded(force := false) {
    global IsRebuildingGui, CachedDevices, GuiDirty, DevicesStale
    sig := GetMonitorLayoutSignature()
    if !force && sig = BuiltMonSignature
        return

    wasVisible := false
    prevX := "", prevY := ""
    try {
        if IsObject(MainGui) && WinExist("ahk_id " MainGui.Hwnd) {
            wasVisible := DllCall("IsWindowVisible", "Ptr", MainGui.Hwnd) ? true : false
            if wasVisible
                MainGui.GetPos(&prevX, &prevY)
        }
    }

    IsRebuildingGui := true
    if ActiveCaptureHwnd != 0
        StopHotkeyCapture(false)
    Suspend(false)
    if IsObject(DetectWindow)
        CloseDetectWindow()
    try {
        if IsObject(MainGui)
            MainGui.Destroy()
    }
    if DevicesStale {
        CachedDevices := GetDevices()
        DevicesStale := false
    }
    BuildMainGui()
    GuiDirty := false
    PopulateMonitorDropdowns()
    PopulateOverrideDeviceDropdowns()
    PopulateAppList(true)
    RefreshSelectedAppPanel()
    UpdateOverrideBanner()
    RefreshHotkeyIndicators()
    IsRebuildingGui := false

    if wasVisible {
        if IsInteger(prevX) && IsInteger(prevY)
            MainGui.Show(Format("x{1} y{2} w1148", prevX, prevY))
        else
            MainGui.Show("w1148")
    }
}

; ------------------------------ WINDOW EVENTS -------------------------------
; Low-volume WinEvents (foreground change, end of a move/resize, restore from
; minimize) trigger an immediate re-check. EVENT_OBJECT_LOCATIONCHANGE is NOT
; hooked on purpose: it fires for every cursor/caret/animation update system-wide.
; A slow poll stays as a safety net for moves that raise no event (tiling tools,
; programmatic moves) and for apps that start or appear.
InstallWinEventHooks() {
    global WinEventCb, EventsActive
    if !UseWinEvents
        return
    try {
        WinEventCb := CallbackCreate(WinEventProc, , 7)
        for ev in [0x0003, 0x000B, 0x0017] {   ; FOREGROUND, MOVESIZEEND, MINIMIZEEND
            ; flags 2 = WINEVENT_OUTOFCONTEXT | WINEVENT_SKIPOWNPROCESS
            h := DllCall("SetWinEventHook", "UInt", ev, "UInt", ev, "Ptr", 0, "Ptr", WinEventCb
                , "UInt", 0, "UInt", 0, "UInt", 2, "Ptr")
            if h
                WinEventHooks.Push(h)
        }
        EventsActive := WinEventHooks.Length > 0
        OnExit(RemoveWinEventHooks)
    }
}

RemoveWinEventHooks(*) {
    global WinEventCb
    for h in WinEventHooks
        DllCall("UnhookWinEvent", "Ptr", h)
    WinEventHooks.Length := 0
    if WinEventCb {
        CallbackFree(WinEventCb)
        WinEventCb := 0
    }
}

WinEventProc(hHook, event, hwnd, idObject, idChild, idThread, eventTime) {
    if idObject != 0 || !Apps.Count        ; OBJID_WINDOW only; skip if nothing tracked
        return
    SetTimer(OnWinEventSettled, -120)      ; debounce bursts into one check
}

OnWinEventSettled() {
    global ScanStamp
    ScanStamp := 0                         ; force fresh process/window snapshot
    Tick()
}

KeySnapSettle() {
    SetTimer(OnWinEventSettled, -400)
}

ApplyPollTimer() {
    SetTimer(Tick, EventsActive ? FallbackPollMs : PollMs)
}

; WM_DEVICECHANGE fires for every USB stick, dock or Bluetooth device. The playback
; devices are then read from the registry (a few ms) at about 1, 3 and 8 s, so a slow
; first-time driver install is caught too. Only a real change in active playback devices
; marks the device list stale, re-applies routing and warns about assigned devices.
; A menu or the window opened while a check is pending runs it at once.
OnWmDeviceChange(wParam, lParam, msg, hwnd) {
    global DeviceCheckPending, DeviceCheckStage
    DeviceCheckPending := true
    DeviceCheckStage := 0
    SetTimer(CheckAudioEndpoints, -1000)  ; device events come in bursts
}

; After the PC wakes up, monitors and their HDMI audio come back one by one: re-check the
; devices (at ~5, 8 and 13 s) and re-apply routing, whatever order the device messages came in.
OnWmPowerBroadcast(wParam, lParam, msg, hwnd) {
    if wParam = 7 || wParam = 0x12 {               ; PBT_APMRESUMESUSPEND / PBT_APMRESUMEAUTOMATIC
        LogLine("Resumed from sleep")
        SetTimer(AfterResume, -5000)
    }
}

AfterResume() {
    global DeviceCheckPending, DeviceCheckStage, DeviceWarnReadyAt
    DeviceWarnReadyAt := A_TickCount + 10000      ; let devices settle before warning
    RefreshNativeDeviceList()
    DeviceCheckPending := true
    DeviceCheckStage := 0
    CheckAudioEndpoints()                          ; also schedules the 3 s / 8 s re-checks
    ReapplyAll(false, true)
    LogLine("Routing re-applied after wake-up")
}

CheckAudioEndpoints() {
    global DeviceCheckPending, DeviceCheckStage
    RunEndpointCheck()
    DeviceCheckStage++
    if DeviceCheckStage = 1
        SetTimer(CheckAudioEndpoints, -2000)       ; ~3 s after the device change
    else if DeviceCheckStage = 2
        SetTimer(CheckAudioEndpoints, -5000)       ; ~8 s
    else
        DeviceCheckPending := false
}

; Runs a pending device check right away (title-bar menu, main window).
CheckAudioEndpointsNow() {
    if DeviceCheckPending
        RunEndpointCheck()
}

RunEndpointCheck() {
    global DevicesStale, CachedDevices
    if !RefreshEndpointState()
        return
    DevicesStale := true
    if NativeAudio {                               ; native list takes ms: re-read it before re-routing,
        try {                                      ; so a device that came back has its Windows id again
            CachedDevices := GetDevices()
            DevicesStale := false
        }
    }

    gone := [], back := []
    uses := AssignedDeviceUses()
    for n, u in uses {
        if !DevicePresent(u.id) {
            if !WarnedMissing.Has(n) {
                WarnedMissing[n] := u.id
                gone.Push(u)
            }
        } else if WarnedMissing.Has(n) {
            WarnedMissing.Delete(n)
            back.Push(u)
        }
    }
    for n, id in WarnedMissing.Clone() {           ; no longer assigned and back: forget quietly
        if !uses.Has(n) && DevicePresent(id)
            WarnedMissing.Delete(n)
    }
    for k, id in WarnedApp.Clone() {               ; device back: warn again next time it goes
        if DevicePresent(id)
            WarnedApp.Delete(k)
    }

    ; running apps routed to a device that just went away (they are named in the warning)
    affected := Map()                              ; device -> apps that were playing on it
    for app, r in LastRouted {
        if IsObject(r) && r.dev != DEFAULT_DEVICE && !DevicePresent(r.dev) {
            n := DevKey(r.dev)
            for u in gone {
                if DevKey(u.id) = n {
                    if !affected.Has(n)
                        affected[n] := []
                    affected[n].Push(app)
                    WarnedApp[app "|" n] := r.dev
                }
            }
        }
    }

    ReapplyAll(false, true)                        ; a device came or went: route everything again
    SetTimer(UpdateTrayIndicators, -60)

    ; window open: show the new device list now (dropdowns, disconnected marks)
    try {
        if IsObject(MainGui) && DllCall("IsWindowVisible", "Ptr", MainGui.Hwnd) {
            if DevicesStale {
                CachedDevices := GetDevices()
                DevicesStale := false
            }
            PopulateMonitorDropdowns()
            PopulateOverrideDeviceDropdowns()
            RefreshSelectedAppPanel()
            PopulateAppList(true)
        }
    }

    for u in gone
        LogLine("Device gone : " ShortDeviceName(u.id) "  (used by " u.text ")")
    for u in back
        LogLine("Device back : " ShortDeviceName(u.id))
    if DeviceWarnings && (gone.Length || back.Length) {
        ; one notification for everything that changed (a second one would replace the first)
        msg := "", mon := 0
        for u in gone {
            n := DevKey(u.id)
            msg .= (msg = "" ? "" : "`n`n") Chr(0x26A0) " " ShortDeviceName(u.id) " disconnected`nUsed by : " u.text
            if affected.Has(n) {
                now := ""
                for app in affected[n] {
                    r := LastRouted.Get(app, "")
                    now .= (now = "" ? "" : ", ") app " " Chr(0x2192) " " TrayDevName(IsObject(r) ? r.dev : DEFAULT_DEVICE)
                }
                msg .= "`nNow playing : " now
            }
            mon := mon ? mon : u.mon
        }
        for u in back {
            msg .= (msg = "" ? "" : "`n`n") Chr(0x2714) " " ShortDeviceName(u.id) " connected again`nRouting restored"
            mon := mon ? mon : u.mon
        }
        ShowOsdToast(msg, mon, gone.Length ? "warn" : "")
    }
}

; Reads the playback devices from the registry. Returns true when the active set changed.
; Ids are rebuilt in SoundVolumeView's "Command-Line Friendly ID" form
; ("<adapter>\Device\<name>\Render") so they compare with the saved ones.
RefreshEndpointState() {
    global AudioEndpointSig, EndpointActive, EndpointKnown, EndpointActiveX, EndpointKnownX
    act := Map(), known := Map(), actX := Map(), knownX := Map(), cnt := Map()
    act.CaseSense := false, known.CaseSense := false, actX.CaseSense := false, knownX.CaseSense := false
    cnt.CaseSense := false
    sig := ""
    try {
        Loop Reg, "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\MMDevices\Audio\Render", "K" {
            key := A_LoopRegKey "\" A_LoopRegName
            st := 0, name := "", adapter := ""
            try st := RegRead(key, "DeviceState")
            try name := RegRead(key "\Properties", "{a45c254e-df1c-4efd-8020-67d146a850e0},2")
            try adapter := RegRead(key "\Properties", "{b3f8fa53-0004-438e-9003-51a46e139bfc},6")
            if adapter = ""
                try adapter := RegRead(key "\Properties", "{026e516e-b814-414b-83cd-856d6fef4822},2")
            if name != "" && adapter != "" {
                full := adapter "\Device\" name "\Render"
                n := NormDevId(full)
                known[n] := true, knownX[full] := true
                if st = 1 {
                    act[n] := true, actX[full] := true
                    cnt[n] := cnt.Get(n, 0) + 1
                }
            }
            if st = 1
                sig .= A_LoopRegName "|"
        }
    }
    changed := (sig != AudioEndpointSig)
    AudioEndpointSig := sig
    EndpointActive := act, EndpointKnown := known
    EndpointActiveX := actX, EndpointKnownX := knownX
    for n, c in cnt {
        if c >= 2
            LearnIdentical(n)
    }
    return changed
}

; Device id without the "2- " Windows puts in front of a device's name when it is
; plugged into another port (or a second identical one is added), so
; "2- USB Audio Device\Device\Speakers\Render" counts as the same device.
NormDevId(id) {
    return RegExReplace(Trim(id), "(^|\\)\d+-\s*", "$1")
}

; Key that identifies a device in warnings and lookups: its exact id when you own two
; of that device (so they stay apart), otherwise the renumber-proof normalized id.
DevKey(id) {
    n := NormDevId(id)
    return MultiDevNames.Has(n) ? Trim(id) : n
}

; Remembers that two devices with the same name were active at the same time.
LearnIdentical(n) {
    if MultiDevNames.Has(n)
        return
    MultiDevNames[n] := true
    ScheduleSave()
}

; The entry of the current device list that is this device: exact id first, then (only
; for a device you own one of) the same device under a renumbered name.
FindCachedDevice(id) {
    if id = "" || id = DEFAULT_DEVICE
        return ""
    for d in CachedDevices {
        if d.id = id
            return d
    }
    n := NormDevId(id)
    if MultiDevNames.Has(n)                        ; two of them: never swap one for the other
        return ""
    for d in CachedDevices {
        if NormDevId(d.id) = n
            return d
    }
    return ""
}

; The id to hand to SoundVolumeView: the device's current id when it was renumbered.
ResolveDeviceId(id) {
    d := FindCachedDevice(id)
    return IsObject(d) ? d.id : id
}

; True unless Windows knows the device and it is not active (unplugged, disabled,
; removed). A device the registry scan cannot match is treated as present: no false alarms.
DevicePresent(id) {
    if id = "" || id = DEFAULT_DEVICE || id = DISABLED_MONITOR
        return true
    n := NormDevId(id)
    if MultiDevNames.Has(n) {                      ; two of them: exact id only
        if EndpointKnownX.Has(Trim(id))
            return EndpointActiveX.Has(Trim(id))
        if CachedDevices.Length && !DevicesStale
            return IsObject(FindCachedDevice(id))
        return true
    }
    if EndpointKnown.Has(n)
        return EndpointActive.Has(n)
    ; unknown to the registry scan: trust the device list when it is loaded and current
    if CachedDevices.Length && !DevicesStale
        return IsObject(FindCachedDevice(id))
    return true
}

; Devices the current settings actually use: device -> {id, text (who uses it), mon}.
AssignedDeviceUses() {
    uses := Map()
    uses.CaseSense := false
    add(id, who, mon := 0) {
        if id = "" || id = DEFAULT_DEVICE || id = DISABLED_MONITOR
            return
        n := DevKey(id)
        if uses.Has(n)
            uses[n].text .= ", " who
        else
            uses[n] := {id: id, text: who, mon: mon}
    }
    if DisableAllRouting
        return uses
    if !DisableMonitorRouting {
        Loop DetectedMonCount {
            m := A_Index
            if IsMonitorDisabled(m)
                continue
            if AllMonitorsMode
                add(AllMonitorsDevice, "All-Monitors override", m)
            else if MonitorOverrideActive.Get(m, false)
                add(MonitorOverrideRules.Get(m, DEFAULT_DEVICE), "Monitor " m " override", m)
            else if MonitorRules.Has(m)
                add(MonitorRules[m], "Monitor " m " output", m)
        }
    }
    if !DisableAppRouting {
        if AllMode
            add(AllDevice, "All-Apps override")
        for app, on in AppOverrideActive {
            if on && Apps.Get(app, false)
                add(AppOverrideDevice(app), app (AppTempOverride.Has(app) ? " temporary override" : " override"), LastSeen.Get(app, 0))
        }
        for app, dev in AppFixedDevice {
            if Apps.Get(app, false)
                add(dev, app " fixed device", LastSeen.Get(app, 0))
        }
    }
    return uses
}

; Status / label text for a device, flagged when it is not connected.
DevStatusName(id) {
    return ShortDeviceName(id) (DevicePresent(id) ? "" : "  " Chr(0x26A0) " not connected")
}

; Assigned devices that are missing right now, for the tray tooltip.
MissingAssignedNames() {
    names := []
    for n, u in AssignedDeviceUses() {
        if !DevicePresent(u.id)
            names.Push(TrayDevName(u.id))
    }
    return names
}


; ------------------------------ MAIN LOOP & ROUTING -------------------------
Tick() {
    global LastFocusedTrackedApp, LastForegroundHwnd
    fg := WinExist("A")
    if fg != LastForegroundHwnd {
        LastForegroundHwnd := fg
        curFoc := FocusedApp()
        if curFoc != ""
            LastFocusedTrackedApp := curFoc
    }

    if DisableAllRouting
        return

    for app, enabled in Apps {
        if enabled
            try RouteAppNow(app, false)
    }
}

GetEffectiveDeviceForApp(app, mon) {
    return GetRoutingTarget(app, mon).dev
}

; Device an app should play on, in priority order: app override, All-Apps override,
; the app's fixed device ("Follow monitor" off), (monitor set to Disabled -> Windows default), All-Monitors override, monitor
; override, monitor output, Windows default. A device that is not connected is
; skipped, so the next one down is used: a missing override falls back to the
; monitor's output, a missing output to the Windows default.
; Returns {dev, missing}: missing = the device that should have been used, or "".
GetRoutingTarget(app, mon) {
    if DisableAllRouting
        return {dev: DEFAULT_DEVICE, missing: ""}
    cands := []
    if !DisableAppRouting && AppOverrideActive.Get(app, false)
        cands.Push(AppOverrideDevice(app))
    if !DisableAppRouting && AllMode && !Released.Has(app)
        cands.Push(AllDevice)
    if !DisableAppRouting && AppFixedDevice.Has(app)          ; "Follow monitor" unticked
        cands.Push(AppFixedDevice[app])
    monOk := mon && mon <= DetectedMonCount
    if !(monOk && IsMonitorDisabled(mon)) && !DisableMonitorRouting && mon {
        if AllMonitorsMode
            cands.Push(AllMonitorsDevice)
        if monOk && MonitorOverrideActive.Get(mon, false)
            cands.Push(MonitorOverrideRules.Get(mon, DEFAULT_DEVICE))
        if monOk && MonitorRules.Has(mon)
            cands.Push(MonitorRules[mon])
    }
    missing := ""
    for dev in cands {
        if DevicePresent(dev)
            return {dev: dev, missing: missing}
        if missing = ""
            missing := dev
    }
    return {dev: DEFAULT_DEVICE, missing: missing}
}

RouteAppNow(app, force := false) {
    if DisableAllRouting || !Apps.Get(app, false)
        return
    if !AppRunning(app) {
        MapDel(LastRouted, app)
        return
    }

    prev := LastRouted.Get(app, "")
    prevMon := IsObject(prev) ? prev.mon : 0
    prevDev := IsObject(prev) ? prev.dev : ""

    mon := CurrentMonitor(app)
    tgt := GetRoutingTarget(app, mon)
    targetDev := tgt.dev

    if !force && IsObject(prev) && prevMon = mon && prevDev = targetDev
        return

    LastRouted[app] := {mon: mon, dev: targetDev}
    LogLine(Format("Route {1}  mon {2}  -> {3}{4}", app, mon, ShortDeviceName(targetDev)
        , tgt.missing != "" ? "   (" ShortDeviceName(tgt.missing) " missing)" : ""))
    SetDevice(app, targetDev)

    if DeviceWarnings && !IsStartingUp && A_TickCount >= DeviceWarnReadyAt && tgt.missing != "" {
        k := app "|" DevKey(tgt.missing)
        if !WarnedApp.Has(k) {                     ; once per app and device, until it returns
            WarnedApp[k] := tgt.missing
            WarnedMissing[DevKey(tgt.missing)] := tgt.missing
            ShowOsdToast(Format("{1} {2} : {3} is not connected`nPlaying on {4} instead"
                , Chr(0x26A0), FormatAppDisplayName(app), ShortDeviceName(tgt.missing), ShortDeviceName(targetDev)), mon, "warn")
            return
        }
    }

    if mon > 0 && ((prevMon > 0 && mon != prevMon) || (prevDev != "" && targetDev != prevDev)) {
        ShowOsdToast(Format("{1} plays on {2}", FormatAppDisplayName(app), ShortDeviceName(targetDev)), mon)
    }
}

; ------------------------------ INSTANT OVERRIDES ---------------------------
ToggleFocused(*) {
    app := FocusedApp()
    if !app {
        Tip("Focused window isn't one of the tracked apps")
        return
    }
    ToggleAppOverrideByName(app)
}

ToggleFocusedFromGui(*) {
    if SelectedApp != "" && Apps.Has(SelectedApp) {
        ToggleAppOverrideByName(SelectedApp)
        return
    }
    if LastFocusedTrackedApp != "" && Apps.Has(LastFocusedTrackedApp) {
        ToggleAppOverrideByName(LastFocusedTrackedApp)
        return
    }
    Tip("Select an app in Tracked Applications, or press " FormatHotkeyDisplay(HkOverrideFocused) " inside a tracked app")
}

ToggleAppOverrideByName(app, *) {
    if !Apps.Has(app)
        return
    if !Apps[app] {
        Tip(app " : routing is disabled (check its box in the GUI first)")
        return
    }
    if DisableAllRouting || DisableAppRouting {
        Tip("Cannot toggle App Override while App Routing or Routing is deactivated")
        return
    }

    newState := !AppOverrideActive.Get(app, false)

    if newState {
        if AllMode
            Released[app] := true
        MapDel(AppTempOverride, app)       ; a plain toggle uses the saved device
        AppOverrideActive[app] := true
    } else {
        MapDel(AppOverrideActive, app)
        if AllMode
            MapDel(Released, app)
    }

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

ToggleMonitorOverrideByIndex(mIdx, *) {
    global AllMode, AllMonitorsMode
    if mIdx < 1 || mIdx > DetectedMonCount {
        Tip("Monitor " mIdx " is not currently detected")
        return
    }
    if IsMonitorDisabled(mIdx) {
        Tip("Monitor " mIdx " routing is Disabled")
        return
    }

    newState := !MonitorOverrideActive.Get(mIdx, false)

    if newState {
        if DisableAllRouting || DisableMonitorRouting {
            Tip("Cannot toggle Monitor Override while Monitor Routing or Routing is deactivated")
            return
        }

        normDev := MonitorRules.Get(mIdx, DEFAULT_DEVICE)
        ovrDev  := MonitorOverrideRules.Get(mIdx, DEFAULT_DEVICE)

        if AvoidConflicts && normDev = ovrDev {
            Tip(Format("Monitor {1} : Override device matches Output ({2}) — pick a different Ovrd device first", mIdx, ShortDeviceName(normDev)))
            return
        }

        if AvoidConflicts {
            if AllMode {
                AllMode := false
                Released.Clear()
            }
            if AllMonitorsMode {
                AllMonitorsMode := false
                PrevMonitorOverrideActive.Clear()
            }
            for app, isOvrOn in AppOverrideActive.Clone() {
                if isOvrOn && LastSeen.Get(app, 0) = mIdx
                    MapDel(AppOverrideActive, app)
            }
        }
    }

    MonitorOverrideActive[mIdx] := newState

    SaveState()
    SetupTrayMenu()
    ReapplyAll(false, false)
    RefreshSelectedAppPanel()
    UpdateOverrideBanner()

    if newState {
        ovrDev := MonitorOverrideRules.Get(mIdx, DEFAULT_DEVICE)
        ShowOsdToast(Format("Monitor {1} plays on {2}", mIdx, ShortDeviceName(ovrDev)), mIdx)
    } else {
        normDev := MonitorRules.Get(mIdx, DEFAULT_DEVICE)
        ShowOsdToast(Format("Monitor {1} plays on {2}", mIdx, ShortDeviceName(normDev)), mIdx)
    }
}

ToggleAllMonitorsOverride(*) {
    global AllMode, AllMonitorsMode

    if AllMonitorsMode {
        AllMonitorsMode := false
        PrevMonitorOverrideActive.Clear()

        SaveState()
        SetupTrayMenu()
        ReapplyAll(false, false)
        UpdateOverrideBanner()
        ShowOsdToast("All-Monitors Override OFF", 1)
        return
    }

    if AnyEffectiveMonitorOverride() {       ; monitor overrides on: first press returns them all to normal
        ResetAllMonitorOverrides()
        return
    }

    if DisableAllRouting || DisableMonitorRouting {
        Tip("Cannot toggle All-Monitors Override while Monitor Routing or Routing is deactivated")
        return
    }

    if AvoidConflicts {
        if AllMode {
            AllMode := false
            Released.Clear()
        }
        AppOverrideActive.Clear()
        Loop MAX_MONITORS
            MonitorOverrideActive[A_Index] := false
        PrevMonitorOverrideActive.Clear()
    }

    AllMonitorsMode := true
    SaveState()
    SetupTrayMenu()
    ReapplyAll(false, false)
    RefreshSelectedAppPanel()
    UpdateOverrideBanner()

    ShowOsdToast(Format("All Monitors play on {1}", ShortDeviceName(AllMonitorsDevice)), 1)
}

ToggleAll(*) {
    global AllMode, AllMonitorsMode
    if AllMode {
        AllMode := false
        Released.Clear()
        SaveState()
        SetupTrayMenu()
        ReapplyAll(false, false)
        UpdateOverrideBanner()
        ShowOsdToast("All-Apps Override OFF", 1)
        return
    }

    if AnyAppOverrideActive() {              ; app overrides on: first press returns them all to normal
        ResetAllAppOverrides()
        return
    }

    if DisableAllRouting || DisableAppRouting {
        Tip("Cannot toggle All-Apps Override while App Routing or Routing is deactivated")
        return
    }

    if AvoidConflicts {
        Loop MAX_MONITORS {
            MonitorOverrideActive[A_Index] := false
        }
        AllMonitorsMode := false
        PrevMonitorOverrideActive.Clear()
        AppOverrideActive.Clear()
    }

    AllMode := true
    Released.Clear()
    SaveState()
    SetupTrayMenu()
    ReapplyAll(false, false)
    RefreshSelectedAppPanel()
    UpdateOverrideBanner()
    ShowOsdToast(Format("All Apps play on {1}", ShortDeviceName(AllDevice)), 1)
}

; Sends every enabled tracked app back to the Windows default device.
ResetTrackedAppsToDefault() {
    for app, enabled in Apps {
        if enabled
            SetDevice(app, DEFAULT_DEVICE)
    }
    LastRouted.Clear()
}

ReapplyAll(showTip := true, force := true, *) {
    if DisableAllRouting {
        PopulateAppList(true)
        if showTip
            Tip("Routing is currently deactivated")
        return
    }
    for app, enabled in Apps {
        if enabled
            RouteAppNow(app, force ? true : false)
    }
    PopulateAppList(true)
    if showTip
        Tip("Routing re-applied")
}

; ------------------------------ ANCHOR WINDOW ------------------------------
; Windows routes audio per program, not per window, so one window per app decides
; the monitor. By default that is the app's first window (the "anchor"): focusing or
; dragging its other windows changes nothing, moving the anchor moves the audio, and
; "Audio follows this window" in the title-bar menu picks another one. If the anchor
; closes while other windows remain, the next one is adopted but the audio stays put
; until that window reaches another monitor. Nothing is remembered once the app closes.
; Apps set to follow focus use their topmost window instead (the old behaviour).
FindWindow(app) {
    top := AppWindow(app)                          ; topmost visible window (shared scan)
    if AppFollowsFocus(app) {
        MapDel(AnchorHwnd, app)
        MapDel(AnchorPending, app)
        return top
    }
    a := AnchorHwnd.Get(app, 0)
    if a && !DllCall("IsWindow", "Ptr", a) {       ; anchor closed, app still running
        MapDel(AnchorHwnd, app)
        MapDel(AnchorPending, app)
        if top {
            AnchorHwnd[app] := top
            AnchorPending[app] := WindowMonitor(top)
        }
        return 0                                   ; keep the last known monitor
    }
    if !a {
        if top
            AnchorHwnd[app] := top                 ; first window seen (app start or script start)
        return top
    }
    if AnchorPending.Has(app) {
        m := WindowMonitor(a)
        if !m || m = AnchorPending[app]
            return 0
        AnchorPending.Delete(app)                  ; it reached another monitor: follow it from now on
    }
    return a
}

AppFollowsFocus(app) {
    return AppFollowFocus.Has(app) ? AppFollowFocus[app] : FollowFocusGlobal
}

; Monitor under the window's center; 0 when it is hidden or minimized.
WindowMonitor(hwnd) {
    if !hwnd || !DllCall("IsWindowVisible", "Ptr", hwnd) || DllCall("IsIconic", "Ptr", hwnd)
        return 0
    rc := Buffer(16, 0)
    if !DllCall("GetWindowRect", "Ptr", hwnd, "Ptr", rc)
        return 0
    l := NumGet(rc, 0, "Int"), t := NumGet(rc, 4, "Int")
    return MonitorAt(l + (NumGet(rc, 8, "Int") - l) // 2, t + (NumGet(rc, 12, "Int") - t) // 2)
}

SetAnchorWindow(app, hwnd, *) {
    global ScanStamp
    if !Apps.Has(app) || !hwnd
        return
    AnchorHwnd[app] := hwnd
    MapDel(AnchorPending, app)
    ScanStamp := 0
    RouteAppNow(app)
    PopulateAppList(false)
    Tip(FormatAppDisplayName(app) " : audio follows this window")
}

; ------------------------------ SHARED SCAN ---------------------------------
; One process snapshot + one pass over the visible windows serves every
; tracked app. Replaces a ProcessExist() plus WinGetList("ahk_exe ...") per
; app per tick. Results are reused for up to maxAgeMs.
RefreshScan(maxAgeMs := 150) {
    global ScanStamp, ScanAppCount
    now := A_TickCount
    if now - ScanStamp < maxAgeMs && Apps.Count = ScanAppCount
        return
    ScanStamp := now
    ScanAppCount := Apps.Count
    ScanRunning.Clear()
    ScanWindow.Clear()
    ScanPids.Clear()
    if !Apps.Count
        return

    pidToExe := Map()
    hSnap := DllCall("CreateToolhelp32Snapshot", "UInt", 0x2, "UInt", 0, "Ptr")
    if !hSnap || hSnap = -1
        return
    entrySize  := (A_PtrSize = 8) ? 568 : 556
    nameOffset := (A_PtrSize = 8) ? 44 : 36
    pe := Buffer(entrySize, 0)
    NumPut("UInt", entrySize, pe, 0)
    if DllCall("Process32FirstW", "Ptr", hSnap, "Ptr", pe) {
        loop {
            exe := StrGet(pe.Ptr + nameOffset, 260, "UTF-16")
            if Apps.Has(exe) {
                pid := NumGet(pe, 8, "UInt")
                pidToExe[pid] := exe
                ScanRunning[exe] := true
                if !ScanPids.Has(exe)
                    ScanPids[exe] := []
                ScanPids[exe].Push(pid)
            }
        } until !DllCall("Process32NextW", "Ptr", hSnap, "Ptr", pe)
    }
    DllCall("CloseHandle", "Ptr", hSnap)
    for app in AnchorHwnd.Clone() {               ; app closed: forget its anchor (start fresh next time)
        if !ScanRunning.Has(app) {
            AnchorHwnd.Delete(app)
            MapDel(AnchorPending, app)
        }
    }
    if !pidToExe.Count
        return

    ; Topmost non-minimized window per app; a titled window beats an untitled one.
    fallback := Map()
    for hwnd in WinGetList() {
        try {
            exe := pidToExe.Get(WinGetPID(hwnd), "")
            if exe = "" || ScanWindow.Has(exe)
                continue
            if WinGetMinMax(hwnd) = -1
                continue
            if WinGetTitle(hwnd) != ""
                ScanWindow[exe] := hwnd
            else if !fallback.Has(exe)
                fallback[exe] := hwnd
        }
    }
    for exe, hwnd in fallback {
        if !ScanWindow.Has(exe)
            ScanWindow[exe] := hwnd
    }
}

AppRunning(app) {
    RefreshScan()
    return ScanRunning.Has(app)
}

AppWindow(app) {
    RefreshScan()
    return ScanWindow.Get(app, 0)
}

CurrentMonitor(app) {
    mon := WindowMonitor(FindWindow(app))
    if mon
        LastSeen[app] := mon
    return LastSeen.Get(app, 0)
}

MonitorAt(px, py) {
    Loop Min(MonitorGetCount(), MAX_MONITORS) {
        MonitorGet(A_Index, &l, &t, &r, &b)
        if px >= l && px < r && py >= t && py < b
            return A_Index
    }
    return 0
}
