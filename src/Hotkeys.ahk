; Screen Audio Router - Copyright (C) 2026 panoc
; Licensed under the GNU GPL v3 or later. See LICENSE.
; ============================================================================
; Screen Audio Router  -  src\Hotkeys.ahk
; Hotkey registration and the capture boxes
; Part of ScreenAudioRouter.ahk (included at its end). Functions only.
; ============================================================================

; ------------------------------ HOTKEY MANAGEMENT & CAPTURE -----------------
InitAllHotkeys() {
    global HkOverrideFocused, HkOverrideAllMons, HkOverrideAll, HkReapply, DetectedMonCount
    DetectedMonCount := Min(Max(MonitorGetCount(), 1), MAX_MONITORS)

    RegisterSingleHotkey("focused", HkOverrideFocused, true)
    RegisterSingleHotkey("allmons", HkOverrideAllMons, true)
    RegisterSingleHotkey("all", HkOverrideAll, true)
    RegisterSingleHotkey("reapply", HkReapply, true)

    Loop DetectedMonCount {
        mIdx := A_Index
        if !IsMonitorDisabled(mIdx) {
            hk := MonHotkeys.Get(mIdx, "")
            RegisterMonitorHotkey(mIdx, hk, true)
        }
    }

    for app, hk in AppHotkeys {
        if Apps.Has(app) && hk != ""
            RegisterAppHotkey(app, hk, true)
    }
}

IsHotkeyDuplicate(newHk, excludeKey) {
    if newHk = ""
        return false
    target := StrLower(newHk)

    if excludeKey != "focused" && StrLower(HkOverrideFocused) = target
        return true
    if excludeKey != "allmons" && StrLower(HkOverrideAllMons) = target
        return true
    if excludeKey != "all" && StrLower(HkOverrideAll) = target
        return true
    if excludeKey != "reapply" && StrLower(HkReapply) = target
        return true

    for mIdx, hk in MonHotkeys {
        if excludeKey != ("mon:" mIdx) && hk != "" && StrLower(hk) = target
            return true
    }

    for app, hk in AppHotkeys {
        if excludeKey != ("app:" StrLower(app)) && hk != "" && StrLower(hk) = target
            return true
    }
    return false
}

RegisterSingleHotkey(which, newHk, silent := false) {
    global HkOverrideFocused, HkOverrideAllMons, HkOverrideAll, HkReapply
    global RegHkFocused, RegHkAllMons, RegHkAll, RegHkReapply

    newHk := Trim(newHk)

    if which = "focused" {
        oldReg := RegHkFocused
        cb     := ToggleFocused
        ctrl   := HkCtrlFocused
    } else if which = "allmons" {
        oldReg := RegHkAllMons
        cb     := ToggleAllMonitorsOverride
        ctrl   := HkCtrlAllMons
    } else if which = "all" {
        oldReg := RegHkAll
        cb     := ToggleAll
        ctrl   := HkCtrlAll
    } else {
        oldReg := RegHkReapply
        cb     := ReapplyAll
        ctrl   := HkCtrlReapply
    }

    if newHk != "" && IsHotkeyDuplicate(newHk, which) {
        SetHotkeyBoxValue(ctrl, newHk, "error")
        if !silent
            Tip("Hotkey conflict : " FormatHotkeyDisplay(newHk) " is already assigned")
        return false
    }

    if oldReg != "" {
        try Hotkey(oldReg, "Off")
        oldReg := ""
    }

    if newHk = "" {
        SetHotkeyStateVars(which, "", "")
        SetHotkeyBoxValue(ctrl, "", "normal")
        SaveHotkeys()
        SetupTrayMenu()
        RefreshHotkeyIndicators()
        if !silent
            Tip("Hotkey cleared")
        return true
    }

    try {
        Hotkey(newHk, cb, "On")
        SetHotkeyStateVars(which, newHk, newHk)
        SetHotkeyBoxValue(ctrl, newHk, "normal")
        SaveHotkeys()
        SetupTrayMenu()
        RefreshHotkeyIndicators()
        if !silent
            Tip("Hotkey set to " FormatHotkeyDisplay(newHk))
        return true
    } catch {
        SetHotkeyBoxValue(ctrl, newHk, "error")
        if !silent
            Tip("Could not register " FormatHotkeyDisplay(newHk) " (reserved or in use)")
        return false
    }
}

