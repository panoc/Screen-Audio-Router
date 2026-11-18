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

; Tooltip of the shortcut boxes (a function: code in src runs after the window can be built)
HotkeyBoxTip() {
    return "Click the box, then press the shortcut.`nBackspace clears it, Esc cancels. Then click Set (or Apply)."
}

CreateHotkeyCaptureBox(guiObj, opts, kind, key := "", initialHk := "") {
    ctrl := guiObj.AddEdit(opts " ReadOnly Center", FormatHotkeyDisplay(initialHk))
    ctrl.Opt("Background" Th("editBg"))
    ctrl.Opt(initialHk = "" ? "c" Th("hint") : "c" Th("text"))
    HotkeyBoxMeta[ctrl.Hwnd] := {ctrl: ctrl, kind: kind, key: key, pendingHk: initialHk, state: "normal"}
    AddTip(ctrl, HotkeyBoxTip())
    if initialHk != ""
        SetTimer(RecheckHotkeyBoxes, -150)          ; shows the warning if another program uses it
    return ctrl
}

; A shortcut that another program also uses is shown as "⚠ Ctrl+Alt+M" in the error color,
; and the box's tooltip says who uses it (see HotkeyTakenBy).
SetHotkeyBoxValue(ctrl, hk, state := "normal") {
    if !IsObject(ctrl)
        return
    if HotkeyBoxMeta.Has(ctrl.Hwnd) {
        HotkeyBoxMeta[ctrl.Hwnd].pendingHk := hk
        HotkeyBoxMeta[ctrl.Hwnd].state := state
    }

    owner := ""
    if hk != "" {
        k := HkKey(hk)
        if HkOwnerCache.Has(k)
            owner := HkOwnerCache[k]
        else
            SetTimer(RecheckHotkeyBoxes, -150)      ; not checked yet: check it in a moment
    }

    if state = "error" || owner != ""
        SetCtrlColor(ctrl, Th("err"))
    else if state = "pending"
        SetCtrlColor(ctrl, Th("warn"))
    else if hk = ""
        SetCtrlColor(ctrl, Th("hint"))
    else
        SetCtrlColor(ctrl, Th("text"))

    SetCtrlValue(ctrl, (owner != "" ? "⚠ " : "") FormatHotkeyDisplay(hk))
    HoverTips[ctrl.Hwnd] := owner = "" ? HotkeyBoxTip()
        : "⚠ Already used by " owner ".`nScreen Audio Router takes it over while it runs, so the other`n"
        . "program's shortcut doesn't work. Pick another one if you need both.`n`n" HotkeyBoxTip()
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

    SetCtrlColor(meta.ctrl, Th("capture"))         ; through the cache, so the old color comes back afterwards
    SetCtrlValue(meta.ctrl, "Press a key...")

    ; Keys are blocked while recording (S), so a combination another program uses doesn't
    ; also trigger that program. The modifiers are blocked too and read by physical state.
    ih := InputHook("L0")
    ih.KeyOpt("{All}", "NS")
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
        if accepted && meta.pendingHk != "" && HkOwnerCache.Has(HkKey(meta.pendingHk))
            HkOwnerCache.Delete(HkKey(meta.pendingHk))     ; check it fresh
        savedHk := GetSavedHotkeyForMeta(meta)
        state := (meta.pendingHk != savedHk) ? "pending" : "normal"
        SetHotkeyBoxValue(meta.ctrl, meta.pendingHk, state)
    }
    UpdateApplyButton()
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
    ; Letters and digits are stored by physical key (A-Z, 0-9), so a shortcut recorded while
    ; e.g. the Greek layout is active is still "o", not a Greek letter.
    if (VK >= 0x30 && VK <= 0x39) || (VK >= 0x41 && VK <= 0x5A)
        keyName := Chr(VK)
    else
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

    if ConfirmHotkeyUse(val, which, SingleHotkeySaved(which), SingleHotkeyCtrl(which))
        RegisterSingleHotkey(which, val, false)
}

SingleHotkeySaved(which) {
    return which = "focused" ? HkOverrideFocused : which = "allmons" ? HkOverrideAllMons
         : which = "all" ? HkOverrideAll : HkReapply
}

SingleHotkeyCtrl(which) {
    return which = "focused" ? HkCtrlFocused : which = "allmons" ? HkCtrlAllMons
         : which = "all" ? HkCtrlAll : HkCtrlReapply
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
    if ConfirmHotkeyUse(def, which, SingleHotkeySaved(which), SingleHotkeyCtrl(which))
        RegisterSingleHotkey(which, def, false)
}

