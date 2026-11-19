; Screen Audio Router - Copyright (C) 2026 panoc
; Licensed under the GNU GPL v3 or later. See LICENSE.
; ============================================================================
; Screen Audio Router  -  src\Gui.ahk
; Main window, its handlers, and the Detect / Devices / Replace Device windows
; Part of ScreenAudioRouter.ahk (included at its end). Functions only.
; ============================================================================

; ------------------------------ MAIN GUI ------------------------------------
BuildMainGui() {
    global MainGui, BtnToggleRouting, AppLV, StatusLV, BtnRemoveApp, ChkStartMin, EdtPollMs, EdtToastSec
    global ChkAutoStart, ChkFollowFocus, DdlAppFollowFocus, DdlTitleBarKey
    global ChkAppFollowMon, DdlAppFixedDevice, ChkAppSystemMic, ChkAppMicOn, DdlAppMic, ChkAppHideTray
    global MonMicChecks, MonMicDropdowns, MonMicDropdownIds, MonEnableChecks
    global LblSelAppName, DdlAppOverrideDevice, BtnToggleAppOvr, BtnResetAppOvr
    global HkCtrlApp, BtnSetAppHk, BtnClrAppHk, BtnRstAppHk
    global ChkDisableAll, ChkDisableMon, ChkDisableApp
    global ChkTitleBarMenu, ChkAllTitleBarMenu, LblRoutingModeNote
    global BtnResetAppOverrides, BtnResetMonOverrides, BtnResetAllOverrides, BtnResetWinMixer
    global BtnApplyChanges, BtnCloseGui
    global LblStatusBar, LblConflictBar
    global MonCount, DetectedMonCount, BuiltMonSignature, MonDropdowns, MonDropdownIds
    global MonOvrLabels, MonOvrDropdowns, MonOvrDropdownIds, MonOvrButtons
    global MonHkLabels, MonHkControls, MonHkSetButtons, MonHkClrButtons, MonHkRstButtons
    global LblOvrAllHeader, DdlAllAppsDevice
    global LblOvrAllMonsHeader, DdlAllMonsDevice
    global ChkAvoidConflicts, BtnFixConflicts, LblConflictStatus
    global BtnHkFocused, HkCtrlFocused
    global BtnHkAllMons, HkCtrlAllMons
    global BtnHkAll, HkCtrlAll
    global BtnHkReapply, HkCtrlReapply
    global ActiveCaptureHwnd, HoveredBtnHwnd

    ActiveCaptureHwnd := 0
    HotkeyBoxMeta.Clear()
    PurgeDeadControlMaps()                ; keeps the Detect window's colored buttons
    HoveredBtnHwnd := 0

    MonCount := MAX_MONITORS
    DetectedMonCount := Min(Max(MonitorGetCount(), 1), MAX_MONITORS)
    BuiltMonSignature := GetMonitorLayoutSignature()
    monInfos := CollectMonitorInfos()

    ; Monitor frame ends with the left column (y = 690); its blocks are spread evenly inside
    leftEndY      := 690
    monSectionH   := leftEndY - 60
    rightEndY     := 60 + monSectionH
    bodyEndY      := Max(leftEndY, rightEndY)

    ; Symmetrical bottom row: Global Hotkeys & Quick Actions (w553) + Routing Controls & Options (w553)
    hkSectionY    := bodyEndY + 8
    hkSectionH    := 154

    ; Status bar with Apply / Close at its right end
    statusBarY    := hkSectionY + hkSectionH + 8

    MainGui := Gui("-MaximizeBox", "Screen Audio Router")
    MainGui.SetFont("s9", "Segoe UI")
    MainGui.BackColor := Th("bg")
    MainGui.OnEvent("Close", OnGuiCloseRequest)
    MainGui.AddButton("x0 y0 w0 h0")               ; invisible first control: takes the focus when the window opens

    iconSrc := IconSource(101)
    if !iconSrc && A_IsCompiled
        iconSrc := {file: A_ScriptFullPath, num: 1}
    if iconSrc {
        try {
            hIcon := LoadPicture(iconSrc.file, "Icon" iconSrc.num, &imgType)
            if hIcon {
                SendMessage(0x0080, 0, hIcon, MainGui.Hwnd) ; WM_SETICON ICON_SMALL
                SendMessage(0x0080, 1, hIcon, MainGui.Hwnd) ; WM_SETICON ICON_BIG
            }
        }
    }

    ; --- Top Banner ---
    MainGui.SetFont("s" TitleSize " Bold c" Th("appTitle"), "Segoe UI")
    ttl := MainGui.AddText("x16 y" (TitleSize > 11 ? 8 : 12), "Screen Audio Router")
    ttl.GetPos(&ttlX, &ttlY, &ttlW, &ttlH)
    MainGui.SetFont("s9 Norm c" Th("muted"), "Segoe UI")
    ver := MainGui.AddText("x" (ttlX + ttlW + 6) " y" ttlY, "v" APP_VERSION)
    ver.GetPos(, , , &verH)
    ver.Move(, ttlY + ttlH - verH - 1)                 ; on the title's baseline
    MainGui.SetFont("s9 Norm c" Th("text2"), "Segoe UI")
    MainGui.AddText("x16 y" Max(34, ttlY + ttlH + 1) " w566", "Checked apps follow their screen's Output, or switch instantly via Per-App, Monitor, or Global Overrides.")

    MainGui.SetFont("s9 Bold c" Th("text"), "Segoe UI")
    BtnToggleRouting := AddColoredButton(MainGui, "x1004 y16 w128 h28", DisableAllRouting ? "Routing : OFF" : "Routing : ON", DisableAllRouting ? BtnColorRoutingOff : BtnColorRoutingOn)
    BtnToggleRouting.OnEvent("Click", ToggleMasterRouting)

    MainGui.SetFont("s9 Norm c" Th("text"), "Segoe UI")
    btnDetectWin := AddColoredButton(MainGui, "x590 y16 w100 h28", "Detect Apps...", BtnColorDetect)
    btnDetectWin.OnEvent("Click", ShowDetectWindow)
    AddTip(btnDetectWin, "List running apps and add them to the tracked apps.")

    btnRefreshDev := AddColoredButton(MainGui, "x696 y16 w104 h28", "Refresh Devices", BtnColorRefresh)
    btnRefreshDev.OnEvent("Click", OnRefreshDevices)

    btnDevices := AddColoredButton(MainGui, "x806 y16 w90 h28", "Devices...", BtnColorRefresh)
    btnDevices.OnEvent("Click", ShowDevicesDialog)
    AddTip(btnDevices, "Give devices your own names, choose which lists show them,`nand replace a device everywhere at once.")

    btnIdMon := AddColoredButton(MainGui, "x902 y16 w96 h28", "Identify Mons", BtnColorIdentifyMons)
    btnIdMon.OnEvent("Click", ShowMonitorNumbers)

    ; --- Tracked Applications: the table, and below a thin line the selected app's settings ---
    ; (one frame, y60-548; the table fills the space above the line)
    MainGui.SetFont("s9 Bold c" Th("text"), "Segoe UI")
    MainGui.AddGroupBox("x16 y60 w718 h488", "Tracked Applications  (Check to Enable)")

    AppLV := MainGui.AddListView("x28 y82 w694 h287 -Multi Grid Checked -HScroll", ["Application", "Status", "Output", "Input"])
    ; taller rows: a list's row height follows its small icons, so it gets an empty 1 px wide image list
    rowPx := Round(Max(18, Min(TABLE_ROW_HEIGHT, 40)) * A_ScreenDPI / 96)
    AppLV.SetImageList(DllCall("comctl32\ImageList_Create", "Int", 1, "Int", rowPx, "UInt", 0x20, "Int", 1, "Int", 0, "Ptr"), 1)
    AppLV.ModifyCol(1, 150)
    AppLV.ModifyCol(2, 132)
    AppLV.ModifyCol(3, 202)
    AppLV.ModifyCol(4, 186)
    AppLV.OnEvent("ItemSelect", OnAppSelect)
    AppLV.OnEvent("Click", OnAppClick)
    AppLV.OnEvent("ItemCheck", OnAppCheck)

    MainGui.AddText("x28 y379 w694 h1 Background" Th("sepLine"), "")    ; table | selected app

    ; Row 1: Selected App + Override Toggle Button
    MainGui.SetFont("s9 Norm c" Th("text"), "Segoe UI")
    MainGui.AddText("x28 y394 w96", "Selected App :")
    selCol := NormalizeHexColor(SelectedAppColor)
    selSize := Max(9, Min(SELECTED_APP_SIZE, 14))
    MainGui.SetFont("s" selSize " Bold c" (selCol != "" ? selCol : Th("accent")), "Segoe UI")
    LblSelAppName := MainGui.AddText("x138 y" (394 - (selSize - 9)) " w334 h" (16 + 2 * (selSize - 9)), "(None selected)")

    MainGui.SetFont("s9 Norm c" Th("text"), "Segoe UI")
    BtnRemoveApp := AddColoredButton(MainGui, "x480 y390 w116 h25 Disabled", "Remove App", BtnColorRemoveApp)
    BtnRemoveApp.OnEvent("Click", OnRemoveApp)
    AddTip(BtnRemoveApp, "Remove the selected app from the table (it goes back to the Windows default device).")
    BtnToggleAppOvr := AddColoredButton(MainGui, "x602 y390 w120 h25 Disabled", "Override : OFF", BtnColorAppOvrOff)
    BtnToggleAppOvr.OnEvent("Click", OnToggleSelectedAppOverride)
    AddTip(BtnToggleAppOvr, "Turn this app's override on or off.")

    ; Row 2: App Shortcut (Capture Box + Set / Clear / Reset) + Follow focus
    MainGui.SetFont("s9 Norm c" Th("text"), "Segoe UI")
    MainGui.AddText("x28 y424 w96", "App Shortcut :")
    HkCtrlApp := CreateHotkeyCaptureBox(MainGui, "x138 y421 w166 h23 Disabled", "app", "", "")

    BtnSetAppHk := AddColoredButton(MainGui, "x310 y420 w50 h24 Disabled", "Set", BtnColorHkSet)
    BtnSetAppHk.OnEvent("Click", OnApplyAppHotkey)
    BtnClrAppHk := AddColoredButton(MainGui, "x364 y420 w50 h24 Disabled", "Clear", BtnColorHkClear)
    BtnClrAppHk.OnEvent("Click", OnClearAppHotkey)
    BtnRstAppHk := AddColoredButton(MainGui, "x418 y420 w50 h24 Disabled", "Reset", BtnColorHkReset)
    BtnRstAppHk.OnEvent("Click", OnResetAppHotkey)

    ; Per-app "Follow focused window": Global (the setting in Routing Controls) / On / Off
    MainGui.SetFont("s9 Norm c" Th("text"), "Segoe UI")
    AddTip(MainGui.AddText("x480 y424 w82 +0x100", "Follow focus :")
        , "Which of this app's windows its audio follows (for apps with several windows, like browsers).")
    DdlAppFollowFocus := MainGui.AddDropDownList("x566 y421 w156 Disabled", AppFollowFocusLabels())
    DdlAppFollowFocus.Choose(1)
    DdlAppFollowFocus.OnEvent("Change", OnAppFollowFocusChanged)
    AddTip(DdlAppFollowFocus, "On: the audio follows whichever of the app's windows you used last.`n"
        . "Off: it follows its first window (or the one picked with `"Audio follows this window`").`n"
        . "Global: use `"Follow focused window`" in Routing Controls & Options.")

    ; Row 3: Follow monitor / fixed device
    ChkAppFollowMon := MainGui.AddCheckbox("x28 y452 w106 h20 Disabled", "Follow monitor")
    ChkAppFollowMon.OnEvent("Click", OnAppFollowMonitorChanged)
    AddTip(ChkAppFollowMon, "Checked: the app plays on the output of the monitor its window is on.`n"
        . "Unchecked: it always plays on the device on the right, wherever its window is.`n"
        . "Overrides, temporary overrides and the All-Apps override still apply on top.")
    DdlAppFixedDevice := MainGui.AddDropDownList("x138 y451 w330 Disabled", ["Windows Default Device"])
    DdlAppFixedDevice.OnEvent("Change", OnAppFixedDeviceChanged)
    AddTip(DdlAppFixedDevice, "Device this app always uses while Follow monitor is unchecked.")

    ; Row 4: Override Output
    MainGui.AddText("x28 y484 w106", "Override Output :")
    DdlAppOverrideDevice := MainGui.AddDropDownList("x138 y481 w330 Disabled", ["Windows Default Device"])
    DdlAppOverrideDevice.OnEvent("Change", OnSelectedAppOverrideDeviceChanged)
    AddTip(DdlAppOverrideDevice, "Device this app plays on while its override is ON, whatever monitor it is on.")
    ChkAppHideTray := MainGui.AddCheckbox("x480 y482 w242 h20 Disabled", "Hide tray icon")
    ChkAppHideTray.OnEvent("Click", OnAppHideTrayChanged)
    AddTip(ChkAppHideTray, "No extra tray icon for this app while its override is ON.`n"
        . "The override still shows in the main tray icon's tooltip and in the table.")

    ; Row 5: Override Mic + Windows default mic + Reset Override (far right)
    ChkAppMicOn := MainGui.AddCheckbox("x28 y512 w106 h20 Disabled", "Override Mic")
    ChkAppMicOn.OnEvent("Click", OnAppMicOnChanged)
    AddTip(ChkAppMicOn, "Checked: while this app's override is ON, it uses the microphone on the right.`n"
        . "Unchecked: overrides change only the sound; the app keeps the microphone of the monitor it is on`n"
        . "(the one paired with that monitor's Output in the Devices window).")
    DdlAppMic := MainGui.AddDropDownList("x138 y511 w330 Disabled", ["Paired : Windows default mic"])
    DdlAppMic.OnEvent("Change", OnAppMicDeviceChanged)
    AddTip(DdlAppMic, "Microphone used while the override is ON and Override Mic is checked.`n"
        . "Paired = the microphone paired with the Override Output device (Devices window).")
    ChkAppSystemMic := MainGui.AddCheckbox("x480 y512 w116 h20 Disabled", "Win default mic")
    ChkAppSystemMic.OnEvent("Click", OnAppSystemMicChanged)
    AddTip(ChkAppSystemMic, "Also make this app's microphone the Windows default microphone (for the whole PC)`n"
        . "whenever it changes. For apps that ignore their own per-app microphone.")

    BtnResetAppOvr := AddColoredButton(MainGui, "x602 y510 w120 h25 Disabled", "Reset Override", BtnColorResetAppOvr)
    BtnResetAppOvr.OnEvent("Click", OnResetSelectedAppOverride)
    AddTip(BtnResetAppOvr, "Set this app's override back to its defaults:`noff, Override Output = Windows Default, Override Mic off.")

    ; --- Below Per-App Override (B): Global Override Settings & Conflict Guard (Horizontal Two-Column Layout) ---
    MainGui.SetFont("s9 Bold c" Th("text"), "Segoe UI")
    MainGui.AddGroupBox("x16 y556 w718 h134", "Global Override Settings && Conflict Guard")

    ; Left Half: All-Apps Override
    MainGui.SetFont("s9 Bold c" Th("text"), "Segoe UI")
    LblOvrAllHeader := MainGui.AddText("x28 y576 w340", "All-Apps Override device  (Hotkey : " FormatHotkeyDisplay(HkOverrideAll) ")")
    MainGui.SetFont("s9 Norm c" Th("text"), "Segoe UI")

    DdlAllAppsDevice := MainGui.AddDropDownList("x28 y595 w340", ["Windows Default Device"])
    DdlAllAppsDevice.OnEvent("Change", OnAllAppsOverrideDeviceChanged)
    AddTip(DdlAllAppsDevice, "Device used by Toggle All-Apps Override (Global Hotkeys & Quick Actions).")

    ; Right Half: All-Monitors Override
    MainGui.SetFont("s9 Bold c" Th("text"), "Segoe UI")
    LblOvrAllMonsHeader := MainGui.AddText("x382 y576 w340", "All-Monitors Override device  (Hotkey : " FormatHotkeyDisplay(HkOverrideAllMons) ")")
    MainGui.SetFont("s9 Norm c" Th("text"), "Segoe UI")

    DdlAllMonsDevice := MainGui.AddDropDownList("x382 y595 w340", ["Windows Default Device"])
    DdlAllMonsDevice.OnEvent("Change", OnAllMonsOverrideDeviceChanged)
    AddTip(DdlAllMonsDevice, "Device used by Toggle All-Monitors Override (Global Hotkeys & Quick Actions).")

    ; Bottom Row: Conflict Guard
    MainGui.SetFont("s9 Norm c" Th("text"), "Segoe UI")
    ChkAvoidConflicts := MainGui.AddCheckbox("x28 y628 w264 h20", "Avoid contradicting overrides (auto-prevent)")
    AddTip(ChkAvoidConflicts, "Automatically prevent override settings that contradict each other.")
    ChkAvoidConflicts.Value := AvoidConflicts ? 1 : 0
    ChkAvoidConflicts.OnEvent("Click", OnToggleAvoidConflicts)

    BtnFixConflicts := AddColoredButton(MainGui, "x298 y626 w54 h23 Disabled", "Fix", BtnColorFixConflicts)
    BtnFixConflicts.OnEvent("Click", ResolveAllConflicts)

    ; Resets: right half, under the All-Monitors list (3 x 108 + 2 x 8 = its 340 px)
    BtnResetAllOverrides := AddColoredButton(MainGui, "x382 y625 w108 h25", "Reset Overrides", BtnColorResetOverrides)
    BtnResetAllOverrides.OnEvent("Click", ResetOverridesToDefaults)
    AddTip(BtnResetAllOverrides, "Set every override back to its default (asks first):`n"
        . "all overrides off, all override devices back to Windows Default, all Override Mic / Mic off.`n"
        . "Tracked apps, monitor outputs, hotkeys, names, microphone pairs and options stay.")
    BtnResetWinMixer := AddColoredButton(MainGui, "x498 y625 w108 h25", "Reset Win Mixer", BtnColorResetWinMixer)
    BtnResetWinMixer.OnEvent("Click", ResetWindowsVolumeMixer)
    AddTip(BtnResetWinMixer, "Put every app (tracked or not) back on the Windows default device and microphone,`n"
        . "end all overrides and turn routing OFF. Volumes are not changed.")
    btnResetAll := AddColoredButton(MainGui, "x614 y625 w108 h25", "Reset All...", BtnColorResetSettings)
    btnResetAll.OnEvent("Click", ResetAllSettings)
    AddTip(btnResetAll, "Return Screen Audio Router to its first-start settings (asks first, keeps a backup).")
    MainGui.SetFont("s8 Bold c" Th("ok"), "Segoe UI")
    LblConflictStatus := MainGui.AddText("x28 y654 w694 h30", "✓ No rule or override contradictions")   ; 2 lines

    ; --- Column 3 (Right): Global Monitor Rules & Overrides (4 monitor blocks, frame ends with the left column) ---
    monHeader := Format("Global Monitor Rules && Overrides  ({1} / {2} Detected)", DetectedMonCount, MAX_MONITORS)
    MainGui.SetFont("s9 Bold c" Th("text"), "Segoe UI")
    MainGui.AddGroupBox("x744 y60 w388 h" monSectionH, monHeader)

    MonDropdowns.Clear()
    MonDropdownIds.Clear()
    MonOvrLabels.Clear()
    MonOvrDropdowns.Clear()
    MonOvrDropdownIds.Clear()
    MonOvrButtons.Clear()
    MonHkLabels.Clear()
    MonHkControls.Clear()
    MonHkSetButtons.Clear()
    MonHkClrButtons.Clear()
    MonHkRstButtons.Clear()
    MonMicChecks.Clear()
    MonEnableChecks.Clear()
    MonMicDropdowns.Clear()
    MonMicDropdownIds.Clear()

    ; 4 blocks of 134 px (rows 30 px apart, as in the Per-App section): first at y82, last ending
    ; 14 px above the frame bottom, equal gaps
    monBlockH := 134
    monStep := Max(monBlockH + 12, (60 + monSectionH - 14 - monBlockH - 82) // Max(MAX_MONITORS - 1, 1))
    yPos := 82
    for info in monInfos {
        mIdx := info.idx
        isConn := info.connected
        isSubEnabled := isConn && !IsMonitorDisabled(mIdx)
        disOpt := isConn ? "" : " Disabled"
        subDisOpt := isSubEnabled ? "" : " Disabled"

        if isConn {
            posPart := (info.posTag != "") ? "  [" info.posTag "]" : ""
            priPart := info.isPrimary ? "  [Primary]" : ""
            titleTxt := Format("Monitor {1}  ({2}){3}{4}", mIdx, info.res, posPart, priPart)
            MainGui.SetFont("s9 Bold c" Th("textHead"), "Segoe UI")
        } else {
            titleTxt := Format("Monitor {1}  (Not Detected)", mIdx)
            MainGui.SetFont("s9 Bold c" Th("muted"), "Segoe UI")
        }
        MainGui.AddText("x756 y" yPos " w286", titleTxt)

        ; Enabled (right end of the title line): unticked = this monitor gives the Windows default
        MainGui.SetFont("s9 Norm c" Th("text"), "Segoe UI")
        enChk := MainGui.AddCheckbox("x1050 y" (yPos - 2) " w70 h20" disOpt, "Enabled")
        enChk.Value := IsMonitorDisabled(mIdx) ? 0 : 1
        enChk.OnEvent("Click", OnMonitorEnabledChanged.Bind(mIdx))
        AddTip(enChk, "Unticked: apps on this monitor play on the Windows default device and microphone,`n"
            . "its override and hotkey are off. Its Output, Ovrd and Mic settings are kept.")
        MonEnableChecks[mIdx] := enChk

        ; Output Row
        MainGui.SetFont("s9 Norm " (isConn ? "c" Th("text") : "c" Th("muted")), "Segoe UI")
        MainGui.AddText("x756 y" (yPos + 24) " w48", "Output :")
        ddl := MainGui.AddDropDownList("x808 y" (yPos + 21) " w312" subDisOpt, ["Windows Default Device"])
        ddl.OnEvent("Change", OnGlobalRuleChanged.Bind(mIdx))
        MonDropdowns[mIdx] := ddl
        MonDropdownIds[mIdx] := [DEFAULT_DEVICE]

        ; Ovrd Row
        MainGui.SetFont("s9 Norm " (isSubEnabled ? "c" Th("text") : "c" Th("muted")), "Segoe UI")
        MonOvrLabels[mIdx] := MainGui.AddText("x756 y" (yPos + 54) " w48", "Ovrd :")
        MainGui.SetFont("s9 Norm c" Th("text"), "Segoe UI")
        ovrDdl := MainGui.AddDropDownList("x808 y" (yPos + 51) " w234" subDisOpt, ["Windows Default Device"])
        ovrDdl.OnEvent("Change", OnMonitorOverrideDeviceChanged.Bind(mIdx))
        MonOvrDropdowns[mIdx] := ovrDdl
        MonOvrDropdownIds[mIdx] := [DEFAULT_DEVICE]

        isOvrOn := isSubEnabled && MonitorOverrideActive.Get(mIdx, false)
        ovrBtn := AddColoredButton(MainGui, "x1046 y" (yPos + 50) " w74 h24" subDisOpt, isOvrOn ? "Ovrd : ON" : "Ovrd : OFF", isOvrOn ? BtnColorMonOvrOn : BtnColorMonOvrOff)
        ovrBtn.OnEvent("Click", ToggleMonitorOverrideByIndex.Bind(mIdx))
        MonOvrButtons[mIdx] := ovrBtn

        ; Mic Row: Mic override (counts while this monitor's override is on) + its microphone
        MainGui.SetFont("s9 Norm c" Th("text"), "Segoe UI")
        micChk := MainGui.AddCheckbox("x756 y" (yPos + 82) " w50 h20" subDisOpt, "Mic")
        micChk.Value := MonMicOn.Has(mIdx) ? 1 : 0
        micChk.OnEvent("Click", OnMonMicOnChanged.Bind(mIdx))
        AddTip(micChk, "Mic override. Checked: while this monitor's override is ON, apps on it use the microphone on the right.`n"
            . "Unchecked: overrides change only the sound; apps keep this monitor's microphone`n"
            . "(the one paired with its Output in the Devices window).")
        MonMicChecks[mIdx] := micChk
        micDdl := MainGui.AddDropDownList("x808 y" (yPos + 81) " w312 Disabled", ["Paired : Windows default mic"])
        micDdl.OnEvent("Change", OnMonMicDeviceChanged.Bind(mIdx))
        AddTip(micDdl, "Microphone used while this monitor's override is ON and Mic is checked.`n"
            . "Paired = the microphone paired with the Ovrd device (Devices window).")
        MonMicDropdowns[mIdx] := micDdl
        MonMicDropdownIds[mIdx] := [""]

        ; Hotkey Row (Capture Box + Set / Clear / Reset)
        MainGui.SetFont("s9 Norm " (isSubEnabled ? "c" Th("text2") : "c" Th("muted")), "Segoe UI")
        MonHkLabels[mIdx] := MainGui.AddText("x756 y" (yPos + 114) " w48", "Hotkey :")
        MainGui.SetFont("s9 Norm c" Th("text"), "Segoe UI")
        mHkCtrl := CreateHotkeyCaptureBox(MainGui, "x808 y" (yPos + 111) " w154 h23" subDisOpt, "mon", mIdx, MonHotkeys.Get(mIdx, ""))
        MonHkControls[mIdx] := mHkCtrl

        btnMSet := AddColoredButton(MainGui, "x968 y" (yPos + 110) " w48 h24" subDisOpt, "Set", BtnColorHkSet)
        btnMSet.OnEvent("Click", OnApplyMonitorHotkey.Bind(mIdx))
        MonHkSetButtons[mIdx] := btnMSet

        btnMClr := AddColoredButton(MainGui, "x1020 y" (yPos + 110) " w48 h24" subDisOpt, "Clear", BtnColorHkClear)
        btnMClr.OnEvent("Click", OnClearMonitorHotkey.Bind(mIdx))
        MonHkClrButtons[mIdx] := btnMClr

        btnMRst := AddColoredButton(MainGui, "x1072 y" (yPos + 110) " w48 h24" subDisOpt, "Reset", BtnColorHkReset)
        btnMRst.OnEvent("Click", OnResetMonitorHotkey.Bind(mIdx))
        MonHkRstButtons[mIdx] := btnMRst

        if mIdx < MAX_MONITORS
            MainGui.AddText("x756 y" (yPos + monBlockH + (monStep - monBlockH) // 2) " w364 h1 Background" Th("sepLine"))

        yPos += monStep
    }

    ; --- Bottom-Left Symmetrical Panel: Global Hotkeys & Quick Actions (w553) ---
    MainGui.SetFont("s9 Bold c" Th("text"), "Segoe UI")
    MainGui.AddGroupBox("x16 y" hkSectionY " w553 h" hkSectionH, "Global Hotkeys && Quick Actions  (Click a Box to Capture a Key)")

    ; Row 1: Focused App Override
    r1Y := hkSectionY + 23
    MainGui.SetFont("s9 Norm c" Th("text"), "Segoe UI")
    BtnHkFocused := AddColoredButton(MainGui, "x28 y" (r1Y - 2) " w180 h25", "Focused App Override", BtnColorQuickSelectedOff)
    BtnHkFocused.OnEvent("Click", ToggleFocusedFromGui)

    MainGui.AddText("x216 y" (r1Y + 2) " w46", "Hotkey :")
    HkCtrlFocused := CreateHotkeyCaptureBox(MainGui, "x266 y" (r1Y - 1) " w136 h23", "focused", "", HkOverrideFocused)

    btnSetHk1 := AddColoredButton(MainGui, "x408 y" (r1Y - 2) " w48 h25", "Set", BtnColorHkSet)
    btnSetHk1.OnEvent("Click", OnApplyHotkey.Bind("focused"))
    btnClrHk1 := AddColoredButton(MainGui, "x460 y" (r1Y - 2) " w48 h25", "Clear", BtnColorHkClear)
    btnClrHk1.OnEvent("Click", OnClearHotkey.Bind("focused"))
    btnDefHk1 := AddColoredButton(MainGui, "x512 y" (r1Y - 2) " w48 h25", "Reset", BtnColorHkReset)
    btnDefHk1.OnEvent("Click", OnResetHotkey.Bind("focused"))

    ; Row 3: Global All-Monitors Override
    r2Y := hkSectionY + 87
    BtnHkAllMons := AddColoredButton(MainGui, "x28 y" (r2Y - 2) " w180 h25", "Toggle All-Monitors Override", BtnColorQuickAllMonsOff)
    BtnHkAllMons.OnEvent("Click", ToggleAllMonitorsOverride)
    AddTip(BtnHkAllMons, "Send every monitor to the All-Monitors Override device (Global Override Settings).`nWhile any monitor override is on, this ends all monitor overrides instead.")

    MainGui.AddText("x216 y" (r2Y + 2) " w46", "Hotkey :")
    HkCtrlAllMons := CreateHotkeyCaptureBox(MainGui, "x266 y" (r2Y - 1) " w136 h23", "allmons", "", HkOverrideAllMons)

    btnSetHkM := AddColoredButton(MainGui, "x408 y" (r2Y - 2) " w48 h25", "Set", BtnColorHkSet)
    btnSetHkM.OnEvent("Click", OnApplyHotkey.Bind("allmons"))
    btnClrHkM := AddColoredButton(MainGui, "x460 y" (r2Y - 2) " w48 h25", "Clear", BtnColorHkClear)
    btnClrHkM.OnEvent("Click", OnClearHotkey.Bind("allmons"))
    btnDefHkM := AddColoredButton(MainGui, "x512 y" (r2Y - 2) " w48 h25", "Reset", BtnColorHkReset)
    btnDefHkM.OnEvent("Click", OnResetHotkey.Bind("allmons"))

    ; Row 2: All-Apps Override
    r3Y := hkSectionY + 55
    BtnHkAll := AddColoredButton(MainGui, "x28 y" (r3Y - 2) " w180 h25", "Toggle All-Apps Override", BtnColorQuickAllAppsOff)
    BtnHkAll.OnEvent("Click", ToggleAll)
    AddTip(BtnHkAll, "Send every tracked app to the All-Apps Override device (Global Override Settings).`nWhile any app override is on, this ends all app overrides instead.")

    MainGui.AddText("x216 y" (r3Y + 2) " w46", "Hotkey :")
    HkCtrlAll := CreateHotkeyCaptureBox(MainGui, "x266 y" (r3Y - 1) " w136 h23", "all", "", HkOverrideAll)

    btnSetHk2 := AddColoredButton(MainGui, "x408 y" (r3Y - 2) " w48 h25", "Set", BtnColorHkSet)
    btnSetHk2.OnEvent("Click", OnApplyHotkey.Bind("all"))
    btnClrHk2 := AddColoredButton(MainGui, "x460 y" (r3Y - 2) " w48 h25", "Clear", BtnColorHkClear)
    btnClrHk2.OnEvent("Click", OnClearHotkey.Bind("all"))
    btnDefHk2 := AddColoredButton(MainGui, "x512 y" (r3Y - 2) " w48 h25", "Reset", BtnColorHkReset)
    btnDefHk2.OnEvent("Click", OnResetHotkey.Bind("all"))

    ; Row 4: Re-apply Routing Now
    r4Y := hkSectionY + 119
    BtnHkReapply := AddColoredButton(MainGui, "x28 y" (r4Y - 2) " w180 h25", "Re-apply Routing Now", BtnColorQuickActions)
    BtnHkReapply.OnEvent("Click", ReapplyAll)

    MainGui.AddText("x216 y" (r4Y + 2) " w46", "Hotkey :")
    HkCtrlReapply := CreateHotkeyCaptureBox(MainGui, "x266 y" (r4Y - 1) " w136 h23", "reapply", "", HkReapply)

    btnSetHk3 := AddColoredButton(MainGui, "x408 y" (r4Y - 2) " w48 h25", "Set", BtnColorHkSet)
    btnSetHk3.OnEvent("Click", OnApplyHotkey.Bind("reapply"))
    btnClrHk3 := AddColoredButton(MainGui, "x460 y" (r4Y - 2) " w48 h25", "Clear", BtnColorHkClear)
    btnClrHk3.OnEvent("Click", OnClearHotkey.Bind("reapply"))
    btnDefHk3 := AddColoredButton(MainGui, "x512 y" (r4Y - 2) " w48 h25", "Reset", BtnColorHkReset)
    btnDefHk3.OnEvent("Click", OnResetHotkey.Bind("reapply"))

    ; --- Bottom-Right Symmetrical Panel: Routing Controls & Options (w553) ---
    MainGui.SetFont("s9 Bold c" Th("text"), "Segoe UI")
    MainGui.AddGroupBox("x579 y" hkSectionY " w553 h" hkSectionH, "Routing Controls && Options")

    ; Grid: a muted row label, then three fixed columns (A / B / C) so every option lines up.
    rx := 591, cA := 690, cB := 852, cC := 990
    r1 := hkSectionY + 24, r2 := hkSectionY + 50, r3 := hkSectionY + 76, r4 := hkSectionY + 102

    MainGui.SetFont("s9 Norm c" Th("text2"), "Segoe UI")
    AddTip(MainGui.AddText("x" rx " y" (r1 + 2) " w96 +0x100", "Disable :")
        , "Turn routing off completely, or only one kind of rule.")
    AddTip(MainGui.AddText("x" rx " y" (r2 + 2) " w96 +0x100", "Title-bar menu :")
        , "A menu on a window's title bar for adding apps, choosing their override device and`npicking which window an app's audio follows.")
    AddTip(MainGui.AddText("x" rx " y" (r3 + 2) " w96 +0x100", "Tracking :")
        , "How the script decides which monitor an app is on.")
    AddTip(MainGui.AddText("x" rx " y" (r4 + 2) " w96 +0x100", "Startup && look :")
        , "How the app starts and how it looks.")

    MainGui.SetFont("s9 Norm c" Th("text"), "Segoe UI")
    ; Row 1: Disable
    ChkDisableAll := MainGui.AddCheckbox("x" cA " y" r1 " w156 h20", "All routing")
    ChkDisableAll.Value := DisableAllRouting ? 1 : 0
    ChkDisableAll.OnEvent("Click", OnRoutingDisableOptionChanged)
    AddTip(ChkDisableAll, "Stop all routing. Tracked apps go back to the Windows default device.")

    ChkDisableMon := MainGui.AddCheckbox("x" cB " y" r1 " w134 h20", "Monitor routing")
    ChkDisableMon.Value := DisableMonitorRouting ? 1 : 0
    ChkDisableMon.Enabled := !DisableAllRouting
    ChkDisableMon.OnEvent("Click", OnRoutingDisableOptionChanged)
    AddTip(ChkDisableMon, "Ignore the monitor outputs and monitor overrides.`nPer-app overrides still apply.")

    ChkDisableApp := MainGui.AddCheckbox("x" cC " y" r1 " w130 h20", "App routing")
    ChkDisableApp.Value := DisableAppRouting ? 1 : 0
    ChkDisableApp.Enabled := !DisableAllRouting
    ChkDisableApp.OnEvent("Click", OnRoutingDisableOptionChanged)
    AddTip(ChkDisableApp, "Ignore per-app overrides and the All-Apps override.`nMonitor outputs still apply.")

    ; Row 2: Title-bar menu
    DdlTitleBarKey := MainGui.AddDropDownList("x" cA " y" (r2 - 3) " w146", TitleBarKeyLabels())
    DdlTitleBarKey.Choose(Max(1, TitleBarKeyIndex(TitleBarMenuKey)))
    DdlTitleBarKey.OnEvent("Change", OnTitleBarKeyChanged)
    AddTip(DdlTitleBarKey, "Mouse combination that opens the menu on a window's title bar.")

    ChkTitleBarMenu := MainGui.AddCheckbox("x" cB " y" r2 " w134 h20", "Tracked apps")
    ChkTitleBarMenu.Value := EnableTitleBarMenu ? 1 : 0
    ChkTitleBarMenu.OnEvent("Click", OnSettingChanged)
    AddTip(ChkTitleBarMenu, "Show the menu on the title bars of tracked apps.")

    ChkAllTitleBarMenu := MainGui.AddCheckbox("x" cC " y" r2 " w130 h20", "All apps")
    ChkAllTitleBarMenu.Value := EnableAllAppsTitleBarMenu ? 1 : 0
    ChkAllTitleBarMenu.OnEvent("Click", OnSettingChanged)
    AddTip(ChkAllTitleBarMenu, "Show the menu on every window's title bar, so untracked apps can be added from it.")

    ; Row 3: Tracking
    ChkFollowFocus := MainGui.AddCheckbox("x" cA " y" r3 " w158 h20", "Follow focused window")
    ChkFollowFocus.Value := FollowFocusGlobal ? 1 : 0
    ChkFollowFocus.OnEvent("Click", OnFollowFocusChanged)
    AddTip(ChkFollowFocus, "Off: an app's audio follows its first window (pick another from the title-bar menu).`n"
        . "On: it follows whichever of its windows you used last.`nEach app can override this in the Per-App section.")

    AddTip(MainGui.AddText("x" cB " y" (r3 + 2) " w62 +0x100", EventsActive ? "Fallback :" : "Poll :")
        , EventsActive ? "How often (ms) window positions are re-checked as a safety net.`nWindow moves are normally picked up instantly."
                       : "How often (ms) window positions are checked.")
    EdtPollMs := MainGui.AddEdit("x" (cB + 64) " y" (r3 - 1) " w56 h22 Number", EventsActive ? FallbackPollMs : PollMs)
    EdtPollMs.OnEvent("Change", (*) => UpdateApplyButton())
    MainGui.AddText("x" (cB + 126) " y" (r3 + 2) " w24", "ms")

    AddTip(MainGui.AddText("x1010 y" (r3 + 2) " w46 +0x100", "Notify :")
        , "How many seconds notifications stay on screen (1-30).`nWarnings, such as a missing device, stay twice as long (at least 6 s).")
    EdtToastSec := MainGui.AddEdit("x1056 y" (r3 - 1) " w34 h22 Number", ToastSec)
    EdtToastSec.OnEvent("Change", (*) => UpdateApplyButton())
    MainGui.AddText("x1094 y" (r3 + 2) " w14", "s")

    ; Row 4: Startup
    ChkStartMin := MainGui.AddCheckbox("x" cA " y" r4 " w156 h20", "Start in tray")
    ChkStartMin.Value := StartMinimized ? 1 : 0
    ChkStartMin.OnEvent("Click", OnSettingChanged)
    AddTip(ChkStartMin, "Start hidden in the tray instead of opening this window.")

    ChkAutoStart := MainGui.AddCheckbox("x" cB " y" r4 " w134 h20", "Start with Windows")
    ChkAutoStart.Value := IsAutoStartEnabled() ? 1 : 0
    ChkAutoStart.OnEvent("Click", OnAutoStartChanged)
    AddTip(ChkAutoStart, "Start Screen Audio Router when you sign in to Windows.")

    ; Status line
    MainGui.SetFont("s8 Bold c" Th("ok"), "Segoe UI")
    LblRoutingModeNote := MainGui.AddText("x" rx " y" (hkSectionY + 128) " w529 h18", "● Active : Monitor Routing + Per-App Routing enabled")

    ; --- Bottom Status Bar: Override Status Messages ---
    MainGui.SetFont("s9 Bold c" Th("text"), "Segoe UI")
    MainGui.AddGroupBox("x16 y" statusBarY " w880 h40", "")

    MainGui.SetFont("s9 Bold c" Th("ok"), "Segoe UI")
    LblStatusBar := MainGui.AddText("x28 y" (statusBarY + 14) " w584", "Status : Automatic (Using Global Screen Rules)")

    MainGui.SetFont("s8 Bold c" Th("text2"), "Segoe UI")
    LblConflictBar := MainGui.AddText("x616 y" (statusBarY + 15) " w268 Right", "Active Overrides : 0")

    ; Apply (grey while there is nothing to apply) and Close, at the right end of the status row,
    ; as high as the status frame's visible box (its top line is drawn 7 px below its y)
    MainGui.SetFont("s9 Bold c" Th("text"), "Segoe UI")
    BtnApplyChanges := AddColoredButton(MainGui, "x904 y" (statusBarY + 7) " w110 h33 Disabled", "Apply", BtnColorApply)
    BtnApplyChanges.OnEvent("Click", OnApplyAllChangesClick)
    AddTip(BtnApplyChanges, "Apply recorded hotkeys and the Fallback / Notify values.`nEverything else applies as soon as you change it.")
    BtnCloseGui := AddColoredButton(MainGui, "x1022 y" (statusBarY + 7) " w110 h33", "Close", BtnColorClose)
    BtnCloseGui.OnEvent("Click", OnGuiCloseRequest)

    if !FileExist(SVV) && !(NativeAudio && IsObject(AudioPolicyFactory())) {
        LblStatusBar.Opt("c" Th("err"))
        LblStatusBar.Value := "WARNING : SoundVolumeView.exe not found next to script! Audio routing cannot switch devices."
    }

    UpdateRoutingModeLabel()
    RefreshHotkeyIndicators()
    ApplyThemeToWindow(MainGui)
}

; ------------------------------ APPLY & CLOSE UNSAVED-CHANGES GUARD ---------
HasUnappliedGuiChanges() {
    if !IsObject(MainGui) || !WinExist("ahk_id " MainGui.Hwnd)
        return false

    if GetHotkeyBoxPending(HkCtrlFocused) != HkOverrideFocused
        return true
    if GetHotkeyBoxPending(HkCtrlAllMons) != HkOverrideAllMons
        return true
    if GetHotkeyBoxPending(HkCtrlAll) != HkOverrideAll
        return true
    if GetHotkeyBoxPending(HkCtrlReapply) != HkReapply
        return true

    Loop DetectedMonCount {
        mIdx := A_Index
        if MonHkControls.Has(mIdx) && !IsMonitorDisabled(mIdx) && GetHotkeyBoxPending(MonHkControls[mIdx]) != MonHotkeys.Get(mIdx, "")
            return true
    }

    if SelectedApp != "" && Apps.Has(SelectedApp) && IsObject(HkCtrlApp) {
        if GetHotkeyBoxPending(HkCtrlApp) != AppHotkeys.Get(SelectedApp, "")
            return true
    }

    if IsObject(EdtPollMs) {
        curVal := IsInteger(EdtPollMs.Value) ? Integer(EdtPollMs.Value) : -1
        savedVal := EventsActive ? FallbackPollMs : PollMs
        if curVal != savedVal
            return true
    }

    if IsObject(EdtToastSec) {
        if (IsInteger(EdtToastSec.Value) ? Integer(EdtToastSec.Value) : -1) != ToastSec
            return true
    }

    return false
}

ApplyChangesFromGui(silent := false) {
    global PollMs, FallbackPollMs, ToastSec
    if ActiveCaptureHwnd != 0
        StopHotkeyCapture(false)

    allOk := true

    ; A shortcut that another program uses is only applied after "Use it anyway?" (a No puts
    ; the box back to the saved shortcut, which doesn't count as a failure).
    for item in [["focused", HkCtrlFocused, HkOverrideFocused], ["allmons", HkCtrlAllMons, HkOverrideAllMons]
               , ["all", HkCtrlAll, HkOverrideAll], ["reapply", HkCtrlReapply, HkReapply]] {
        pend := GetHotkeyBoxPending(item[2])
        if pend != item[3] && ConfirmHotkeyUse(pend, item[1], item[3], item[2])
            allOk &= RegisterSingleHotkey(item[1], pend, true)
    }

    Loop DetectedMonCount {
        mIdx := A_Index
        if MonHkControls.Has(mIdx) && !IsMonitorDisabled(mIdx) {
            pend := GetHotkeyBoxPending(MonHkControls[mIdx])
            saved := MonHotkeys.Get(mIdx, "")
            if pend != saved && ConfirmHotkeyUse(pend, "mon:" mIdx, saved, MonHkControls[mIdx])
                allOk &= RegisterMonitorHotkey(mIdx, pend, true)
        }
    }

    if SelectedApp != "" && Apps.Has(SelectedApp) && IsObject(HkCtrlApp) {
        pendApp := GetHotkeyBoxPending(HkCtrlApp)
        saved := AppHotkeys.Get(SelectedApp, "")
        if pendApp != saved && ConfirmHotkeyUse(pendApp, "app:" StrLower(SelectedApp), saved, HkCtrlApp)
            allOk &= RegisterAppHotkey(SelectedApp, pendApp, true)
    }

    if IsObject(EdtPollMs) {
        val := IsInteger(EdtPollMs.Value) ? Integer(EdtPollMs.Value) : 500
        if EventsActive {
            FallbackPollMs := Max(500, Min(val, 10000))
            EdtPollMs.Value := FallbackPollMs
        } else {
            PollMs := Max(150, Min(val, 10000))
            EdtPollMs.Value := PollMs
        }
        ApplyPollTimer()
    }

    if IsObject(EdtToastSec) {
        ToastSec := IsInteger(EdtToastSec.Value) ? Max(1, Min(Integer(EdtToastSec.Value), 30)) : 3
        EdtToastSec.Value := ToastSec
    }

    SaveSettings()
    SaveHotkeys()
    SaveState()

    if !silent {
        if allOk
            Tip("All changes applied and saved")
        else
            Tip("Some shortcuts could not be applied (conflict or reserved)")
    }
    UpdateApplyButton()
    return allOk
}

; Apply is clickable only while something is waiting to be applied.
UpdateApplyButton() {
    try {
        if IsObject(BtnApplyChanges)
            SetCtrlEnabled(BtnApplyChanges, HasUnappliedGuiChanges())
    }
}

RevertUnappliedGuiChanges() {
    SetHotkeyBoxValue(HkCtrlFocused, HkOverrideFocused, "normal")
    SetHotkeyBoxValue(HkCtrlAllMons, HkOverrideAllMons, "normal")
    SetHotkeyBoxValue(HkCtrlAll, HkOverrideAll, "normal")
    SetHotkeyBoxValue(HkCtrlReapply, HkReapply, "normal")

    Loop MAX_MONITORS {
        mIdx := A_Index
        if MonHkControls.Has(mIdx)
            SetHotkeyBoxValue(MonHkControls[mIdx], MonHotkeys.Get(mIdx, ""), "normal")
    }

    if SelectedApp != "" && Apps.Has(SelectedApp) && IsObject(HkCtrlApp)
        SetHotkeyBoxValue(HkCtrlApp, AppHotkeys.Get(SelectedApp, ""), "normal")

    if IsObject(EdtPollMs)
        EdtPollMs.Value := EventsActive ? FallbackPollMs : PollMs
    if IsObject(EdtToastSec)
        EdtToastSec.Value := ToastSec
    UpdateApplyButton()
}

OnApplyAllChangesClick(*) {
    ApplyChangesFromGui(false)
}

OnGuiCloseRequest(*) {
    if ActiveCaptureHwnd != 0
        StopHotkeyCapture(false)

    if HasUnappliedGuiChanges() {
        res := MsgBox(
            "You have unapplied changes (shortcuts or poll interval).`n`nDo you want to apply them before closing?",
            "Unsaved Changes",
            "YesNoCancel Icon?"
        )
        if res = "Cancel"
            return true
        if res = "Yes" {
            if !ApplyChangesFromGui(false)
                return true
        } else {
            RevertUnappliedGuiChanges()
        }
    }

    HideMainGui()
    return true
}

; ------------------------------ DETECT WINDOW -------------------------------
ShowDetectWindow(*) {
    global DetectWindow, DetectedLV, EdtFilter, ChkShowAllProcs
    if IsObject(DetectWindow) && WinExist("ahk_id " DetectWindow.Hwnd) {
        DetectWindow.Show()
        return
    }

    ownerOpt := ""
    try {
        if IsObject(MainGui) && DllCall("IsWindowVisible", "Ptr", MainGui.Hwnd)
            ownerOpt := " +Owner" MainGui.Hwnd      ; owned: always stays above the main window
    }
    DetectWindow := Gui("-MaximizeBox" (ownerOpt != "" ? ownerOpt : " +AlwaysOnTop"), "Detected Running Apps")
    DetectWindow.SetFont("s9 c" Th("text"), "Segoe UI")
    DetectWindow.BackColor := Th("bg")
    DetectWindow.AddButton("x0 y0 w0 h0")          ; invisible first control: takes the focus when the window opens

    DetectWindow.AddText("x16 y12 w42", "Filter :")
    EdtFilter := DetectWindow.AddEdit("x60 y9 w172 h23", "")
    EdtFilter.OnEvent("Change", (*) => RenderDetectedList())

    btnDetect := AddColoredButton(DetectWindow, "x240 y8 w68 h25", "Detect", BtnColorDetectWinDetect)
    btnDetect.OnEvent("Click", OnDetectClick)

    ChkShowAllProcs := DetectWindow.AddCheckbox("x318 y12 w90", "All procs")
    ChkShowAllProcs.OnEvent("Click", (*) => RenderDetectedList())

    DetectedLV := DetectWindow.AddListView("x16 y40 w440 h340 Grid", ["Process (.exe)", "Activity / Window"])
    DetectedLV.ModifyCol(1, 132)
    DetectedLV.ModifyCol(2, 292)
    DetectedLV.OnEvent("DoubleClick", OnAddDetectedApps)

    btnAddSelected := AddColoredButton(DetectWindow, "x16 y388 w212 h30", "Add Selected to Tracked ->", BtnColorDetectWinAdd)
    btnAddSelected.OnEvent("Click", OnAddDetectedApps)

    btnCloseDetect := AddColoredButton(DetectWindow, "x244 y388 w212 h30", "Close Window", BtnColorDetectWinClose)
    btnCloseDetect.OnEvent("Click", CloseDetectWindow)
    DetectWindow.OnEvent("Close", CloseDetectWindow)

    ApplyThemeToWindow(DetectWindow)
    ScanAndRenderDetected()
    pos := ""
    if ownerOpt != "" {                                 ; centered over the main window
        try {
            WinGetPos(&mx, &my, &mw, &mh, MainGui.Hwnd)
            sc := A_ScreenDPI / 96
            pos := Format("x{1} y{2} ", mx + (mw - Round(488 * sc)) // 2, my + Max(0, (mh - Round(466 * sc)) // 2))
        }
    }
    DetectWindow.Show(pos "w472 h428")
}

CloseDetectWindow(*) {
    global CachedCandidates, DetectWindow, DetectedLV, EdtFilter, ChkShowAllProcs
    CachedCandidates := []
    try {
        if IsObject(DetectWindow)
            DetectWindow.Destroy()
    }
    DetectWindow := "", DetectedLV := "", EdtFilter := "", ChkShowAllProcs := ""
    PurgeDeadControlMaps()
}

CollectMonitorInfos() {
    cnt := Min(Max(MonitorGetCount(), 1), MAX_MONITORS)
    pri := MonitorGetPrimary()
    raw := []

    minCx := 999999, maxCx := -999999
    minCy := 999999, maxCy := -999999
    sumCx := 0, sumCy := 0

    Loop cnt {
        MonitorGet(A_Index, &l, &t, &r, &b)
        cx := (l + r) // 2
        cy := (t + b) // 2
        if cx < minCx
            minCx := cx
        if cx > maxCx
            maxCx := cx
        if cy < minCy
            minCy := cy
        if cy > maxCy
            maxCy := cy
        sumCx += cx
        sumCy += cy
        raw.Push({
            idx: A_Index,
            l: l, t: t, r: r, b: b,
            cx: cx, cy: cy,
            res: (r - l) "x" (b - t),
            isPrimary: (A_Index = pri),
            posTag: "",
            connected: true
        })
    }

    if cnt > 1 {
        avgCx := sumCx / cnt
        avgCy := sumCy / cnt
        horizSpread := maxCx - minCx
        vertSpread  := maxCy - minCy

        for m in raw {
            leftRank := 1
            topRank  := 1
            for other in raw {
                if other.cx < m.cx || (other.cx = m.cx && other.idx < m.idx)
                    leftRank++
                if other.cy < m.cy || (other.cy = m.cy && other.idx < m.idx)
                    topRank++
            }

            if vertSpread < 250 {
                if cnt = 2
                    m.posTag := (leftRank = 1) ? "Left" : "Right"
                else if cnt = 3
                    m.posTag := (leftRank = 1) ? "Left" : (leftRank = 2 ? "Center" : "Right")
                else if cnt = 4
                    m.posTag := (leftRank = 1) ? "Far-Left" : (leftRank = 2 ? "Center-Left" : (leftRank = 3 ? "Center-Right" : "Far-Right"))
                else
                    m.posTag := "Pos " leftRank
            } else if horizSpread < 250 {
                if cnt = 2
                    m.posTag := (topRank = 1) ? "Top" : "Bottom"
                else
                    m.posTag := (topRank = 1) ? "Top" : (topRank = cnt ? "Bottom" : "Middle")
            } else {
                vLabel := (m.cy < avgCy) ? "Top" : "Bottom"
                hLabel := (m.cx < avgCx) ? "Left" : "Right"
                m.posTag := vLabel "-" hLabel
            }
        }
    }

    while raw.Length < MAX_MONITORS {
        raw.Push({
            idx: raw.Length + 1,
            l: 0, t: 0, r: 0, b: 0,
            cx: 0, cy: 0,
            res: "Not Detected",
            isPrimary: false,
            posTag: "",
            connected: false
        })
    }

    return raw
}

ShowMainGui(*) {
    global CachedDevices, DevicesStale
    CheckAudioEndpointsNow()
    if DevicesStale {
        CachedDevices := GetDevices()
        DevicesStale := false
    }
    if !CachedDevices.Length
        CachedDevices := GetDevices()
    if !IsObject(MainGui) || GuiDirty || GetMonitorLayoutSignature() != BuiltMonSignature {
        RebuildMainGuiIfNeeded(true)      ; builds and fills every list
    } else {
        PopulateMonitorDropdowns()
        PopulateOverrideDeviceDropdowns()
        PopulateAppList(true)
        RefreshSelectedAppPanel()
        UpdateOverrideBanner()
        RefreshHotkeyIndicators()
    }
    RefreshAutoStartUi()
    RevertUnappliedGuiChanges()
    ClearAppSelection()                            ; the window always opens with no app selected
    SetTimer(RecheckHotkeyBoxes.Bind(true), -80)   ; another app may have taken a shortcut since last time
    if DllCall("IsWindowVisible", "Ptr", MainGui.Hwnd)
        MainGui.Show("w1148")
    else
        MainGui.Show(SavedMainWindowPos() "w1148")      ; last position, if its screen is still there
    SetTimer(RefreshTrackedStatusOnly, 1000)
}

HideMainGui(*) {
    SetTimer(RefreshTrackedStatusOnly, 0)
    if ActiveCaptureHwnd != 0
        StopHotkeyCapture(false)
    Suspend(false)
    RememberMainWindowPos()
    SaveSettings()
    SaveHotkeys()
    SaveState()
    MainGui.Hide()
}

; ------------------------------ ON-DEMAND APP DETECTION ---------------------
OnDetectClick(*) {
    if GetMonitorLayoutSignature() != BuiltMonSignature {
        RebuildMainGuiIfNeeded(true)
        Tip("Monitors and running applications updated")
        return
    }
    ScanAndRenderDetected()
    Tip("Running applications updated")
}

ScanAndRenderDetected() {
    global CachedCandidates
    CachedCandidates := CollectRunningApps()
    RenderDetectedList()
}

RenderDetectedList() {
    if !IsObject(DetectedLV)
        return
    q := Trim(EdtFilter.Value)
    showAll := (ChkShowAllProcs.Value = 1) || (q != "")

    selMap := Map()
    selMap.CaseSense := false
    r := 0
    while (r := DetectedLV.GetNext(r))
        selMap[DetectedLV.GetText(r, 1)] := true

    DetectedLV.Opt("-Redraw")
    DetectedLV.Delete()
    idx := 0
    for item in CachedCandidates {
        if Apps.Has(item.exe)
            continue
        if !showAll && item.rank >= 4
            continue
        if q != "" && !InStr(item.exe, q) && !InStr(item.info, q)
            continue
        idx++
        DetectedLV.Add("", item.exe, item.info)
        if selMap.Has(item.exe)
            DetectedLV.Modify(idx, "Select")
    }
    DetectedLV.Opt("+Redraw")
}

OnAddDetectedApps(*) {
    global SelectedApp
    added := []
    row := 0
    while (row := DetectedLV.GetNext(row)) {
        exe := DetectedLV.GetText(row, 1)
        if exe != ""
            added.Push(exe)
    }
    if !added.Length
        return

    for exeName in added {
        if !Apps.Has(exeName)
            Apps[exeName] := true
        SelectedApp := exeName
    }
    SaveConfig()
    RenderDetectedList()
    PopulateAppList(true)
    RefreshSelectedAppPanel()

    for exeName in added {
        RouteAppNow(exeName, true)
    }
}

CollectRunningApps() {
    sysProcs := Map()
    sysProcs.CaseSense := false
    sysProcs.Set(
        "System", 1, "Registry", 1, "smss.exe", 1, "csrss.exe", 1, "wininit.exe", 1,
        "services.exe", 1, "lsass.exe", 1, "winlogon.exe", 1, "fontdrvhost.exe", 1,
        "dwm.exe", 1, "svchost.exe", 1, "sihost.exe", 1, "taskhostw.exe", 1,
        "RuntimeBroker.exe", 1, "conhost.exe", 1, "ctfmon.exe", 1, "dllhost.exe", 1,
        "audiodg.exe", 1, "spoolsv.exe", 1, "SearchIndexer.exe", 1, "SearchHost.exe", 1,
        "StartMenuExperienceHost.exe", 1, "ShellExperienceHost.exe", 1, "TextInputHost.exe", 1,
        "LockApp.exe", 1, "SecurityHealthService.exe", 1, "SecurityHealthSystray.exe", 1,
        "SgrmBroker.exe", 1, "MsMpEng.exe", 1, "NisSrv.exe", 1, "WmiPrvSE.exe", 1,
        "unsecapp.exe", 1, "dasHost.exe", 1, "MoUsoCoreWorker.exe", 1, "explorer.exe", 1,
        "AutoHotkey64.exe", 1, "AutoHotkey32.exe", 1, "SoundVolumeView.exe", 1
    )

    snap := GetProcessSnapshot()
    pidToExe := snap.pidToExe

    found := Map()
    found.CaseSense := false
    list := []

    AddOrUpdate(exe, info, rank) {
        if exe = "" || sysProcs.Has(exe)
            return
        if !found.Has(exe) {
            item := {exe: exe, info: info, rank: rank}
            found[exe] := item
            list.Push(item)
        } else {
            cur := found[exe]
            if rank < cur.rank {
                cur.rank := rank
                cur.info := info
            } else if !InStr(cur.info, info) && StrLen(cur.info) < 90 {
                cur.info .= " | " info
            }
        }
    }

    for sess in GetCoreAudioSessions() {
        exe := pidToExe.Get(sess.pid, "")
        if exe = ""
            exe := GetProcessExeName(sess.pid)
        if exe = ""
            continue
        if sess.makingSound
            AddOrUpdate(exe, "[Making Sound]", 1)
        else
            AddOrUpdate(exe, "[Audio Session]", 2)
    }

    for hwnd in WinGetList() {
        try {
            title := WinGetTitle(hwnd)
            if title = ""
                continue
            pid := WinGetPID(hwnd)
            exe := pidToExe.Get(pid, "")
            if exe = ""
                exe := GetProcessExeName(pid)
            if exe = ""
                continue
            AddOrUpdate(exe, "[Window] " title, 3)
        }
    }

    for exe in snap.uniqueExes {
        AddOrUpdate(exe, "(Background / Tray)", 4)
    }

    if list.Length > 1 {
        keys := ""
        for entry in list
            keys .= entry.rank "|" entry.exe "`n"
        sorted := []
        for line in StrSplit(Sort(RTrim(keys, "`n"), "D`n"), "`n") {
            exeKey := SubStr(line, InStr(line, "|") + 1)
            if found.Has(exeKey)
                sorted.Push(found[exeKey])
        }
        list := sorted
    }
    return list
}

GetProcessSnapshot() {
    pidToExe := Map()
    uniqueExes := []
    seen := Map()
    seen.CaseSense := false

    hSnap := DllCall("CreateToolhelp32Snapshot", "UInt", 0x2, "UInt", 0, "Ptr")
    if !hSnap || hSnap = -1
        return {pidToExe: pidToExe, uniqueExes: uniqueExes}

    entrySize := (A_PtrSize = 8) ? 568 : 556
    nameOffset := (A_PtrSize = 8) ? 44 : 36
    pe := Buffer(entrySize, 0)
    NumPut("UInt", entrySize, pe, 0)

    if DllCall("Process32FirstW", "Ptr", hSnap, "Ptr", pe) {
        loop {
            pid := NumGet(pe, 8, "UInt")
            exe := StrGet(pe.Ptr + nameOffset, 260, "UTF-16")
            if pid > 4 && exe != "" && RegExMatch(exe, "i)\.exe$") {
                pidToExe[pid] := exe
                if !seen.Has(exe) {
                    seen[exe] := true
                    uniqueExes.Push(exe)
                }
            }
        } until !DllCall("Process32NextW", "Ptr", hSnap, "Ptr", pe)
    }
    DllCall("CloseHandle", "Ptr", hSnap)
    return {pidToExe: pidToExe, uniqueExes: uniqueExes}
}

GetCoreAudioSessions() {
    sessions := []
    try {
        enumerator := ComObject("{BCDE0395-E52F-467C-8E3D-C4579291692E}", "{A95664D2-9614-4F35-A746-DE8DB63617E6}")
        ComCall(3, enumerator, "Int", 0, "UInt", 1, "Ptr*", &pCollection := 0)
        if !pCollection
            return sessions

        ComCall(3, pCollection, "UInt*", &devCount := 0)
        guidMgr2 := Buffer(16)
        DllCall("ole32\CLSIDFromString", "WStr", "{77AA99A0-1BD6-484F-8BC7-2C654C9A9B6F}", "Ptr", guidMgr2)

        Loop devCount {
            ComCall(4, pCollection, "UInt", A_Index - 1, "Ptr*", &pDevice := 0)
            if !pDevice
                continue
            pMgr2 := 0
            try ComCall(3, pDevice, "Ptr", guidMgr2, "UInt", 23, "Ptr", 0, "Ptr*", &pMgr2)
            if pMgr2 {
                pSessEnum := 0
                try ComCall(5, pMgr2, "Ptr*", &pSessEnum)
                if pSessEnum {
                    ComCall(3, pSessEnum, "Int*", &sessCount := 0)
                    Loop sessCount {
                        pCtrl := 0
                        try ComCall(4, pSessEnum, "Int", A_Index - 1, "Ptr*", &pCtrl)
                        if !pCtrl
                            continue
                        try {
                            ComCall(3, pCtrl, "Int*", &state := 0)
                            ctrl2 := ComObjQuery(pCtrl, "{bfb7ff88-7239-4fc9-8fa2-07c950be9c6d}")
                            ComCall(14, ctrl2, "UInt*", &pid := 0)
                            isSys := ComCall(15, ctrl2)
                            peak := 0.0
                            try {
                                meter := ComObjQuery(pCtrl, "{C02216F6-8C67-4B5B-9D00-D008E73E0064}")
                                ComCall(3, meter, "Float*", &peak)
                                meter := ""
                            }
                            ctrl2 := ""
                            if pid > 4 && isSys != 0 && state != 2 {
                                sessions.Push({
                                    pid: pid,
                                    active: (state = 1),
                                    makingSound: (state = 1 && peak > 0.0001)
                                })
                            }
                        }
                        ObjRelease(pCtrl)
                    }
                    ObjRelease(pSessEnum)
                }
                ObjRelease(pMgr2)
            }
            ObjRelease(pDevice)
        }
        ObjRelease(pCollection)
        enumerator := ""
    }
    return sessions
}

GetSvvAudioSessions(pidToExe) {
    results := []
    if !FileExist(SVV)
        return results
    tmp := A_Temp "\ScreenAudioRouter_apps.csv"
    try FileDelete(tmp)
    cmd := Format('"{1}" /SaveFileEncoding 3 /scomma "{2}" /Columns "Name,Type,Item ID,Process ID,Process Path"', SVV, tmp)
    try RunWait(cmd, , "Hide")
    if !FileExist(tmp)
        return results
    text := FileRead(tmp, "UTF-8")
    try FileDelete(tmp)

    rows := []
    for line in StrSplit(text, "`n", "`r") {
        if Trim(line) != ""
            rows.Push(ParseCsvLine(line))
    }
    if rows.Length < 2
        return results
    rows[1][1] := LTrim(rows[1][1], Chr(0xFEFF))

    hdr := Map()
    hdr.CaseSense := false
    for i, name in rows[1]
        hdr[name] := i

    if !hdr.Has("Type")
        return results

    Loop rows.Length - 1 {
        r := rows[A_Index + 1]
        if Field(r, hdr, "Type") != "Application"
            continue
        exe := ""
        pidStr := Field(r, hdr, "Process ID")
        if IsInteger(pidStr) && Integer(pidStr) > 4
            exe := pidToExe.Get(Integer(pidStr), "")
        if exe = "" {
            pPath := Field(r, hdr, "Process Path")
            if pPath != ""
                SplitPath(pPath, &exe)
        }
        if exe = "" {
            nm := Field(r, hdr, "Name")
            if nm != ""
                exe := RegExMatch(nm, "i)\.exe$") ? nm : nm ".exe"
        }
        itemId := Field(r, hdr, "Item ID")
        if exe != "" || itemId != ""
            results.Push({exe: exe, itemId: itemId})
    }
    return results
}

GetProcessExeName(pid) {
    static cache := Map(), lastFlush := 0
    if !pid
        return ""
    now := A_TickCount
    if (now - lastFlush) > 15000 || cache.Count > 256 {
        cache.Clear()
        lastFlush := now
    }
    if cache.Has(pid)
        return cache[pid]
    hProc := DllCall("OpenProcess", "UInt", 0x1000, "Int", false, "UInt", pid, "Ptr")
    if !hProc
        return ""
    buf := Buffer(1040, 0)
    size := 520
    ok := DllCall("QueryFullProcessImageNameW", "Ptr", hProc, "UInt", 0, "Ptr", buf, "UInt*", &size)
    DllCall("CloseHandle", "Ptr", hProc)
    if !ok || size = 0
        return ""
    fullPath := StrGet(buf, size, "UTF-16")
    SplitPath(fullPath, &exeName)
    cache[pid] := exeName
    return exeName
}

; ------------------------------ GUI HANDLERS --------------------------------
PopulateMonitorDropdowns() {
    Loop MAX_MONITORS {
        mIdx := A_Index
        isConn := (mIdx <= DetectedMonCount)
        normId := MonitorRules.Get(mIdx, DEFAULT_DEVICE)
        isSubEnabled := isConn && !IsMonitorDisabled(mIdx)

        if MonEnableChecks.Has(mIdx) {
            SetCtrlValue(MonEnableChecks[mIdx], IsMonitorDisabled(mIdx) ? 0 : 1)
            SetCtrlEnabled(MonEnableChecks[mIdx], isConn)
        }

        if MonDropdowns.Has(mIdx) {
            ddl := MonDropdowns[mIdx]
            res := BuildDeviceDropdownItems(normId, "", "", false, "o")
            MonDropdownIds[mIdx] := res.ids
            SetDdlItems(ddl, res.labels, res.chosenIdx)
            SetCtrlEnabled(ddl, isSubEnabled)
        }

        if MonOvrLabels.Has(mIdx)
            SetCtrlColor(MonOvrLabels[mIdx], isSubEnabled ? Th("text") : Th("muted"))

        if MonOvrDropdowns.Has(mIdx) {
            ovrDdl := MonOvrDropdowns[mIdx]
            ovrTargetId := MonitorOverrideRules.Get(mIdx, DEFAULT_DEVICE)
            excludeId := (AvoidConflicts && normId != DEFAULT_DEVICE) ? normId : ""
            sameWarn := normId
            ovrRes := BuildDeviceDropdownItems(ovrTargetId, excludeId, sameWarn, false, "m")
            MonOvrDropdownIds[mIdx] := ovrRes.ids
            SetDdlItems(ovrDdl, ovrRes.labels, ovrRes.chosenIdx)
            SetCtrlEnabled(ovrDdl, isSubEnabled)
        }

        if MonOvrButtons.Has(mIdx) {
            isOvrOn := isSubEnabled && MonitorOverrideActive.Get(mIdx, false)
            SetCtrlText(MonOvrButtons[mIdx], isOvrOn ? "Ovrd : ON" : "Ovrd : OFF")
            SetCtrlEnabled(MonOvrButtons[mIdx], isSubEnabled)
            SetButtonColor(MonOvrButtons[mIdx], isOvrOn ? BtnColorMonOvrOn : BtnColorMonOvrOff)
        }

        if MonHkLabels.Has(mIdx)
            SetCtrlColor(MonHkLabels[mIdx], isSubEnabled ? Th("text2") : Th("muted"))

        if MonHkControls.Has(mIdx) {
            SetCtrlEnabled(MonHkControls[mIdx], isSubEnabled)
            SetHotkeyBoxValue(MonHkControls[mIdx], isConn ? MonHotkeys.Get(mIdx, "") : "", "normal")
        }
        if MonHkSetButtons.Has(mIdx)
            SetCtrlEnabled(MonHkSetButtons[mIdx], isSubEnabled)
        if MonHkClrButtons.Has(mIdx)
            SetCtrlEnabled(MonHkClrButtons[mIdx], isSubEnabled)
        if MonHkRstButtons.Has(mIdx)
            SetCtrlEnabled(MonHkRstButtons[mIdx], isSubEnabled)

        if MonMicChecks.Has(mIdx) {
            SetCtrlValue(MonMicChecks[mIdx], MonMicOn.Has(mIdx) ? 1 : 0)
            SetCtrlEnabled(MonMicChecks[mIdx], isSubEnabled)
        }
        if MonMicDropdowns.Has(mIdx) {
            res := BuildMicDropdownItems(MonitorOverrideRules.Get(mIdx, DEFAULT_DEVICE), MonMicDevice.Get(mIdx, ""))
            MonMicDropdownIds[mIdx] := res.ids
            SetDdlItems(MonMicDropdowns[mIdx], res.labels, res.chosenIdx)
            SetCtrlEnabled(MonMicDropdowns[mIdx], isSubEnabled && MonMicOn.Has(mIdx))
        }
    }
}

; Microphone list: "Paired : <microphone paired with pairDev>" (id ""), the Windows default,
; then every microphone. A chosen microphone that is not connected stays selectable.
BuildMicDropdownItems(pairDev, chosenId) {
    paired := PairedMicOf(pairDev)
    labels := ["Paired : " MicDisplayName(paired) (DevicePresent(paired) ? "" : "  (not connected)")]
    ids := [""]
    labels.Push("Windows default microphone"), ids.Push(DEFAULT_CAPTURE_DEVICE)
    for m in CachedMics {
        labels.Push(m.label)
        ids.Push(m.id)
    }
    chosen := 1
    if chosenId != "" {
        for i, id in ids {
            if i > 1 && (id = chosenId || (id != DEFAULT_CAPTURE_DEVICE && DevKey(id) = DevKey(chosenId))) {
                chosen := i
                break
            }
        }
        if chosen = 1 {
            labels.Push("[Disconnected] " DeviceWinName(chosenId))
            ids.Push(chosenId)
            chosen := ids.Length
        }
    }
    return {labels: labels, ids: ids, chosenIdx: chosen}
}

OnMonMicOnChanged(mIdx, ctrl, *) {
    if ctrl.Value
        MonMicOn[mIdx] := true
    else
        MapDel(MonMicOn, mIdx)
    SaveConfig()
    PopulateMonitorDropdowns()
    if MonitorOverrideActive.Get(mIdx, false)
        ReapplyAll(false, true)
    PopulateAppList(true)
    Tip("Monitor " mIdx " : " (ctrl.Value ? "its override also switches the microphone" : "its override changes only the sound"))
}

OnMonMicDeviceChanged(mIdx, ctrl, *) {
    idx := ctrl.Value
    ids := MonMicDropdownIds.Get(mIdx, [])
    if idx < 1 || idx > ids.Length
        return
    if ids[idx] = ""
        MapDel(MonMicDevice, mIdx)
    else
        MonMicDevice[mIdx] := ids[idx]
    SaveConfig()
    if MonitorOverrideActive.Get(mIdx, false) && MonMicOn.Has(mIdx)
        ReapplyAll(false, true)
    PopulateAppList(true)
}

; The Per-App microphone controls for the selected app.
RefreshAppMicControls() {
    global AppMicDdlIds
    if !IsObject(DdlAppMic)
        return
    app := SelectedApp
    if app = "" || !Apps.Has(app) {
        SetCtrlValue(ChkAppMicOn, 0)
        SetCtrlEnabled(ChkAppMicOn, false)
        res := BuildMicDropdownItems(DEFAULT_DEVICE, "")
    } else {
        SetCtrlEnabled(ChkAppMicOn, true)
        SetCtrlValue(ChkAppMicOn, AppMicOn.Has(app) ? 1 : 0)
        res := BuildMicDropdownItems(AppOverrideRules.Get(app, DEFAULT_DEVICE), AppMicDevice.Get(app, ""))
    }
    AppMicDdlIds := res.ids
    SetDdlItems(DdlAppMic, res.labels, res.chosenIdx)
    SetCtrlEnabled(DdlAppMic, app != "" && Apps.Has(app) && AppMicOn.Has(app))
}

OnAppMicOnChanged(*) {
    app := SelectedApp
    if app = "" || !Apps.Has(app)
        return
    if ChkAppMicOn.Value
        AppMicOn[app] := true
    else
        MapDel(AppMicOn, app)
    SaveConfig()
    RefreshAppMicControls()
    MapDel(LastRouted, app)
    RouteAppNow(app, true)
    PopulateAppList(true)
    Tip(app " : " (ChkAppMicOn.Value ? "its override also switches the microphone" : "its override changes only the sound"))
}

OnAppMicDeviceChanged(*) {
    app := SelectedApp
    idx := DdlAppMic.Value
    if app = "" || !Apps.Has(app) || idx < 1 || idx > AppMicDdlIds.Length
        return
    if AppMicDdlIds[idx] = ""
        MapDel(AppMicDevice, app)
    else
        AppMicDevice[app] := AppMicDdlIds[idx]
    SaveConfig()
    MapDel(LastRouted, app)
    RouteAppNow(app, true)
    PopulateAppList(true)
}

PopulateOverrideDeviceDropdowns() {
    global AllAppsDeviceIds, AllMonsDeviceIds
    if !IsObject(DdlAllAppsDevice)
        return

    allRes := BuildDeviceDropdownItems(AllDevice, "", "", false, "a")
    AllAppsDeviceIds := allRes.ids
    SetDdlItems(DdlAllAppsDevice, allRes.labels, allRes.chosenIdx)

    monsRes := BuildDeviceDropdownItems(AllMonitorsDevice, "", "", false, "m")
    AllMonsDeviceIds := monsRes.ids
    SetDdlItems(DdlAllMonsDevice, monsRes.labels, monsRes.chosenIdx)
}

RefreshSelectedAppPanel() {
    global AppOverrideDeviceIds, AppFixedDeviceIds
    if !IsObject(LblSelAppName)
        return

    if SelectedApp = "" || !Apps.Has(SelectedApp) {
        SetCtrlValue(LblSelAppName, "(None selected)")
        SetCtrlEnabled(DdlAppOverrideDevice, false)
        SetDdlItems(DdlAppOverrideDevice, ["Windows Default Device"], 1)
        SetCtrlEnabled(BtnToggleAppOvr, false)
        SetCtrlText(BtnToggleAppOvr, "Override : OFF")
        SetButtonColor(BtnToggleAppOvr, BtnColorAppOvrOff)
        SetCtrlEnabled(BtnResetAppOvr, false)
        SetCtrlEnabled(HkCtrlApp, false)
        SetHotkeyBoxValue(HkCtrlApp, "", "normal")
        SetCtrlEnabled(BtnSetAppHk, false)
        SetCtrlEnabled(BtnClrAppHk, false)
        SetCtrlEnabled(BtnRstAppHk, false)
        SetDdlItems(DdlAppFollowFocus, AppFollowFocusLabels(), 1)
        SetCtrlEnabled(DdlAppFollowFocus, false)
        SetCtrlValue(ChkAppFollowMon, 1)
        SetCtrlEnabled(ChkAppFollowMon, false)
        SetDdlItems(DdlAppFixedDevice, ["Windows Default Device"], 1)
        SetCtrlEnabled(DdlAppFixedDevice, false)
        SetCtrlValue(ChkAppSystemMic, 0)
        SetCtrlEnabled(ChkAppSystemMic, false)
        SetCtrlValue(ChkAppHideTray, 0)
        SetCtrlEnabled(ChkAppHideTray, false)
        RefreshAppMicControls()
        return
    }

    app := SelectedApp
    SetCtrlValue(LblSelAppName, app)
    SetCtrlEnabled(DdlAppOverrideDevice, true)
    SetCtrlEnabled(BtnToggleAppOvr, Apps.Get(app, false))
    SetCtrlEnabled(BtnResetAppOvr, true)
    SetCtrlEnabled(HkCtrlApp, true)
    SetCtrlEnabled(BtnSetAppHk, true)
    SetCtrlEnabled(BtnClrAppHk, true)
    SetCtrlEnabled(BtnRstAppHk, true)
    SetCtrlEnabled(DdlAppFollowFocus, true)
    SetDdlItems(DdlAppFollowFocus, AppFollowFocusLabels(), !AppFollowFocus.Has(app) ? 1 : AppFollowFocus[app] ? 2 : 3)

    targetId := AppOverrideRules.Get(app, DEFAULT_DEVICE)
    res := BuildDeviceDropdownItems(targetId, "", "", false, "a")
    AppOverrideDeviceIds := res.ids
    SetDdlItems(DdlAppOverrideDevice, res.labels, res.chosenIdx)

    isOvrOn := AppOverrideActive.Get(app, false)
    SetCtrlText(BtnToggleAppOvr, isOvrOn ? "Override : ON" : "Override : OFF")
    SetButtonColor(BtnToggleAppOvr, isOvrOn ? BtnColorAppOvrOn : BtnColorAppOvrOff)

    hk := AppHotkeys.Get(app, "")
    SetHotkeyBoxValue(HkCtrlApp, hk, "normal")

    fixed := AppFixedDevice.Has(app)
    SetCtrlEnabled(ChkAppFollowMon, true)
    SetCtrlValue(ChkAppFollowMon, fixed ? 0 : 1)
    fRes := BuildDeviceDropdownItems(AppFixedDevice.Get(app, DEFAULT_DEVICE), "", "", false, "o")
    AppFixedDeviceIds := fRes.ids
    SetDdlItems(DdlAppFixedDevice, fRes.labels, fRes.chosenIdx)
    SetCtrlEnabled(DdlAppFixedDevice, fixed)
    SetCtrlEnabled(ChkAppSystemMic, true)
    SetCtrlValue(ChkAppSystemMic, AppSystemMic.Get(app, false) ? 1 : 0)
    SetCtrlEnabled(ChkAppHideTray, true)
    SetCtrlValue(ChkAppHideTray, AppHideTrayIcon.Has(app) ? 1 : 0)
    RefreshAppMicControls()
    UpdateQuickActionButtons()
}

OnAppHideTrayChanged(*) {
    app := SelectedApp
    if app = "" || !Apps.Has(app)
        return
    if ChkAppHideTray.Value
        AppHideTrayIcon[app] := true
    else
        MapDel(AppHideTrayIcon, app)
    SaveConfig()
    UpdateTrayIndicators()
    Tip(app " : " (ChkAppHideTray.Value ? "no tray icon while its override is on" : "tray icon while its override is on"))
}

OnAppSystemMicChanged(*) {
    app := SelectedApp
    if app = "" || !Apps.Has(app)
        return
    if ChkAppSystemMic.Value {
        AppSystemMic[app] := true
        Tip(app " : its microphone also becomes the Windows default"
            . (MicRoutingActive() ? "" : "`n(pair microphones with devices in the Devices window, or use Override Mic)"))
    } else {
        MapDel(AppSystemMic, app)
        Tip(app " : Windows default microphone left alone")
    }
    SaveConfig()
    MapDel(LastRouted, app)
    RouteAppNow(app, true)
}

; "Follow monitor" unticked: the app keeps the device it plays on now (its monitor's
; output), which can then be changed in the dropdown.
OnAppFollowMonitorChanged(*) {
    app := SelectedApp
    if app = "" || !Apps.Has(app)
        return
    if ChkAppFollowMon.Value {
        MapDel(AppFixedDevice, app)
        Tip(app " : follows its monitor")
    } else {
        AppFixedDevice[app] := GetActiveMonitorDevice(LastSeen.Get(app, 0))
        Tip(app " : stays on " ShortDeviceName(AppFixedDevice[app]) " wherever its window is")
    }
    SaveConfig()
    MapDel(LastRouted, app)
    RouteAppNow(app, true)
    RefreshSelectedAppPanel()
    PopulateAppList(true)
}

OnAppFixedDeviceChanged(*) {
    app := SelectedApp
    idx := DdlAppFixedDevice.Value
    if app = "" || !Apps.Has(app) || !idx || idx > AppFixedDeviceIds.Length
        return
    AppFixedDevice[app] := AppFixedDeviceIds[idx]
    SaveConfig()
    RouteAppNow(app, true)
    PopulateAppList(true)
}

BuildDeviceDropdownItems(targetId, excludeId := "", sameWarnId := "", includeDisabled := false, listKind := "") {
    labels := []
    ids := []
    chosenIdx := 0

    if includeDisabled {
        labels.Push("Disabled")
        ids.Push(DISABLED_MONITOR)
        if targetId = DISABLED_MONITOR
            chosenIdx := ids.Length
    }

    if excludeId != DEFAULT_DEVICE {
        defLabel := (sameWarnId = DEFAULT_DEVICE) ? "Windows Default Device  (Same as Output)" : "Windows Default Device"
        labels.Push(defLabel)
        ids.Push(DEFAULT_DEVICE)
        if targetId = DEFAULT_DEVICE
            chosenIdx := ids.Length
    }

    for d in CachedDevices {
        if excludeId != "" && d.id = excludeId
            continue
        if DeviceHidden(d.id, listKind) && DevKey(d.id) != DevKey(targetId)   ; hidden, unless it is the current choice
            continue
        lbl := (sameWarnId != "" && d.id = sameWarnId) ? d.label "  [Same as Output!]" : d.label
        labels.Push(lbl)
        ids.Push(d.id)
        if d.id = targetId
            chosenIdx := ids.Length
    }

    if targetId != "" && chosenIdx = 0 {                ; same device under a renumbered id
        n := MultiDevNames.Has(NormDevId(targetId)) ? "" : NormDevId(targetId)
        for i, id in ids {
            if n != "" && id != DEFAULT_DEVICE && id != DISABLED_MONITOR && NormDevId(id) = n {
                chosenIdx := i
                break
            }
        }
    }

    if targetId != "" && chosenIdx = 0 && targetId != excludeId {
        labels.Push("[Disconnected] " ShortDeviceName(targetId))
        ids.Push(targetId)
        chosenIdx := ids.Length
    }

    if chosenIdx = 0
        chosenIdx := 1

    return {labels: labels, ids: ids, chosenIdx: chosenIdx}
}

OnGlobalRuleChanged(mIdx, ctrl, *) {
    if mIdx > DetectedMonCount
        return
    idx := ctrl.Value
    ids := MonDropdownIds[mIdx]
    if idx < 1 || idx > ids.Length
        return

    chosenId := ids[idx]
    if chosenId = DEFAULT_DEVICE
        MapDel(MonitorRules, mIdx)
    else
        MonitorRules[mIdx] := chosenId

    if AvoidConflicts
        SanitizeConfigConflicts(false)

    SaveConfig()
    SaveState()
    PopulateMonitorDropdowns()
    SetupTrayMenu()
    ReapplyAll(false, false)
    UpdateOverrideBanner()
}

; "Enabled" ticked / unticked. Off: the monitor's override ends and its hotkey is switched off;
; its Output, Ovrd and Mic settings stay for when it is ticked again.
OnMonitorEnabledChanged(mIdx, ctrl, *) {
    if mIdx > DetectedMonCount
        return
    if ctrl.Value {
        MapDel(MonitorOff, mIdx)
        if !RegMonHotkeys.Has(mIdx) && MonHotkeys.Get(mIdx, "") != ""
            RegisterMonitorHotkey(mIdx, MonHotkeys[mIdx], true)
    } else {
        MonitorOff[mIdx] := true
        MonitorOverrideActive[mIdx] := false
        if RegMonHotkeys.Has(mIdx) {
            try Hotkey(RegMonHotkeys[mIdx], "Off")
            MapDel(RegMonHotkeys, mIdx)
        }
    }
    SaveConfig()
    SaveState()
    PopulateMonitorDropdowns()
    SetupTrayMenu()
    ReapplyAll(false, true)
    UpdateOverrideBanner()
    Tip("Monitor " mIdx " : " (ctrl.Value ? "enabled" : "disabled (Windows default device)"))
}

OnMonitorOverrideDeviceChanged(mIdx, ctrl, *) {
    if mIdx > DetectedMonCount
        return
    idx := ctrl.Value
    ids := MonOvrDropdownIds[mIdx]
    if idx < 1 || idx > ids.Length
        return

    chosenId := ids[idx]
    if chosenId = DEFAULT_DEVICE {
        MapDel(MonitorOverrideRules, mIdx)
    } else {
        MonitorOverrideRules[mIdx] := chosenId
    }

    if AvoidConflicts
        SanitizeConfigConflicts(false)

    SaveConfig()
    PopulateMonitorDropdowns()
    SetupTrayMenu()
    if MonitorOverrideActive.Get(mIdx, false)
        ReapplyAll(false, false)
    UpdateOverrideBanner()
}

OnSelectedAppOverrideDeviceChanged(ctrl, *) {
    if SelectedApp = "" || !Apps.Has(SelectedApp)
        return
    idx := ctrl.Value
    if idx < 1 || idx > AppOverrideDeviceIds.Length
        return

    chosenId := AppOverrideDeviceIds[idx]
    MapDel(AppTempOverride, SelectedApp)
    if chosenId = DEFAULT_DEVICE
        MapDel(AppOverrideRules, SelectedApp)
    else
        AppOverrideRules[SelectedApp] := chosenId
    RefreshAppMicControls()                       ; "Paired :" follows the override device

    if AvoidConflicts
        SanitizeConfigConflicts(false)

    SaveConfig()
    SetupTrayMenu()
    if AppOverrideActive.Get(SelectedApp, false) {
        RouteAppNow(SelectedApp, true)
        mon := LastSeen.Get(SelectedApp, 1)
        ShowOsdToast(Format("{1} plays on {2}", FormatAppDisplayName(SelectedApp), ShortDeviceName(chosenId)), mon)
    }
    PopulateAppList(true)
    RefreshSelectedAppPanel()
    UpdateOverrideBanner()
}

OnToggleSelectedAppOverride(*) {
    if SelectedApp = "" || !Apps.Has(SelectedApp)
        return
    ToggleAppOverrideByName(SelectedApp)
}

OnResetSelectedAppOverride(*) {
    if SelectedApp = "" || !Apps.Has(SelectedApp)
        return
    app := SelectedApp
    hadOvr := AppOverrideActive.Get(app, false) || AppOverrideRules.Has(app) || AppMicOn.Has(app) || AppMicDevice.Has(app)

    ; this app's override back to its defaults: off, Override Output = Windows Default, Override Mic off
    MapDel(AppOverrideActive, app)
    MapDel(AppOverrideRules, app)
    MapDel(AppTempOverride, app)
    MapDel(AppMicOn, app)
    MapDel(AppMicDevice, app)
    if AllMode
        MapDel(Released, app)

    SaveConfig()
    SaveState()
    SetupTrayMenu()
    RouteAppNow(app, true)
    PopulateAppList(true)
    RefreshSelectedAppPanel()
    UpdateOverrideBanner()

    if hadOvr {
        mon := LastSeen.Get(app, 1)
        effDev := GetEffectiveDeviceForApp(app, mon)
        ShowOsdToast(Format("{1} plays on {2}", FormatAppDisplayName(app), ShortDeviceName(effDev)), mon)
    } else {
        Tip(app " : no active override to reset")
    }
}

OnAllAppsOverrideDeviceChanged(ctrl, *) {
    global AllDevice
    idx := ctrl.Value
    if idx < 1 || idx > AllAppsDeviceIds.Length
        return

    AllDevice := AllAppsDeviceIds[idx]
    SaveState()
    SetupTrayMenu()

    if AllMode {
        for app, enabled in Apps {
            if enabled && !Released.Has(app)
                RouteAppNow(app, true)
        }
        ShowOsdToast(Format("All Apps play on {1}", ShortDeviceName(AllDevice)), 1)
    }
    PopulateAppList(true)
    UpdateOverrideBanner()
}

OnAllMonsOverrideDeviceChanged(ctrl, *) {
    global AllMonitorsDevice
    idx := ctrl.Value
    if idx < 1 || idx > AllMonsDeviceIds.Length
        return

    AllMonitorsDevice := AllMonsDeviceIds[idx]
    SaveState()
    SetupTrayMenu()

    if AllMonitorsMode {
        ReapplyAll(false, false)
        ShowOsdToast(Format("All Monitors play on {1}", ShortDeviceName(AllMonitorsDevice)), 1)
    }
    PopulateAppList(true)
    UpdateOverrideBanner()
}

OnRoutingDisableOptionChanged(*) {
    global DisableAllRouting, DisableMonitorRouting, DisableAppRouting
    DisableAllRouting     := (ChkDisableAll.Value = 1)
    DisableMonitorRouting := (ChkDisableMon.Value = 1)
    DisableAppRouting     := (ChkDisableApp.Value = 1)

    ChkDisableMon.Enabled := !DisableAllRouting
    ChkDisableApp.Enabled := !DisableAllRouting
    if IsObject(BtnToggleRouting) {
        BtnToggleRouting.Text := DisableAllRouting ? "Routing : OFF" : "Routing : ON"
        SetButtonColor(BtnToggleRouting, DisableAllRouting ? BtnColorRoutingOff : BtnColorRoutingOn)
    }

    SaveSettings()
    UpdateRoutingModeLabel()
    SetupTrayMenu()

    if DisableAllRouting
        ResetTrackedAppsToDefault()

    if AvoidConflicts {
        ResolveAllConflicts()
    } else {
        LastRouted.Clear()
        ReapplyAll(false, false)
        UpdateOverrideBanner()
    }
}

; An override being on is a normal state, not a warning: its own color (statusOvr), or the text color.
StatusOvrColor() {
    return Th("statusOvr") != "" ? Th("statusOvr") : Th("text")
}

UpdateRoutingModeLabel() {
    if !IsObject(LblRoutingModeNote)
        return
    if DisableAllRouting {
        SetCtrlColor(LblRoutingModeNote, Th("err"))
        SetCtrlValue(LblRoutingModeNote, "⏸ Routing is DEACTIVATED (Click Routing : OFF or Tray/Title Menu to activate)")
    } else if DisableMonitorRouting && DisableAppRouting {
        SetCtrlColor(LblRoutingModeNote, Th("err"))
        SetCtrlValue(LblRoutingModeNote, "⏸ Both Monitor & App Routing are DISABLED")
    } else if DisableMonitorRouting {
        SetCtrlColor(LblRoutingModeNote, Th("warn"))
        SetCtrlValue(LblRoutingModeNote, "⚠ Monitor Routing DISABLED — Only Per-App / All-Apps Overrides active")
    } else if DisableAppRouting {
        SetCtrlColor(LblRoutingModeNote, Th("warn"))
        SetCtrlValue(LblRoutingModeNote, "⚠ App Routing DISABLED — Only Screen Outputs & Monitor Overrides active")
    } else {
        SetCtrlColor(LblRoutingModeNote, Th("ok"))
        SetCtrlValue(LblRoutingModeNote, "● Active : Screen Outputs + Monitor Overrides + Per-App Routing enabled")
    }
}

OnToggleAvoidConflicts(*) {
    global AvoidConflicts
    AvoidConflicts := (ChkAvoidConflicts.Value = 1)
    SaveSettings()
    if AvoidConflicts {
        ResolveAllConflicts()
    } else {
        PopulateMonitorDropdowns()
        UpdateOverrideBanner()
        Tip("Contradiction guard disabled (manual mode)")
    }
}

PopulateAppList(force := false) {
    global SelectedApp, LastTrackedSnapshot, IsPopulatingTracked, LastTrackedRows
    if !IsObject(AppLV)
        return false

    snapshot := ""
    sortedApps := GetSortedApps()

    rowsData := []
    for app in sortedApps {
        enabled := Apps[app]
        running := AppRunning(app)
        mon := running ? LastSeen.Get(app, 0) : 0
        monStr := mon ? String(mon) : "-"

        ; Status: why the app plays where it does (the first rule that applies, as in GetRoutingTarget)
        appLevel := false
        if DisableAllRouting {
            status := "⏸ Routing off"
        } else if !enabled {
            status := "⏸ Disabled"
        } else if !DisableAppRouting && AppOverrideActive.Get(app, false) {
            status := AppTempOverride.Has(app) ? "⏱ Temp override" : "⭐ App override", appLevel := true
        } else if !DisableAppRouting && AllMode && !Released.Has(app) {
            status := "🔥 All-Apps", appLevel := true
        } else if !DisableAppRouting && AppFixedDevice.Has(app) {
            status := "📌 Fixed", appLevel := true
        } else if !running {
            status := "💤 Not running"
        } else if mon && mon <= DetectedMonCount && IsMonitorDisabled(mon) {
            status := "⏸ Mon disabled"
        } else if !DisableMonitorRouting && mon && AllMonitorsMode {
            status := "🌐 All-Mons"
        } else if !DisableMonitorRouting && mon && mon <= DetectedMonCount && MonitorOverrideActive.Get(mon, false) {
            status := "⚡ Mon override"
        } else if !DisableMonitorRouting && mon && mon <= DetectedMonCount && MonitorRules.Has(mon) {
            status := "🟢 Monitor"
        } else {
            status := "⚪ Default"
        }

        ; Output / Input: what it actually gets (a missing device shows its fallback)
        outTxt := "–", inTxt := "–", tipOut := "", tipIn := ""
        if enabled && !DisableAllRouting && (running || appLevel) {
            tgt := GetRoutingTarget(app, mon)
            outTxt := ShortDeviceName(tgt.dev), tipOut := outTxt
            if tgt.missing != ""
                outTxt := "⚠ " outTxt, tipOut .= "   (" ShortDeviceName(tgt.missing) " is not connected)"
            if running && MicRoutingActive() {
                micT := MicForApp(app, mon)
                inTxt := MicDisplayName(micT.mic), tipIn := inTxt
                if micT.missing != ""
                    inTxt := "⚠ " inTxt, tipIn .= "   (" ShortDeviceName(micT.missing) " is not connected)"
            }
        }
        ; tooltip: the reason in full words, with the monitor number
        why := RegExReplace(status, "^\S+\s+")
        switch why {
            case "Monitor":      why := "Monitor " mon " output"
            case "Mon override": why := "Monitor " mon " override"
            case "Mon disabled": why := "Monitor " mon " is disabled"
            case "All-Mons":     why := "All-Monitors override (on Monitor " mon ")"
            case "Default":      why := mon ? "Windows default (Monitor " mon " has no output set)" : "Windows default"
            default:
                if appLevel && running && mon
                    why .= " (on Monitor " mon ")"
        }
        rowTip := app "  —  " why
            . (tipOut != "" ? "`nOutput : " tipOut : "") . (tipIn != "" ? "`nInput : " tipIn : "")
        ; heard on another device than its rules say, and re-routing did not help (SessionWatchTick)
        if SessionStuck.Has(app "|0") {
            outTxt := (SubStr(outTxt, 1, 2) = "⚠ " ? "" : "⚠ ") outTxt
            rowTip .= "`n⚠ Plays on " EndpointName(SessionStuck[app "|0"], 0) " : the app picks that device itself."
                . "`n   Set its output device to Default in its own settings."
        }
        if SessionStuck.Has(app "|1") {
            inTxt := (SubStr(inTxt, 1, 2) = "⚠ " ? "" : "⚠ ") inTxt
            rowTip .= "`n⚠ Records from " EndpointName(SessionStuck[app "|1"], 1) " : the app picks that microphone itself."
                . "`n   Set its input device to Default in its own settings."
        }
        ; the monitor number goes into the monitor statuses ("Monitor 2", "Mon 2 override")
        if mon {
            switch status {
                case "🟢 Monitor":      status := "🟢 Monitor " mon
                case "⚡ Mon override": status := "⚡ Mon " mon " override"
                case "⏸ Mon disabled": status := "⏸ Mon " mon " disabled"
                case "🌐 All-Mons":     status := "🌐 All-Mons (" mon ")"
            }
        }

        ; app override on: the row gets the color of the Override : ON button
        ovrOn := !DisableAllRouting && enabled && !DisableAppRouting && AppOverrideActive.Get(app, false)
        ovrColor := ovrOn ? NormalizeHexColor(BtnColorAppOvrOn) : ""
        rowsData.Push({app: app, enabled: enabled, mon: monStr, status: status, out: outTxt, inp: inTxt, rowTip: rowTip, color: ovrColor})
        snapshot .= app "|" (enabled ? "1" : "0") "|" monStr "|" status "|" outTxt "|" inTxt "|" ovrColor "`n"
    }

    if !force && snapshot = LastTrackedSnapshot
        return false
    LastTrackedSnapshot := snapshot

    ; Same apps in the same order (the usual case after a button): only the cells and row
    ; colors that changed are updated, so the table does not flicker.
    sameApps := AppLV.GetCount() = rowsData.Length && LastTrackedRows.Length = rowsData.Length
    if sameApps {
        for idx, item in rowsData {
            if LastTrackedRows[idx].app != item.app {
                sameApps := false
                break
            }
        }
    }
    if sameApps {
        IsPopulatingTracked := true
        rowColors := Map(), rowTips := Map()
        for idx, item in rowsData {
            if item.color != ""
                rowColors[idx - 1] := item.color
            rowTips[idx - 1] := item.rowTip
        }
        LvRowColors[AppLV.Hwnd] := rowColors
        ListRowTips[AppLV.Hwnd] := rowTips
        for idx, item in rowsData {
            old := LastTrackedRows[idx]
            if old.enabled != item.enabled
                AppLV.Modify(idx, item.enabled ? "Check" : "-Check")
            if old.status != item.status || old.out != item.out || old.inp != item.inp
                AppLV.Modify(idx, "", item.app, item.status, item.out, item.inp)
            else if old.color != item.color
                SendMessage(0x1015, idx - 1, idx - 1, AppLV)       ; LVM_REDRAWITEMS: just the new color
        }
        LastTrackedRows := rowsData
        IsPopulatingTracked := false
        SetCtrlEnabled(BtnRemoveApp, SelectedApp != "" && Apps.Has(SelectedApp))
        UpdateQuickActionButtons()
        return true
    }

    IsPopulatingTracked := true
    prevSel := SelectedApp

    AppLV.Opt("-Redraw")
    AppLV.Delete()

    rowColors := Map(), rowTips := Map()
    selRow := 0
    for idx, item in rowsData {
        if item.color != ""
            rowColors[idx - 1] := item.color
        rowTips[idx - 1] := item.rowTip
        AppLV.Add(item.enabled ? "Check" : "-Check", item.app, item.status, item.out, item.inp)
        if item.app = prevSel
            selRow := idx
    }

    ; (no automatic selection: an app is selected only when you click it)

    if selRow {
        AppLV.Modify(selRow, "Select Focus Vis")
        SelectedApp := rowsData[selRow].app
    } else {
        SelectedApp := ""
    }

    LvRowColors[AppLV.Hwnd] := rowColors
    ListRowTips[AppLV.Hwnd] := rowTips
    LastTrackedRows := rowsData
    AppLV.Opt("+Redraw")
    IsPopulatingTracked := false

    SetCtrlEnabled(BtnRemoveApp, SelectedApp != "" && Apps.Has(SelectedApp))
    UpdateQuickActionButtons()
    return true
}

GetSortedApps() {
    if !Apps.Count
        return []
    names := ""
    for app in Apps
        names .= app "`n"
    return StrSplit(Sort(RTrim(names, "`n"), "D`n"), "`n")
}

RefreshTrackedStatusOnly() {
    if IsRebuildingGui
        return
    UpdateApplyButton()
    if ActiveCaptureHwnd != 0 {
        try {
            if !IsObject(MainGui) || !WinActive("ahk_id " MainGui.Hwnd) || !IsObject(MainGui.FocusedCtrl) || MainGui.FocusedCtrl.Hwnd != ActiveCaptureHwnd
                StopHotkeyCapture(false)
        } catch {
            StopHotkeyCapture(false)
        }
    } else if A_IsSuspended {
        Suspend(false)
    }
    try {
        if IsObject(MainGui) && WinExist("ahk_id " MainGui.Hwnd) && DllCall("IsWindowVisible", "Ptr", MainGui.Hwnd) {
            if PopulateAppList(false)
                UpdateOverrideBanner()
        }
    }
}

; No app selected: the table has no selected row and the selected-app rows are empty.
ClearAppSelection() {
    global SelectedApp, IsPopulatingTracked
    if !IsObject(AppLV)
        return
    IsPopulatingTracked := true                    ; no selection events while clearing
    AppLV.Modify(0, "-Select -Focus")
    IsPopulatingTracked := false
    if SelectedApp = ""
        return
    SelectedApp := ""
    SetCtrlEnabled(BtnRemoveApp, false)
    RefreshSelectedAppPanel()
    UpdateQuickActionButtons()
}

; A click fires "deselect old row", "select new row" and "click": only a newly selected,
; different app updates the panel, once.
OnAppSelect(ctrl, item, selected) {
    if IsPopulatingTracked || IsRebuildingGui || !item || !selected
        return
    app := AppLV.GetText(item, 1)
    if app != SelectedApp
        ShowSelectedApp(app)
}

OnAppClick(ctrl, row) {
    if IsRebuildingGui || !row
        return
    app := AppLV.GetText(row, 1)
    if app != SelectedApp
        ShowSelectedApp(app)
}

; Fills the selected-app rows for another app. The refresh functions change only what
; differs, so nothing else repaints (no window-wide freeze: the table must repaint its
; old and new selected row right away).
ShowSelectedApp(app) {
    global SelectedApp
    SelectedApp := app
    SetCtrlEnabled(BtnRemoveApp, SelectedApp != "" && Apps.Has(SelectedApp))
    RefreshSelectedAppPanel()
    UpdateQuickActionButtons()
}

OnAppCheck(ctrl, item, checked) {
    if IsPopulatingTracked || IsRebuildingGui || item < 1
        return
    app := AppLV.GetText(item, 1)
    if app = "" || !Apps.Has(app)
        return

    isEnabled := (checked = 1)
    if Apps[app] = isEnabled
        return

    Apps[app] := isEnabled
    SaveConfig()

    if isEnabled {
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
        Tip(app " : routing disabled (Windows Default)")
    }
    PopulateAppList(true)
    RefreshSelectedAppPanel()
}

OnRefreshDevices(*) {
    global CachedDevices, DevicesStale
    if GetMonitorLayoutSignature() != BuiltMonSignature {
        RebuildMainGuiIfNeeded(true)
        Tip("Monitors and audio devices refreshed (" CachedDevices.Length " active)")
        return
    }
    CachedDevices := GetDevices()
    DevicesStale := false
    if AvoidConflicts
        SanitizeConfigConflicts(true)
    PopulateMonitorDropdowns()
    PopulateOverrideDeviceDropdowns()
    RefreshSelectedAppPanel()
    SetupTrayMenu()
    PopulateAppList(true)
    UpdateOverrideBanner()
    Tip("Audio devices refreshed (" CachedDevices.Length " active)")
}

RemoveAppByName(app) {
    global SelectedApp
    if app = "" || !Apps.Has(app)
        return
    if RegAppHotkeys.Has(app) {
        try Hotkey(RegAppHotkeys[app], "Off")
        MapDel(RegAppHotkeys, app)
    }
    MapDel(AppHotkeys, app)
    SetDevice(app, DEFAULT_DEVICE)        ; while it is still tracked, so its process is found
    MapDel(Apps, app)
    MapDel(AppOverrideRules, app)
    MapDel(AppOverrideActive, app)
    MapDel(AppFixedDevice, app)
    MapDel(AppSystemMic, app)
    MapDel(AppMicOn, app)
    MapDel(AppMicDevice, app)
    MapDel(AppHideTrayIcon, app)
    MapDel(Released, app)
    MapDel(LastRouted, app)
    MapDel(LastSeen, app)
    MapDel(AppFollowFocus, app)
    MapDel(AnchorHwnd, app)
    MapDel(AnchorPending, app)

    if SelectedApp = app
        SelectedApp := ""

    SaveConfig()
    SaveHotkeys()
    SaveState()
    SetupTrayMenu()
    RenderDetectedList()
    PopulateAppList(true)
    RefreshSelectedAppPanel()
    UpdateOverrideBanner()
    Tip(app " : removed from Screen Audio Router")
}

OnRemoveApp(*) {
    if SelectedApp = "" || !Apps.Has(SelectedApp)
        return
    RemoveAppByName(SelectedApp)
}

OnSettingChanged(*) {
    global StartMinimized, EnableTitleBarMenu, EnableAllAppsTitleBarMenu
    StartMinimized            := (ChkStartMin.Value = 1)
    EnableTitleBarMenu        := (ChkTitleBarMenu.Value = 1)
    EnableAllAppsTitleBarMenu := (ChkAllTitleBarMenu.Value = 1)
    ApplyTitleBarHotkey()
    SaveSettings()
}

OnTitleBarKeyChanged(*) {
    global TitleBarMenuKey
    idx := DdlTitleBarKey.Value
    if idx < 1 || idx > TitleBarKeyChoices.Length
        return
    TitleBarMenuKey := TitleBarKeyChoices[idx][2]
    ApplyTitleBarHotkey()
    SaveSettings()
    Tip("Title-bar menu : " TitleBarKeyChoices[idx][1])
}

OnFollowFocusChanged(*) {
    global FollowFocusGlobal, ScanStamp
    FollowFocusGlobal := (ChkFollowFocus.Value = 1)
    AnchorHwnd.Clear()                    ; every app starts fresh under the new rule
    AnchorPending.Clear()
    ScanStamp := 0
    SaveSettings()
    ReapplyAll(false, false)
    RefreshSelectedAppPanel()             ; the Per-App "Global (On/Off)" entry shows the new value
}

AppFollowFocusLabels() {
    return ["Global  (" (FollowFocusGlobal ? "On" : "Off") ")", "On", "Off"]
}

OnAppFollowFocusChanged(*) {
    global ScanStamp
    app := SelectedApp
    if app = "" || !Apps.Has(app)
        return
    idx := DdlAppFollowFocus.Value                ; 1 Global, 2 On, 3 Off
    if idx <= 1
        MapDel(AppFollowFocus, app)
    else
        AppFollowFocus[app] := (idx = 2) ? 1 : 0
    MapDel(AnchorHwnd, app)
    MapDel(AnchorPending, app)
    ScanStamp := 0
    SaveConfig()
    RouteAppNow(app)
    PopulateAppList(false)
}

; Override on for at least one detected monitor that is not set to Disabled.
AnyEffectiveMonitorOverride() {
    Loop DetectedMonCount {
        if MonitorOverrideActive.Get(A_Index, false) && !IsMonitorDisabled(A_Index)
            return true
    }
    return false
}

; Override on for at least one enabled tracked app.
AnyAppOverrideActive() {
    for app, on in AppOverrideActive {
        if on && Apps.Get(app, false)
            return true
    }
    return false
}

AnyMonitorOverrideActive() {
    Loop DetectedMonCount {
        if MonitorOverrideActive.Get(A_Index, false)
            return true
    }
    return false
}


UpdateOverrideBanner() {
    if !IsObject(DdlAllAppsDevice)
        return
    activeMons := []
    Loop DetectedMonCount {
        if MonitorOverrideActive.Get(A_Index, false)
            activeMons.Push("Mon " A_Index)
    }

    activeAppCount := 0
    activeAppNames := []
    for app, isOvrOn in AppOverrideActive {
        if isOvrOn && Apps.Get(app, false) {
            activeAppCount++
            activeAppNames.Push(app)
        }
    }

    totalActive := activeMons.Length + activeAppCount + (AllMode ? 1 : 0) + (AllMonitorsMode ? 1 : 0)

    if IsObject(LblStatusBar) {
        if DisableAllRouting {
            SetCtrlColor(LblStatusBar, Th("err"))
            SetCtrlValue(LblStatusBar, "Status : ROUTING DEACTIVATED (Apps use Windows Default)")
        } else if AllMode {
            SetCtrlColor(LblStatusBar, StatusOvrColor())
            SetCtrlValue(LblStatusBar, "Status : ALL-APPS OVERRIDE ON -> " ShortDeviceName(AllDevice))
        } else if AllMonitorsMode || activeMons.Length > 0 || activeAppCount > 0 {
            parts := []
            if AllMonitorsMode
                parts.Push("ALL-MONITORS Override ON -> " ShortDeviceName(AllMonitorsDevice))
            if activeMons.Length > 0
                parts.Push(JoinStrings(activeMons, ", ") " Override ON")
            if activeAppCount > 0
                parts.Push("App Override ON (" JoinStrings(activeAppNames, ", ") ")")
            SetCtrlColor(LblStatusBar, StatusOvrColor())
            SetCtrlValue(LblStatusBar, "Status : " JoinStrings(parts, "  |  "))
        } else {
            SetCtrlColor(LblStatusBar, Th("ok"))
            SetCtrlValue(LblStatusBar, "Status : Automatic (Using Global Screen Outputs)")
        }
    }

    if IsObject(LblConflictBar) {
        SetCtrlValue(LblConflictBar, Format("Active Overrides : {1}  (Monitors : {2}, Apps : {3})", totalActive, activeMons.Length + (AllMonitorsMode ? 1 : 0), activeAppCount))
    }

    Loop MAX_MONITORS {
        isConn := (A_Index <= DetectedMonCount) && !IsMonitorDisabled(A_Index)
        if MonOvrButtons.Has(A_Index) {
            isMonOvrOn := isConn && MonitorOverrideActive.Get(A_Index, false)
            SetCtrlText(MonOvrButtons[A_Index], isMonOvrOn ? "Ovrd : ON" : "Ovrd : OFF")
            SetButtonColor(MonOvrButtons[A_Index], isMonOvrOn ? BtnColorMonOvrOn : BtnColorMonOvrOff)
        }
    }

    conflicts := DetectRuleConflicts()
    if conflicts.Length = 0 {
        SetCtrlColor(LblConflictStatus, Th("ok"))
        SetCtrlValue(LblConflictStatus, "✓ No rule or override contradictions")
        SetCtrlEnabled(BtnFixConflicts, false)
    } else {
        msgs := []
        for c in conflicts
            msgs.Push(c.msg)
        SetCtrlColor(LblConflictStatus, Th("err"))
        SetCtrlValue(LblConflictStatus, "⚠ " JoinStrings(msgs, " | "))
        SetCtrlEnabled(BtnFixConflicts, true)
    }

    UpdateQuickActionButtons()
}

JoinStrings(arr, sep) {
    out := ""
    for i, s in arr {
        out .= (i > 1 ? sep : "") . s
    }
    return out
}

; Display labels: your display name when set, otherwise the Windows name (unique, so
; menus never get two items with the same text).
ApplyDeviceAliases(devs) {
    seen := Map()
    seen.CaseSense := false
    for d in devs {
        if !d.HasOwnProp("winLabel")
            d.winLabel := d.label
        label := DeviceAliases.Get(DevKey(d.id), d.winLabel)
        base := label, k := 1
        while seen.Has(label)
            label := base " #" (++k)
        seen[label] := true
        d.label := label
    }
}

; Windows' own name of a device (no display name), connected or not.
DeviceWinName(devId) {
    if IsObject(d := FindCachedDevice(devId))
        return d.winLabel
    if RegExMatch(devId, MultiDevNames.Has(NormDevId(devId)) ? "^(.+?)\\Device\\(.+?)\\(?:Render|Capture)$"
                                                             : "^(?:\d+-\s*)?(.+?)\\Device\\(.+?)\\(?:Render|Capture)$", &m)
        return m[2] "  [" m[1] "]"
    return devId
}

; Name of a microphone for status texts ("Windows default mic" for the default).
MicDisplayName(micId) {
    return (micId = "" || micId = DEFAULT_CAPTURE_DEVICE) ? "Windows default mic" : ShortDeviceName(micId)
}

DeviceHidden(id, kind) {
    return kind != "" && InStr(DeviceHideMap.Get(DevKey(id), ""), kind)
}

ShortDeviceName(devId) {
    if devId = DEFAULT_DEVICE || devId = "" || devId = DEFAULT_CAPTURE_DEVICE
        return "Windows Default"
    if IsObject(d := FindCachedDevice(devId))
        return d.label
    if DeviceAliases.Has(DevKey(devId))
        return DeviceAliases[DevKey(devId)]
    if RegExMatch(devId, MultiDevNames.Has(NormDevId(devId)) ? "^(.+?)\\Device\\(.+?)\\(?:Render|Capture)$"
                                                             : "^(?:\d+-\s*)?(.+?)\\Device\\(.+?)\\(?:Render|Capture)$", &m)
        return m[2] "  [" m[1] "]"                 ; same form as the device list: Name  [Adapter]
    return devId
}

; ------------------------------ DEVICES WINDOW ------------------------------
; One row per device (connected ones, then saved ones that are disconnected): a display
; name used by this app only, and which device lists show it.
ShowDevicesDialog(*) {
    global DevicesDlg, CachedDevices, DevicesStale
    CheckAudioEndpointsNow()
    if DevicesStale || !CachedDevices.Length {
        CachedDevices := GetDevices()
        DevicesStale := false
    }
    try {
        if IsObject(DevicesDlg)
            DevicesDlg.Destroy()
    }

    rows := [], seen := Map()
    seen.CaseSense := false
    for d in CachedDevices {
        seen[DevKey(d.id)] := true
        rows.Push({id: d.id, name: d.winLabel, conn: true})
    }
    addSaved(id) {
        if id = "" || id = DEFAULT_DEVICE || id = DISABLED_MONITOR || seen.Has(DevKey(id))
            return
        seen[DevKey(id)] := true
        rows.Push({id: id, name: DeviceWinName(id), conn: false})
    }
    for src in [MonitorRules, MonitorOverrideRules, AppOverrideRules, AppTempOverride, AppFixedDevice] {
        for k, id in src
            addSaved(id)
    }
    addSaved(AllDevice), addSaved(AllMonitorsDevice)

    ; microphones: connected ones, then paired ones that are disconnected
    micRows := [], micSeen := Map()
    micSeen.CaseSense := false
    for m in CachedMics {
        micSeen[DevKey(m.id)] := true
        micRows.Push({id: m.id, name: m.winLabel, conn: true})
    }
    for k, micId in DeviceMics {
        if micId != "" && !micSeen.Has(DevKey(micId)) {
            micSeen[DevKey(micId)] := true
            micRows.Push({id: micId, name: DeviceWinName(micId), conn: false})
        }
    }

    ownerHwnd := 0
    try {
        if IsObject(MainGui) && DllCall("IsWindowVisible", "Ptr", MainGui.Hwnd)
            ownerHwnd := MainGui.Hwnd
    }
    dlg := Gui("-MaximizeBox -MinimizeBox" (ownerHwnd ? " +Owner" ownerHwnd : " +AlwaysOnTop"), "Devices")
    DevicesDlg := dlg
    dlg.BackColor := Th("bg")
    dlg.AddButton("x0 y0 w0 h0")                   ; invisible first control: takes the focus when the window opens,
                                                   ; so no text box gets the cursor until you click one
    W := 1084                                      ; client width

    cols := [["o", "Output", 520], ["m", "Monitor ovr", 600], ["a", "App ovr", 680], ["t", "Temp ovr", 760]]
    dlg.SetFont("s9 Bold c" Th("text2"), "Segoe UI")
    dlg.AddText("x16 y14 w300", "Playback device (Windows name)")
    dlg.AddText("x330 y14 w170", "Display name")
    AddTip(dlg.AddText("x488 y14 w304 Center +0x100", "Show in these lists"), "Untick a device to hide it from that list.`nA device already selected somewhere stays shown there.")
    AddTip(dlg.AddText("x812 y14 w256 +0x100", "Paired microphone"), "The microphone of a monitor whose Output is this device.`n"
        . "Also the suggested microphone of an Override Mic that uses this device.")
    dlg.SetFont("s8 Norm c" Th("muted"), "Segoe UI")
    for c in cols
        dlg.AddText("x" (c[3] - 32) " y32 w80 Center", c[2])
    dlg.AddText("x330 y32 w170", "used by this app only")
    dlg.AddText("x812 y32 w256", "box : untick to pause the pair")

    ; the microphone choices (each row adds its own disconnected microphone when it has one)
    micLabels := ["Windows default microphone"], micIds := [DEFAULT_CAPTURE_DEVICE]
    for m in CachedMics {
        micLabels.Push(m.label)
        micIds.Push(m.id)
    }

    dlg.SetFont("s9 Norm c" Th("text"), "Segoe UI")
    ctrls := []
    y := 54
    for r in rows {
        dlg.AddText("x16 y" (y + 3) " w306 h18 +0x4000 c" (r.conn ? Th("text") : Th("muted"))
            , (r.conn ? "" : "[Disconnected] ") r.name)                        ; 0x4000 = end ellipsis
        e := dlg.AddEdit("x330 y" y " w170 h22", DeviceAliases.Get(DevKey(r.id), ""))
        cbs := Map()
        for c in cols {
            cb := dlg.AddCheckbox("x" c[3] " y" (y + 2) " w16 h20")
            cb.Value := DeviceHidden(r.id, c[1]) ? 0 : 1
            cbs[c[1]] := cb
        }
        labels := micLabels.Clone(), ids := micIds.Clone()
        cur := DeviceMics.Get(DevKey(r.id), "")
        chosen := 1
        if cur != "" {
            for i, id in ids {
                if i > 1 && DevKey(id) = DevKey(cur) {
                    chosen := i
                    break
                }
            }
            if chosen = 1 {                        ; paired microphone not connected: keep it selectable
                labels.Push("[Disconnected] " DeviceWinName(cur))
                ids.Push(cur)
                chosen := ids.Length
            }
        }
        paused := cur != "" && DevicePairOff.Has(DevKey(r.id))
        pc := dlg.AddCheckbox("x812 y" (y + 2) " w16 h20" (cur = "" ? " Disabled" : ""))
        pc.Value := paused ? 0 : 1
        dd := dlg.AddDropDownList("x834 y" (y - 1) " w234" (paused ? " Disabled" : ""), labels)
        dd.Choose(chosen)
        pc.OnEvent("Click", pairBoxClicked.Bind(dd))
        dd.OnEvent("Change", pairMicChanged.Bind(pc, ids))
        ctrls.Push({id: r.id, edit: e, cbs: cbs, mic: dd, micIds: ids, pair: pc})
        y += 28
    }

    ; microphones: display names only
    y += 10
    dlg.SetFont("s9 Bold c" Th("text2"), "Segoe UI")
    dlg.AddText("x16 y" y " w300", "Microphone (Windows name)")
    dlg.AddText("x330 y" y " w170", "Display name")
    dlg.SetFont("s9 Norm c" Th("text"), "Segoe UI")
    y += 26
    micCtrls := []
    if !micRows.Length {
        dlg.AddText("x16 y" (y + 3) " w480 c" Th("muted"), "(no microphones found)")
        y += 28
    }
    for r in micRows {
        dlg.AddText("x16 y" (y + 3) " w306 h18 +0x4000 c" (r.conn ? Th("text") : Th("muted"))
            , (r.conn ? "" : "[Disconnected] ") r.name)
        e := dlg.AddEdit("x330 y" y " w170 h22", DeviceAliases.Get(DevKey(r.id), ""))
        micCtrls.Push({id: r.id, edit: e})
        y += 28
    }

    y += 6
    chkMics := dlg.AddCheckbox("x16 y" y " w" (W - 32) " h20", "Switch microphones  (each app uses its monitor's microphone, or its Override Mic)")
    chkMics.Value := MicsFollowOutput ? 1 : 0
    AddTip(chkMics, "Unchecked: Screen Audio Router never changes microphones.`n"
        . "Nothing paired and no Override Mic = microphones are left alone too.")
    y += 26

    dlg.SetFont("s8 c" Th("muted"), "Segoe UI")
    dlg.AddText("x16 y" (y + 6) " w" (W - 32) " h72"
        , "Display name : your own short name for a device, used by this app only. Empty = the Windows name.`n"
        . "Show in these lists : untick to hide a device from the Output, Monitor override, App override or Temporary override lists.`n"
        . "Paired microphone : every app on a monitor uses the microphone paired with that monitor's Output (none = Windows default). Untick its box to pause the pair; the microphone is kept.`n"
        . "Overrides change only the sound. To switch the microphone too, tick Override Mic for that app, or Mic for that monitor.`n"
        . "Its list starts on `"Paired`" = the microphone paired here with the override device.")
    y += 86
    dlg.SetFont("s9 Norm c" Th("text"), "Segoe UI")
    bRefresh := AddColoredButton(dlg, "x16 y" y " w110 h28", "Refresh", ColorDefault)
    bReplace := AddColoredButton(dlg, "x132 y" y " w130 h28", "Replace Device...", ColorDefault)
    bSave := AddColoredButton(dlg, "x" (W - 248) " y" y " w110 h28", "Save", ColorDefault)
    bCancel := AddColoredButton(dlg, "x" (W - 132) " y" y " w110 h28", "Cancel", ColorDefault)
    AddTip(bRefresh, "Read the device list again (unsaved changes here are discarded).")
    AddTip(bReplace, "Swap one device for another in every output and override at once,`ne.g. after a driver update renamed it or it moved to another port.")

    ; "Pair" box: unticked = paused, its microphone list greyed out (kept)
    pairBoxClicked(ddCtrl, box, *) {
        ddCtrl.Enabled := box.Value ? true : false
    }
    ; no microphone chosen = nothing to pause
    pairMicChanged(box, idList, ddCtrl, *) {
        hasMic := ddCtrl.Value && idList[ddCtrl.Value] != DEFAULT_CAPTURE_DEVICE
        box.Enabled := hasMic ? true : false
        if !hasMic
            box.Value := 1
    }
    saveAlias(id, editCtrl) {
        k := DevKey(id)
        nm := Trim(StrReplace(editCtrl.Value, "|"))
        if nm = "" || nm = DeviceWinName(id)
            MapDel(DeviceAliases, k)
        else
            DeviceAliases[k] := nm
    }
    save(*) {
        global MicsFollowOutput
        wasActive := MicRoutingActive()
        for c in ctrls {
            k := DevKey(c.id)
            saveAlias(c.id, c.edit)
            hid := ""
            for kind, cb in c.cbs {
                if !cb.Value
                    hid .= kind
            }
            if hid = ""
                MapDel(DeviceHideMap, k)
            else
                DeviceHideMap[k] := hid
            mi := c.mic.Value
            if !mi || c.micIds[mi] = DEFAULT_CAPTURE_DEVICE {
                MapDel(DeviceMics, k)
                MapDel(DevicePairOff, k)
            } else {
                DeviceMics[k] := c.micIds[mi]
                if c.pair.Value
                    MapDel(DevicePairOff, k)
                else
                    DevicePairOff[k] := true
            }
        }
        for c in micCtrls
            saveAlias(c.id, c.edit)
        MicsFollowOutput := chkMics.Value ? true : false
        ApplyDeviceAliases(CachedDevices)
        ApplyDeviceAliases(CachedMics)
        SaveConfig()
        SetupTrayMenu()
        dlg.Destroy()
        if wasActive && !MicRoutingActive()
            ResetTrackedAppMics()                  ; switched off: microphones back to the Windows default
        ReapplyAll(false, true)                    ; new pairs apply right away
        try {
            if IsObject(MainGui) && DllCall("IsWindowVisible", "Ptr", MainGui.Hwnd) {
                PopulateMonitorDropdowns()
                PopulateOverrideDeviceDropdowns()
                RefreshSelectedAppPanel()
                PopulateAppList(true)
            }
        }
        Tip("Device settings saved")
    }
    refresh(*) {
        global CachedDevices, DevicesStale
        CachedDevices := GetDevices()
        DevicesStale := false
        SetTimer(ShowDevicesDialog, -10)
    }
    bSave.OnEvent("Click", save)
    bCancel.OnEvent("Click", (*) => dlg.Destroy())
    bRefresh.OnEvent("Click", refresh)
    bReplace.OnEvent("Click", ShowReplaceDeviceDialog)
    dlg.OnEvent("Close", (*) => dlg.Destroy())
    dlg.OnEvent("Escape", (*) => dlg.Destroy())

    ApplyThemeToWindow(dlg)
    h := y + 44
    pos := ""
    if ownerHwnd {
        try {
            WinGetPos(&mx, &my, &mw, &mh, ownerHwnd)
            sc := A_ScreenDPI / 96
            pos := Format("x{1} y{2} ", mx + (mw - Round((W + 16) * sc)) // 2, my + Max(0, (mh - Round((h + 40) * sc)) // 2))
        }
    }
    dlg.Show(pos "w" W " h" h)
}

; ------------------------------ REPLACE DEVICE ------------------------------
; Swaps one device for another in every monitor output and override at once.
DeviceReferences(id) {
    where := []
    for m, d in MonitorRules {
        if d = id
            where.Push("Monitor " m " output")
    }
    for m, d in MonitorOverrideRules {
        if d = id
            where.Push("Monitor " m " override")
    }
    for app, d in AppOverrideRules {
        if d = id
            where.Push(app " override")
    }
    for app, d in AppTempOverride {
        if d = id
            where.Push(app " temporary override")
    }
    for app, d in AppFixedDevice {
        if d = id
            where.Push(app " fixed device")
    }
    if AllDevice = id
        where.Push("All-Apps override")
    if AllMonitorsDevice = id
        where.Push("All-Monitors override")
    return where
}

ShowReplaceDeviceDialog(*) {
    global ReplaceDlg, CachedDevices, DevicesStale
    CheckAudioEndpointsNow()
    if DevicesStale || !CachedDevices.Length {
        CachedDevices := GetDevices()
        DevicesStale := false
    }
    try {
        if IsObject(ReplaceDlg)
            ReplaceDlg.Destroy()
    }

    ; saved devices, missing ones first
    olds := [], seen := Map()
    seen.CaseSense := false
    for pass in [false, true] {
        for src in [MonitorRules, MonitorOverrideRules, AppOverrideRules, AppTempOverride, AppFixedDevice] {
            for k, d in src {
                if d != "" && d != DEFAULT_DEVICE && d != DISABLED_MONITOR && !seen.Has(d) && DevicePresent(d) = pass {
                    seen[d] := true
                    olds.Push(d)
                }
            }
        }
        for d in [AllDevice, AllMonitorsDevice] {
            if d != "" && d != DEFAULT_DEVICE && !seen.Has(d) && DevicePresent(d) = pass {
                seen[d] := true
                olds.Push(d)
            }
        }
    }
    if !olds.Length {
        Tip("No devices are assigned yet")
        return
    }

    owner := "", ownerHwnd := 0
    try {
        if IsObject(DevicesDlg) && DllCall("IsWindowVisible", "Ptr", DevicesDlg.Hwnd)
            ownerHwnd := DevicesDlg.Hwnd
        else if IsObject(MainGui) && DllCall("IsWindowVisible", "Ptr", MainGui.Hwnd)
            ownerHwnd := MainGui.Hwnd
    }
    if ownerHwnd
        owner := " +Owner" ownerHwnd
    dlg := Gui("-MaximizeBox -MinimizeBox" (owner != "" ? owner : " +AlwaysOnTop"), "Replace Device")
    ReplaceDlg := dlg
    dlg.BackColor := Th("bg")
    dlg.SetFont("s9 c" Th("text"), "Segoe UI")

    oldLabels := []
    for d in olds
        oldLabels.Push((DevicePresent(d) ? "" : "[Disconnected] ") ShortDeviceName(d))
    dlg.AddText("x16 y18 w70", "Replace :")
    ddOld := dlg.AddDropDownList("x90 y14 w380", oldLabels)
    dlg.SetFont("s8 c" Th("muted"), "Segoe UI")
    lblUses := dlg.AddText("x90 y42 w380 h32", "")
    dlg.SetFont("s9 c" Th("text"), "Segoe UI")

    newLabels := ["Windows Default Device"], newIds := [DEFAULT_DEVICE]
    for d in CachedDevices {
        newLabels.Push(d.label)
        newIds.Push(d.id)
    }
    dlg.AddText("x16 y84 w70", "With :")
    ddNew := dlg.AddDropDownList("x90 y80 w380", newLabels)

    btnOk := AddColoredButton(dlg, "x252 y122 w106 h28", "Replace", ColorDefault)
    btnNo := AddColoredButton(dlg, "x364 y122 w106 h28", "Cancel", ColorDefault)

    ; best guess for a missing device: a connected one with the same name
    guess(oldId) {
        nm := RegExMatch(oldId, "\\Device\\(.+?)\\Render$", &m) ? m[1] : ""
        for i, id in newIds {
            if id != DEFAULT_DEVICE && id != oldId && nm != "" && InStr(id, "\Device\" nm "\Render")
                return i
        }
        return 0
    }
    update(*) {
        o := olds[ddOld.Value]
        w := DeviceReferences(o)
        txt := ""
        for x in w
            txt .= (txt = "" ? "" : ", ") x
        lblUses.Value := "Used by : " (txt = "" ? "-" : txt)
        g := guess(o)
        if g
            ddNew.Choose(g)
        else if !ddNew.Value
            ddNew.Choose(1)
    }
    doReplace(*) {
        o := olds[ddOld.Value]
        if !ddNew.Value
            return
        n := newIds[ddNew.Value]
        if n = o {
            Tip("Pick a different device")
            return
        }
        count := ReplaceDeviceEverywhere(o, n)
        dlg.Destroy()
        if IsObject(DevicesDlg)
            SetTimer(ShowDevicesDialog, -10)          ; show the result in the Devices window
        Tip(Format("{1} replaced in {2} place{3}", ShortDeviceName(n), count, count = 1 ? "" : "s"))
    }
    ddOld.OnEvent("Change", update)
    btnOk.OnEvent("Click", doReplace)
    btnNo.OnEvent("Click", (*) => dlg.Destroy())
    dlg.OnEvent("Close", (*) => dlg.Destroy())
    dlg.OnEvent("Escape", (*) => dlg.Destroy())

    ddOld.Choose(1)
    update()
    ApplyThemeToWindow(dlg)
    pos := ""
    if owner != "" {
        try {
            WinGetPos(&mx, &my, &mw, &mh, ownerHwnd)
            sc := A_ScreenDPI / 96
            pos := Format("x{1} y{2} ", mx + (mw - Round(500 * sc)) // 2, my + Max(0, (mh - Round(200 * sc)) // 2))
        }
    }
    dlg.Show(pos "w486 h164")
}

ReplaceDeviceEverywhere(oldId, newId) {
    global AllDevice, AllMonitorsDevice
    count := 0
    for si, src in [MonitorRules, MonitorOverrideRules, AppOverrideRules, AppTempOverride, AppFixedDevice] {
        for k, d in src.Clone() {
            if d = oldId {
                if newId = DEFAULT_DEVICE && si < 4        ; (temporary / fixed devices keep an explicit device)
                    src.Delete(k)                  ; Windows default is stored as "no device"
                else
                    src[k] := newId
                count++
            }
        }
    }
    if AllDevice = oldId
        AllDevice := newId, count++
    if AllMonitorsDevice = oldId
        AllMonitorsDevice := newId, count++
    if newId != DEFAULT_DEVICE && DeviceMics.Has(DevKey(oldId)) && !DeviceMics.Has(DevKey(newId)) {
        DeviceMics[DevKey(newId)] := DeviceMics[DevKey(oldId)]      ; its microphone comes along
        if DevicePairOff.Has(DevKey(oldId))
            DevicePairOff[DevKey(newId)] := true
    }
    MapDel(WarnedMissing, DevKey(oldId))
    SaveConfig()
    SaveState()
    SetupTrayMenu()
    ReapplyAll(false, true)
    try {
        if IsObject(MainGui) && DllCall("IsWindowVisible", "Ptr", MainGui.Hwnd) {
            PopulateMonitorDropdowns()
            PopulateOverrideDeviceDropdowns()
            RefreshSelectedAppPanel()
            PopulateAppList(true)
            UpdateOverrideBanner()
        }
    }
    return count
}

; ------------------------------ HOVER TOOLTIPS ------------------------------
; AddTip(ctrl, text) registers a tooltip shown after the mouse rests ~0.6 s on the control.

AddTip(ctrl, text) {
    HoverTips[ctrl.Hwnd] := text
    return ctrl
}

HoverTipCheck(hwnd) {
    static last := 0
    if hwnd = last
        return
    last := hwnd
    ToolTip(, , , 5)
    SetTimer(HoverTipWatch, 0)
    if HoverTips.Has(hwnd)
        SetTimer(HoverTipShow.Bind(hwnd), -600)
}

HoverTipShow(hwnd) {
    MouseGetPos(, , , &under, 2)
    if under != hwnd || !HoverTips.Has(hwnd)
        return
    ToolTip(HoverTips[hwnd], , , 5)
    SetTimer(HoverTipWatch, 250)
}

HoverTipWatch() {
    MouseGetPos(, , , &under, 2)
    if !under || !HoverTips.Has(under) {
        ToolTip(, , , 5)
        SetTimer(HoverTipWatch, 0)
    }
}