RegisterMonitorHotkey(mIdx, newHk, silent := false) {
    newHk := Trim(newHk)
    oldReg := RegMonHotkeys.Get(mIdx, "")
    ctrl := MonHkControls.Get(mIdx, "")

    if newHk != "" && IsHotkeyDuplicate(newHk, "mon:" mIdx) {
        SetHotkeyBoxValue(ctrl, newHk, "error")
        if !silent
            Tip("Hotkey conflict : " FormatHotkeyDisplay(newHk) " is already assigned")
        return false
    }

    if oldReg != "" {
        try Hotkey(oldReg, "Off")
        MapDel(RegMonHotkeys, mIdx)
    }

    if newHk = "" {
        MapDel(MonHotkeys, mIdx)
        SetHotkeyBoxValue(ctrl, "", "normal")
        SaveHotkeys()
        SetupTrayMenu()
        if !silent
            Tip("Monitor " mIdx " hotkey cleared")
        return true
    }

    if IsMonitorDisabled(mIdx) {
        MonHotkeys[mIdx] := newHk
        SetHotkeyBoxValue(ctrl, newHk, "normal")
        SaveHotkeys()
        return true
    }

    try {
        Hotkey(newHk, ToggleMonitorOverrideByIndex.Bind(mIdx), "On")
        MonHotkeys[mIdx] := newHk
        RegMonHotkeys[mIdx] := newHk
        SetHotkeyBoxValue(ctrl, newHk, "normal")
        SaveHotkeys()
        SetupTrayMenu()
        if !silent
            Tip("Monitor " mIdx " hotkey set to " FormatHotkeyDisplay(newHk))
        return true
    } catch {
        SetHotkeyBoxValue(ctrl, newHk, "error")
        if !silent
            Tip("Could not register " FormatHotkeyDisplay(newHk) " (reserved or in use)")
        return false
    }
}

RegisterAppHotkey(app, newHk, silent := false) {
    newHk := Trim(newHk)
    oldReg := RegAppHotkeys.Get(app, "")
    ctrl := (SelectedApp = app) ? HkCtrlApp : ""

    if newHk != "" && IsHotkeyDuplicate(newHk, "app:" StrLower(app)) {
        SetHotkeyBoxValue(ctrl, newHk, "error")
        if !silent
            Tip("Hotkey conflict : " FormatHotkeyDisplay(newHk) " is already assigned")
        return false
    }

    if oldReg != "" {
        try Hotkey(oldReg, "Off")
        MapDel(RegAppHotkeys, app)
    }

    if newHk = "" {
        MapDel(AppHotkeys, app)
        SetHotkeyBoxValue(ctrl, "", "normal")
        SaveHotkeys()
        if !silent
            Tip(app " shortcut cleared")
        return true
    }

    try {
        Hotkey(newHk, ToggleAppOverrideByName.Bind(app), "On")
        AppHotkeys[app] := newHk
        RegAppHotkeys[app] := newHk
        SetHotkeyBoxValue(ctrl, newHk, "normal")
        SaveHotkeys()
        if !silent
            Tip(app " shortcut set to " FormatHotkeyDisplay(newHk))
        return true
    } catch {
        SetHotkeyBoxValue(ctrl, newHk, "error")
        if !silent
            Tip("Could not register " FormatHotkeyDisplay(newHk) " (reserved or in use)")
        return false
    }
}

SetHotkeyStateVars(which, cfgHk, regHk) {
    global HkOverrideFocused, HkOverrideAllMons, HkOverrideAll, HkReapply
    global RegHkFocused, RegHkAllMons, RegHkAll, RegHkReapply

    if which = "focused" {
        HkOverrideFocused := cfgHk
        RegHkFocused      := regHk
    } else if which = "allmons" {
        HkOverrideAllMons := cfgHk
        RegHkAllMons      := regHk
    } else if which = "all" {
        HkOverrideAll := cfgHk
        RegHkAll      := regHk
    } else {
        HkReapply    := cfgHk
        RegHkReapply := regHk
    }
}