OnApplyMonitorHotkey(mIdx, *) {
    if ActiveCaptureHwnd != 0
        StopHotkeyCapture(false)
    if !MonHkControls.Has(mIdx)
        return
    val := GetHotkeyBoxPending(MonHkControls[mIdx])
    if ConfirmHotkeyUse(val, "mon:" mIdx, MonHotkeys.Get(mIdx, ""), MonHkControls[mIdx])
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
    if ConfirmHotkeyUse(val, "app:" StrLower(SelectedApp), AppHotkeys.Get(SelectedApp, ""), HkCtrlApp)
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

        SetCtrlValue(LblOvrAllHeader, "All-Apps Override device  (Hotkey : " FormatHotkeyDisplay(HkOverrideAll) ")")
        SetCtrlValue(LblOvrAllMonsHeader, "All-Monitors Override device  (Hotkey : " FormatHotkeyDisplay(HkOverrideAllMons) ")")
        UpdateQuickActionButtons()
    }
}

; The quick-action buttons show the same on/off state (color and wording) as the
; buttons they mirror: Override ON/OFF of the selected app, End All Override, End Mons Override.
UpdateQuickActionButtons() {
    if IsObject(BtnHkFocused) {
        if SelectedApp != "" && Apps.Has(SelectedApp) {
            SetCtrlText(BtnHkFocused, "Toggle Selected (" SelectedApp ")")
            SetButtonColor(BtnHkFocused, AppOverrideActive.Get(SelectedApp, false) ? BtnColorQuickSelectedOn : BtnColorQuickSelectedOff)
        } else {
            SetCtrlText(BtnHkFocused, "Focused App Override")
            SetButtonColor(BtnHkFocused, BtnColorQuickSelectedOff)
        }
    }
    if IsObject(BtnHkAll) {
        appsOn := AllMode || AnyAppOverrideActive()          ; same rule as "End All Override"
        SetCtrlText(BtnHkAll, appsOn ? "End All-Apps Override" : "Toggle All-Apps Override")
        SetButtonColor(BtnHkAll, appsOn ? BtnColorQuickAllAppsOn : BtnColorQuickAllAppsOff)
    }
    if IsObject(BtnHkAllMons) {
        monsOn := AllMonitorsMode || AnyEffectiveMonitorOverride()   ; same rule as "End Mons Override"
        SetCtrlText(BtnHkAllMons, monsOn ? "End All-Monitors Override" : "Toggle All-Monitors Override")
        SetButtonColor(BtnHkAllMons, monsOn ? BtnColorQuickAllMonsOn : BtnColorQuickAllMonsOff)
    }
}

; ------------------------------ SHORTCUT CONFLICT CHECK ---------------------
; Finds out whether another program already uses a shortcut (idea and script reading from WinPin):
;  1. shortcuts Windows handles itself, which can't be detected, so they are listed here;
;  2. asks Windows to register the combination for a moment: when another app (or Explorer,
;     which owns most Win+letter shortcuts) registered it first, Windows refuses;
;  3. reads the .ahk files of other running AutoHotkey scripts, whose hook hotkeys ($ ~ * ...)
;     Windows can't report, and names the script.
; Not detectable: shortcuts an app only handles while it's focused (Ctrl+S in an editor), compiled
; AutoHotkey exes and other programs that read the keyboard with a hook. Mouse shortcuts are skipped.

; "^!o" -> mods (RegisterHotKey MOD_ flags) and vk. False for mouse buttons and the wheel.
HkParse(hk, &mods, &vk) {
    mods := 0, vk := 0
    key := RegExReplace(hk, "^[~$*]+")
    while StrLen(key) > 1 && InStr("^!+#", c := SubStr(key, 1, 1)) {
        mods |= (c = "!") ? 0x1 : (c = "^") ? 0x2 : (c = "+") ? 0x4 : 0x8
        key := SubStr(key, 2)
    }
    if key = "" || InStr(key, " ") || RegExMatch(key, "i)button|wheel")
        return false
    vk := GetKeyVK(key)
    return vk > 6                                    ; 1-6 are mouse buttons
}

; Same shortcut, however it is written ("^!o" / "!^O") -> same key. Used by the caches.
HkKey(hk) {
    return HkParse(hk, &mods, &vk) ? Format("{}-{:X}", mods, vk) : StrLower(hk)
}

