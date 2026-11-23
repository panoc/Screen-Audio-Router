; Screen Audio Router - Copyright (C) 2026 panoc
; Licensed under the GNU GPL v3 or later. See LICENSE.
; ============================================================================
; Screen Audio Router  -  src\Update.ahk
; Update check: asks GitHub which release is the latest and tells about a newer one
; Part of ScreenAudioRouter.ahk (included at its end). Functions only.
; ============================================================================

; Only the version number of the latest release is read from GitHub. Nothing is sent but
; the request itself (GitHub sees the IP address, as when the page is opened in a browser).
; Nothing is downloaded or installed: "Download" opens the release page.

; About a minute after start (the network is up after a Windows sign-in), then once a day.
StartUpdateChecks() {
    SetTimer(AutoUpdateCheck, -60000)
}

AutoUpdateCheck() {
    SetTimer(AutoUpdateCheck, -86400000)
    if UpdateCheck
        CheckForUpdate(false)
}

CheckForUpdateNow(*) {
    CheckForUpdate(true)
}

; manual = asked for (tray menu): also says when there is nothing new, and shows a skipped version.
CheckForUpdate(manual) {
    global UpdReq, UpdStarted, UpdManual
    if IsObject(UpdReq) {                           ; a check is running already
        UpdManual := UpdManual || manual
        return
    }
    try {
        req := ComObject("WinHttp.WinHttpRequest.5.1")
        req.Open("GET", "https://api.github.com/repos/" UPDATE_REPO "/releases/latest", true)   ; true = in the background
        req.SetRequestHeader("User-Agent", "ScreenAudioRouter/" APP_VERSION)
        req.SetRequestHeader("Accept", "application/vnd.github+json")
        req.SetTimeouts(5000, 5000, 10000, 10000)
        req.Send()
    } catch as e {
        UpdateCheckDone(manual, "", "", "could not connect (" e.Message ")")
        return
    }
    UpdReq := req, UpdStarted := A_TickCount, UpdManual := manual
    SetTimer(UpdatePoll, 250)
}

UpdatePoll() {
    global UpdReq
    done := false, err := ""
    try done := UpdReq.WaitForResponse(0)
    catch as e
        done := true, err := e.Message
    if !done {
        if A_TickCount - UpdStarted < 20000
            return
        try UpdReq.Abort()
        done := true, err := "no answer"
    }
    SetTimer(UpdatePoll, 0)
    status := 0, body := ""
    if err = "" {
        try status := UpdReq.Status
        try body := UpdReq.ResponseText
    }
    UpdReq := ""
    if err = "" && status != 200
        err := "GitHub answered " status
    latest := "", url := ""
    if err = "" {
        if RegExMatch(body, '"tag_name"\s*:\s*"([^"]+)"', &m)
            latest := RegExReplace(m[1], "^[vV]")
        else
            err := "no version in the answer"
        if RegExMatch(body, '"html_url"\s*:\s*"(https://github\.com/[^"]+/releases/tag/[^"]+)"', &u)
            url := u[1]
    }
    UpdateCheckDone(UpdManual, latest, url, err)
}

UpdateCheckDone(manual, latest, url, err) {
    global UpdateLatest, UpdateUrl
    static toldAbout := ""
    if err != "" {
        LogLine("Update check: " err)
        if manual
            ShowOsdToast("Could not check for updates :`n" err, PrimaryMon(), "warn")
        return
    }
    LogLine("Update check: latest release " latest ", this is " APP_VERSION)
    if VersionCompare(latest, APP_VERSION) > 0 {
        UpdateLatest := latest
        UpdateUrl := url != "" ? url : "https://github.com/" UPDATE_REPO "/releases/latest"
        if manual || (latest != UpdateSkip && latest != toldAbout) {
            toldAbout := latest
            ShowUpdateToast(latest, manual)
        }
    } else {
        UpdateLatest := ""
        if manual
            ShowOsdToast("Screen Audio Router is up to date (v" APP_VERSION ")", PrimaryMon())
    }
    UpdateNoticeChanged()
}

; A newer version that was not skipped: shown in the tray menu and next to the version in the window.
UpdateShown() {
    return UpdateLatest != "" && UpdateLatest != UpdateSkip
}

UpdateNoticeChanged() {
    SetupTrayMenu()
    try {
        if IsObject(LblVersion) {
            shown := UpdateShown()
            SetCtrlText(LblVersion, "v" APP_VERSION (shown ? "   ·   v" UpdateLatest " available" : ""))
            SetCtrlColor(LblVersion, shown ? Th("accent") : Th("muted"))
        }
    }
}

OpenUpdatePage(*) {
    try Run(UpdateUrl != "" ? UpdateUrl : "https://github.com/" UPDATE_REPO "/releases/latest")
    CloseUpdateToast()
}