FormatHotkeyDisplay(hk) {
    if hk = ""
        return "None"
    mods := ""
    rest := RegExReplace(hk, "^[~$\*]+")
    while StrLen(rest) > 1 {
        ch := SubStr(rest, 1, 1)
        if ch = "^" {
            mods .= "Ctrl+"
            rest := SubStr(rest, 2)
        } else if ch = "!" {
            mods .= "Alt+"
            rest := SubStr(rest, 2)
        } else if ch = "+" {
            mods .= "Shift+"
            rest := SubStr(rest, 2)
        } else if ch = "#" {
            mods .= "Win+"
            rest := SubStr(rest, 2)
        } else {
            break
        }
    }

    switch StrLower(rest) {
        case "xbutton1":  keyDisp := "Mouse4"
        case "xbutton2":  keyDisp := "Mouse5"
        case "mbutton":   keyDisp := "Middle Click"
        case "lbutton":   keyDisp := "Left Click"
        case "rbutton":   keyDisp := "Right Click"
        case "wheelup":   keyDisp := "Wheel Up"
        case "wheeldown": keyDisp := "Wheel Down"
        default:
            keyDisp := (StrLen(rest) = 1) ? StrUpper(rest) : StrTitle(rest)
    }
    return mods . keyDisp
}

CreateHotkeyCaptureBox(guiObj, opts, kind, key := "", initialHk := "") {
    ctrl := guiObj.AddEdit(opts " ReadOnly Center", FormatHotkeyDisplay(initialHk))
    ctrl.Opt("Background" Th("editBg"))
    ctrl.Opt(initialHk = "" ? "c" Th("hint") : "c" Th("text"))
    HotkeyBoxMeta[ctrl.Hwnd] := {ctrl: ctrl, kind: kind, key: key, pendingHk: initialHk}
    return ctrl
}

SetHotkeyBoxValue(ctrl, hk, state := "normal") {
    if !IsObject(ctrl)
        return
    if HotkeyBoxMeta.Has(ctrl.Hwnd)
        HotkeyBoxMeta[ctrl.Hwnd].pendingHk := hk

    if state = "error"
        ctrl.Opt("c" Th("err"))
    else if state = "pending"
        ctrl.Opt("c" Th("warn"))
    else if hk = ""
        ctrl.Opt("c" Th("hint"))
    else
        ctrl.Opt("c" Th("text"))

    ctrl.Value := FormatHotkeyDisplay(hk)
}

GetHotkeyBoxPending(ctrl) {
    if IsObject(ctrl) && HotkeyBoxMeta.Has(ctrl.Hwnd)
        return HotkeyBoxMeta[ctrl.Hwnd].pendingHk
    return ""
}


OnWmLButtonDown(wParam, lParam, msg, hwnd) {
    if HotkeyBoxMeta.Has(hwnd) {
        meta := HotkeyBoxMeta[hwnd]
        if meta.ctrl.Enabled {
            DllCall("SetFocus", "Ptr", hwnd)
            StartHotkeyCapture(hwnd)
            return 0
        }
    }
}

OnWmSetFocus(wParam, lParam, msg, hwnd) {
    if HotkeyBoxMeta.Has(hwnd) && HotkeyBoxMeta[hwnd].ctrl.Enabled
        StartHotkeyCapture(hwnd)
}

OnWmKillFocus(wParam, lParam, msg, hwnd) {
    if ActiveCaptureHwnd = hwnd
        StopHotkeyCapture(false)
}