; Who else uses the shortcut: "WinPin.ahk", "another app or Windows", "Windows (Lock screen)",
; or "" when it looks free. Screen Audio Router's own shortcuts don't count.
HotkeyTakenBy(hk) {
    if hk = "" || !HkParse(hk, &mods, &vk)
        return ""

    static reserved := [[0x8, 0x4C, "Windows (Lock screen)"], [0x3, 0x2E, "Windows (Ctrl+Alt+Del)"]
                      , [0x6, 0x1B, "Windows (Task Manager)"], [0x2, 0x1B, "Windows (Start menu)"]
                      , [0x1, 0x09, "Windows (Alt+Tab)"], [0x1, 0x73, "Windows (Close window)"]]
    for r in reserved
        if mods = r[1] && vk = r[2]
            return r[3]

    ; One of our own registered shortcuts would make Windows refuse because of us: switch it
    ; off for the moment of the test.
    own := OwnRegisteredHotkey(mods, vk)
    if own != ""
        try Hotkey(own, "Off")
    static testId := 0xBFF0
    ok := DllCall("RegisterHotKey", "Ptr", A_ScriptHwnd, "Int", testId, "UInt", mods, "UInt", vk)
    err := A_LastError
    if ok
        DllCall("UnregisterHotKey", "Ptr", A_ScriptHwnd, "Int", testId)
    if own != ""
        try Hotkey(own, "On")

    ; A script name is more useful than "another app", and scripts using a keyboard hook
    ; don't make Windows refuse at all, so the scripts are read in both cases.
    script := HkScriptOwner(mods, vk)
    if script != ""
        return script
    if !ok && err = 1409                            ; ERROR_HOTKEY_ALREADY_REGISTERED
        return "another app or Windows"
    return ""
}

; The hotkey string we registered for this combination, or "".
OwnRegisteredHotkey(mods, vk) {
    for hk in [RegHkFocused, RegHkAllMons, RegHkAll, RegHkReapply]
        if hk != "" && HkParse(hk, &m, &v) && m = mods && v = vk
            return hk
    for regMap in [RegMonHotkeys, RegAppHotkeys]
        for , hk in regMap
            if hk != "" && HkParse(hk, &m, &v) && m = mods && v = vk
                return hk
    return ""
}

; Name of another running .ahk script that defines this hotkey, or "".
HkScriptOwner(mods, vk) {
    for sc in HkRunningScripts()
        for k in sc.keys
            if k[2] = vk && (k[1] = mods || (k[3] && (k[1] & ~mods) = 0))   ; exact, or a * wildcard
                return sc.name
    return ""
}

; Hotkeys of the other running AutoHotkey scripts (.ahk only). The process list (a WMI query,
; which can take up to a second) is read again only when the window opens (fresh) or after
; 5 minutes; each script's hotkeys are kept until its file changes.
HkRunningScripts(fresh := false) {
    static files := Map(), list := [], listTick := 0
    if !fresh && listTick && A_TickCount - listTick < 300000
        return list
    listTick := A_TickCount
    list := []
    ownPid := DllCall("GetCurrentProcessId", "UInt")
    try {
        procs := ComObjGet("winmgmts:").ExecQuery("SELECT ProcessId, CommandLine FROM Win32_Process WHERE Name LIKE 'AutoHotkey%'")
        for p in procs {
            try {
                if p.ProcessId = ownPid || !RegExMatch(p.CommandLine, 'i)([a-z]:\\[^"]*?\.ahk)', &m)
                    continue
                path := m[1]
                stamp := FileGetTime(path, "M")
                if !(files.Has(path) && files[path].stamp = stamp)
                    files[path] := {stamp: stamp, keys: HkParseScript(FileRead(path))}
                SplitPath(path, &fileName)
                list.Push({name: fileName, keys: files[path].keys})
            }
        }
    }
    return list
}