SkipUpdateVersion(*) {
    global UpdateSkip
    if UpdateLatest = ""
        return
    UpdateSkip := UpdateLatest
    SaveSettings()
    CloseUpdateToast()
    UpdateNoticeChanged()
    Tip("Version " UpdateSkip " skipped. Tray menu > Settings > Check for updates now shows it again.")
}

OnUpdateCheckChanged(ctrl, *) {
    global UpdateCheck
    UpdateCheck := ctrl.Value ? true : false
    SaveSettings()
    if UpdateCheck
        SetTimer(AutoUpdateCheck, -3000)
}

; 1 when a is newer than b, -1 when older, 0 when equal. "1.6.2-beta3" is older than "1.6.2".
VersionCompare(a, b) {
    pa := VersionParts(a), pb := VersionParts(b)
    Loop 3 {
        if pa.n[A_Index] != pb.n[A_Index]
            return pa.n[A_Index] > pb.n[A_Index] ? 1 : -1
    }
    if pa.pre = pb.pre
        return 0
    if pa.pre = ""                                  ; a release beats its betas
        return 1
    if pb.pre = ""
        return -1
    na := RegExMatch(pa.pre, "\d+$", &ma) ? Integer(ma[0]) : 0
    nb := RegExMatch(pb.pre, "\d+$", &mb) ? Integer(mb[0]) : 0
    return na = nb ? (StrCompare(pa.pre, pb.pre) > 0 ? 1 : -1) : (na > nb ? 1 : -1)
}

VersionParts(v) {
    v := RegExReplace(Trim(v), "^[vV]")
    pre := ""
    if p := InStr(v, "-")
        pre := SubStr(v, p + 1), v := SubStr(v, 1, p - 1)
    n := [0, 0, 0]
    for i, part in StrSplit(v, ".") {
        if i > 3
            break
        n[i] := IsInteger(part) ? Integer(part) : 0
    }
    return {n: n, pre: pre}
}

; ------------------------------ THE NOTIFICATION ----------------------------
; Bottom right of the main screen, in the style of the other notifications, with buttons.
; It stays a minute, longer while the mouse is over it, until a button is clicked.
ShowUpdateToast(ver, manual := false) {
    global UpdateToastGui, UpdateToastUntil
    if IsStartingUp {                               ; not over a starting desktop: a moment later
        SetTimer(ShowUpdateToast.Bind(ver, manual), -5000)
        return
    }
    CloseUpdateToast()
    g := Gui("+AlwaysOnTop -Caption +ToolWindow +Border", "Screen Audio Router update")
    g.BackColor := "18181B"
    g.MarginX := 16, g.MarginY := 12
    g.SetFont("s10 Bold cF9FAFB", "Segoe UI")
    g.AddText("xm w300", "Screen Audio Router " ver " is available")
    g.SetFont("s9 Norm cC8CCD3", "Segoe UI")
    g.AddText("xm y+4 w300", "You have v" APP_VERSION ". Download the new version from GitHub and replace the exe: your settings are kept.")
    g.SetFont("s9 Norm c" Th("text"), "Segoe UI")
    bDl := AddColoredButton(g, "xm y+12 w100 h28", "Download", BtnColorApply)
    bSkip := AddColoredButton(g, "x+8 w118 h28", "Skip this version", ColorDefault)
    bLater := AddColoredButton(g, "x+8 w66 h28", "Later", ColorDefault)
    bDl.OnEvent("Click", OpenUpdatePage)
    bSkip.OnEvent("Click", SkipUpdateVersion)
    bLater.OnEvent("Click", (*) => CloseUpdateToast())
    AddTip(bLater, "Close. The tray menu keeps an `"Update available`" item.")
    g.OnEvent("Escape", (*) => CloseUpdateToast())
    ApplyThemeToWindow(g)

    g.Show("NoActivate x-32000 y-32000 AutoSize")
    g.GetPos(, , &w, &h)
    MonitorGetWorkArea(MonitorGetPrimary(), &wl, &wt, &wr, &wb)
    g.Show(Format("NoActivate x{1} y{2}", Max(wl + 10, wr - w - 18), Max(wt + 10, wb - h - 18)))
    UpdateToastGui := g
    UpdateToastUntil := A_TickCount + 60000
    SetTimer(UpdateToastTick, 500)
    if !manual
        try SoundPlay("*64")                        ; Windows "information" sound
}

UpdateToastTick() {
    global UpdateToastUntil
    if !IsObject(UpdateToastGui) {
        SetTimer(UpdateToastTick, 0)
        return
    }
    MouseGetPos(, , &win)
    if win = UpdateToastGui.Hwnd
        UpdateToastUntil := Max(UpdateToastUntil, A_TickCount + 10000)   ; reading it: stay
    else if A_TickCount > UpdateToastUntil
        CloseUpdateToast()
}

CloseUpdateToast() {
    global UpdateToastGui
    SetTimer(UpdateToastTick, 0)
    try {
        if IsObject(UpdateToastGui)
            UpdateToastGui.Destroy()
    }
    UpdateToastGui := ""
}