StartHotkeyCapture(hwnd) {
    global ActiveCaptureHwnd, ActiveCaptureHook
    if !HotkeyBoxMeta.Has(hwnd)
        return
    if ActiveCaptureHwnd = hwnd
        return
    if ActiveCaptureHwnd != 0
        StopHotkeyCapture(false)

    meta := HotkeyBoxMeta[hwnd]
    ActiveCaptureHwnd := hwnd
    Suspend(true)

    meta.ctrl.Opt("c" Th("capture"))
    meta.ctrl.Value := "Press a key..."

    ih := InputHook("L0")
    ih.KeyOpt("{All}", "N")
    ih.KeyOpt("{LCtrl}{RCtrl}{LAlt}{RAlt}{LShift}{RShift}{LWin}{RWin}", "-N")
    ih.OnKeyDown := OnCaptureKeyDown
    ActiveCaptureHook := ih
    ih.Start()
}

StopHotkeyCapture(accepted := false) {
    global ActiveCaptureHwnd, ActiveCaptureHook
    hwnd := ActiveCaptureHwnd
    ActiveCaptureHwnd := 0

    if IsObject(ActiveCaptureHook) {
        try ActiveCaptureHook.Stop()
        ActiveCaptureHook := ""
    }
    Suspend(false)

    if hwnd && HotkeyBoxMeta.Has(hwnd) {
        meta := HotkeyBoxMeta[hwnd]
        savedHk := GetSavedHotkeyForMeta(meta)
        state := (meta.pendingHk != savedHk) ? "pending" : "normal"
        SetHotkeyBoxValue(meta.ctrl, meta.pendingHk, state)
    }
}

GetCaptureModifiers() {
    mods := ""
    if GetKeyState("Ctrl", "P")
        mods .= "^"
    if GetKeyState("Alt", "P")
        mods .= "!"
    if GetKeyState("Shift", "P")
        mods .= "+"
    if GetKeyState("LWin", "P") || GetKeyState("RWin", "P")
        mods .= "#"
    return mods
}

OnCaptureKeyDown(ih, VK, SC) {
    if ActiveCaptureHwnd = 0 || !HotkeyBoxMeta.Has(ActiveCaptureHwnd)
        return
    meta := HotkeyBoxMeta[ActiveCaptureHwnd]
    keyName := GetKeyName(Format("vk{:x}sc{:x}", VK, SC))
    if keyName = ""
        keyName := Format("vk{:x}", VK)

    mods := GetCaptureModifiers()

    if keyName = "Escape" && mods = "" {
        StopHotkeyCapture(false)
        return
    }
    if (keyName = "Backspace" || keyName = "Delete") && mods = "" {
        meta.pendingHk := ""
        StopHotkeyCapture(true)
        return
    }

    if keyName = " "
        keyName := "Space"
    else if StrLen(keyName) = 1
        keyName := StrLower(keyName)

    meta.pendingHk := mods . keyName
    StopHotkeyCapture(true)
}


GetSavedHotkeyForMeta(meta) {
    if meta.kind = "focused"
        return HkOverrideFocused
    if meta.kind = "allmons"
        return HkOverrideAllMons
    if meta.kind = "all"
        return HkOverrideAll
    if meta.kind = "reapply"
        return HkReapply
    if meta.kind = "mon"
        return MonHotkeys.Get(meta.key, "")
    if meta.kind = "app"
        return (SelectedApp != "" && Apps.Has(SelectedApp)) ? AppHotkeys.Get(SelectedApp, "") : ""
    return ""
}

OnApplyHotkey(which, *) {
    if ActiveCaptureHwnd != 0
        StopHotkeyCapture(false)

    if which = "focused"
        val := GetHotkeyBoxPending(HkCtrlFocused)
    else if which = "allmons"
        val := GetHotkeyBoxPending(HkCtrlAllMons)
    else if which = "all"
        val := GetHotkeyBoxPending(HkCtrlAll)
    else
        val := GetHotkeyBoxPending(HkCtrlReapply)

    RegisterSingleHotkey(which, val, false)
}

OnClearHotkey(which, *) {
    if ActiveCaptureHwnd != 0
        StopHotkeyCapture(false)
    RegisterSingleHotkey(which, "", false)
}