; [[mods, vk, wildcard], ...] for "hotkey::" lines and Hotkey("...") calls in a script.
HkParseScript(text) {
    list := []
    pos := 1
    while pos := RegExMatch(text, "im)^[ \t]*([~*$<>^!+#]*)([^\s:&;]+)(?:[ \t]+up)?[ \t]*::", &m, pos) {
        pos += m.Len
        HkAddScriptKey(list, m[1], m[2])
    }
    pos := 1
    while pos := RegExMatch(text, "i)\bHotkey\(\s*[`"']([~*$<>^!+#]*)([^`"'\s&]+)[`"']", &m, pos) {
        pos += m.Len
        HkAddScriptKey(list, m[1], m[2])
    }
    return list
}

HkAddScriptKey(list, prefix, key) {
    mods := 0
    Loop Parse, prefix {
        switch A_LoopField {
            case "!": mods |= 0x1
            case "^": mods |= 0x2
            case "+": mods |= 0x4
            case "#": mods |= 0x8
        }
    }
    if (vk := GetKeyVK(key)) > 6
        list.Push([mods, vk, InStr(prefix, "*") ? true : false])
}

; A letter, digit, Space, Enter or Tab without Ctrl, Alt or Win would block normal typing.
HkBlocksTyping(hk) {
    if !HkParse(hk, &mods, &vk)
        return false
    return !(mods & 0xB) && ((vk >= 0x30 && vk <= 0x39) || (vk >= 0x41 && vk <= 0x5A)
        || vk = 0x20 || vk = 0x0D || vk = 0x09 || (vk >= 0xBA && vk <= 0xE2))
}

; Asked before a new shortcut is set (Set, Reset, Apply). Returns true to go ahead. On No the
; box goes back to the saved shortcut. dupKey is the IsHotkeyDuplicate key of the box.
ConfirmHotkeyUse(newHk, dupKey, savedHk, ctrl := "") {
    if newHk = ""
        return true
    if HkBlocksTyping(newHk) {
        try MainGui.Opt("+OwnDialogs")
        MsgBox(FormatHotkeyDisplay(newHk) " on its own would block normal typing.`n"
            . "Add Ctrl, Alt or Win to it.", "Shortcut Not Allowed", "Icon!")
        SetHotkeyBoxValue(ctrl, savedHk, "normal")
        return false
    }
    if StrLower(newHk) = StrLower(savedHk)            ; already this box's shortcut
        return true
    if IsHotkeyDuplicate(newHk, dupKey)               ; our own duplicate: Register... reports it
        return true

    owner := HotkeyTakenBy(newHk)
    HkOwnerCache[HkKey(newHk)] := owner
    if owner = "" {
        SetHotkeyBoxValue(ctrl, newHk, "pending")
        return true
    }
    try MainGui.Opt("+OwnDialogs")
    ans := MsgBox(FormatHotkeyDisplay(newHk) " is already used by " owner ".`n`n"
        . "If you use it anyway, Screen Audio Router takes it over: the other shortcut won't work "
        . "while Screen Audio Router is running.`n`nUse it anyway?", "Shortcut Already In Use", "YesNo Icon! Default2")
    if ans != "Yes" {
        SetHotkeyBoxValue(ctrl, savedHk, "normal")
        return false
    }
    HkTakenShown[HkKey(newHk)] := true                ; you know already: no notice at startup
    SaveSettings()
    return true
}

; Checks every shortcut box again and redraws the warnings. fresh = forget earlier results
; (when the window opens: another program may have started since).
RecheckHotkeyBoxes(fresh := false) {
    if fresh {
        HkOwnerCache.Clear()
        HkRunningScripts(true)                         ; read the running scripts once, now
    }
    for hwnd, meta in HotkeyBoxMeta.Clone() {
        if hwnd = ActiveCaptureHwnd || meta.pendingHk = ""
            continue
        k := HkKey(meta.pendingHk)
        if !HkOwnerCache.Has(k)
            HkOwnerCache[k] := HotkeyTakenBy(meta.pendingHk)
        try SetHotkeyBoxValue(meta.ctrl, meta.pendingHk, meta.state)
    }
}

; Once after start: tells about saved shortcuts that another program also uses. Each one is
; reported once (remembered in the INI as TakenShortcuts) and again only after it was free.
StartupHotkeyCheck() {
    HkRunningScripts(true)
    items := [[HkOverrideFocused, "Focused App Override"], [HkOverrideAllMons, "All-Monitors Override"]
            , [HkOverrideAll, "All-Apps Override"], [HkReapply, "Re-apply Routing"]]
    for mIdx, hk in RegMonHotkeys
        items.Push([hk, "Monitor " mIdx " Override"])
    for app, hk in RegAppHotkeys
        items.Push([hk, app])

    lines := []
    changed := false
    for it in items {
        if it[1] = "" || !HkParse(it[1], &mods, &vk)
            continue
        k := HkKey(it[1])
        owner := HotkeyTakenBy(it[1])
        HkOwnerCache[k] := owner
        if owner = "" {
            if HkTakenShown.Has(k)
                HkTakenShown.Delete(k), changed := true
            continue
        }
        if HkTakenShown.Has(k)
            continue
        HkTakenShown[k] := true, changed := true
        lines.Push(FormatHotkeyDisplay(it[1]) "  (" it[2] ")  :  " owner)
    }
    if changed
        SaveSettings()
    if !lines.Length
        return
    msg := (lines.Length = 1 ? "Shortcut also used by another program :" : "Shortcuts also used by other programs :")
    for l in lines
        msg .= "`n" l
    msg .= "`nScreen Audio Router is using " (lines.Length = 1 ? "it" : "them") ". You can change it in the window."
    ShowOsdToast(msg, MonitorGetPrimary(), "warn")
    LogLine("Startup: " StrReplace(msg, "`n", " / "))
}