OnResetHotkey(which, *) {
    if ActiveCaptureHwnd != 0
        StopHotkeyCapture(false)
    if which = "focused"
        def := DEFAULT_HK_FOCUSED
    else if which = "allmons"
        def := DEFAULT_HK_ALL_MONS
    else if which = "all"
        def := DEFAULT_HK_ALL
    else
        def := DEFAULT_HK_REAPPLY
    RegisterSingleHotkey(which, def, false)
}

OnApplyMonitorHotkey(mIdx, *) {
    if ActiveCaptureHwnd != 0
        StopHotkeyCapture(false)
    if !MonHkControls.Has(mIdx)
        return
    val := GetHotkeyBoxPending(MonHkControls[mIdx])
    RegisterMonitorHotkey(mIdx, val, false)
}

OnClearMonitorHotkey(mIdx, *) {
    if ActiveCaptureHwnd != 0
        StopHotkeyCapture(false)
    RegisterMonitorHotkey(mIdx, "", false)
}

OnResetMonitorHotkey(mIdx, *) {
    if ActiveCaptureHwnd != 0
        StopHotkeyCapture(false)
    RegisterMonitorHotkey(mIdx, "", false)
}

OnApplyAppHotkey(*) {
    if ActiveCaptureHwnd != 0
        StopHotkeyCapture(false)
    if SelectedApp = "" || !Apps.Has(SelectedApp)
        return
    val := GetHotkeyBoxPending(HkCtrlApp)
    RegisterAppHotkey(SelectedApp, val, false)
}

OnClearAppHotkey(*) {
    if ActiveCaptureHwnd != 0
        StopHotkeyCapture(false)
    if SelectedApp = "" || !Apps.Has(SelectedApp)
        return
    RegisterAppHotkey(SelectedApp, "", false)
}

OnResetAppHotkey(*) {
    if ActiveCaptureHwnd != 0
        StopHotkeyCapture(false)
    if SelectedApp = "" || !Apps.Has(SelectedApp)
        return
    RegisterAppHotkey(SelectedApp, "", false)
}

RefreshHotkeyIndicators() {
    try {
        if !IsObject(MainGui) || !WinExist("ahk_id " MainGui.Hwnd)
            return

        LblOvrAllHeader.Value     := "All-Apps Override device  (Hotkey : " FormatHotkeyDisplay(HkOverrideAll) ")"
        LblOvrAllMonsHeader.Value := "All-Monitors Override device  (Hotkey : " FormatHotkeyDisplay(HkOverrideAllMons) ")"
        UpdateQuickActionButtons()
    }
}

; The quick-action buttons show the same on/off state (color and wording) as the
; buttons they mirror: Override ON/OFF of the selected app, End All Override, End Mons Override.
UpdateQuickActionButtons() {
    if IsObject(BtnHkFocused) {
        if SelectedApp != "" && Apps.Has(SelectedApp) {
            BtnHkFocused.Text := "Toggle Selected (" SelectedApp ")"
            SetButtonColor(BtnHkFocused, AppOverrideActive.Get(SelectedApp, false) ? BtnColorQuickSelectedOn : BtnColorQuickSelectedOff)
        } else {
            BtnHkFocused.Text := "Focused App Override"
            SetButtonColor(BtnHkFocused, BtnColorQuickSelectedOff)
        }
    }
    if IsObject(BtnHkAll) {
        appsOn := AllMode || AnyAppOverrideActive()          ; same rule as "End All Override"
        BtnHkAll.Text := appsOn ? "End All-Apps Override" : "Toggle All-Apps Override"
        SetButtonColor(BtnHkAll, appsOn ? BtnColorQuickAllAppsOn : BtnColorQuickAllAppsOff)
    }
    if IsObject(BtnHkAllMons) {
        monsOn := AllMonitorsMode || AnyEffectiveMonitorOverride()   ; same rule as "End Mons Override"
        BtnHkAllMons.Text := monsOn ? "End All-Monitors Override" : "Toggle All-Monitors Override"
        SetButtonColor(BtnHkAllMons, monsOn ? BtnColorQuickAllMonsOn : BtnColorQuickAllMonsOff)
    }
}
