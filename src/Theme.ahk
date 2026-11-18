; Screen Audio Router - Copyright (C) 2026 panoc
; Licensed under the GNU GPL v3 or later. See LICENSE.
; ============================================================================
; Screen Audio Router  -  src\Theme.ahk
; Light / dark theme drawing: buttons, tables, frames
; Part of ScreenAudioRouter.ahk (included at its end). Functions only.
; ============================================================================

; ------------------------------ THEME (light / dark) ------------------------
; Palette colors are used for everything the script draws (window, labels, edit boxes,
; lists, buttons). In dark mode, native controls the script cannot recolor (drop-downs,
; scroll bars, list headers, menus, the title bar) use Windows' own dark styling, which
; needs Windows 10 1903 or newer; older builds just get the dark palette.
InitThemeDefaults() {
    ; the palette is defined in the THEME section near the top of the script
    for k in ThemeKeys
        ThemeColors[k] := String(THEME.Get(k, "FF00FF"))
}


ThemeIniValue(v) {
    return v = "" ? "none" : v
}

Th(key) {
    return ThemeColors.Get(key, "FF00FF")
}

OsBuild() {
    return RegExMatch(A_OSVersion, "\.(\d+)$", &m) ? Integer(m[1]) : 0
}

; Gives "default" buttons the theme's button color. Only buttons still set to
; ColorDefault change; a button you gave its own color (e.g. Color10) keeps it.
ApplyTheme() {
    global ColorDefault
    global BtnColorMonOvrOff, BtnColorAppOvrOff, BtnColorDetect, BtnColorRefresh, BtnColorIdentifyMons, BtnColorRemoveApp, BtnColorResetAppOvr, BtnColorFixConflicts, BtnColorQuickActions, BtnColorHkSet, BtnColorHkClear, BtnColorHkReset, BtnColorResetOverrides, BtnColorResetWinMixer, BtnColorResetSettings, BtnColorDetectWinDetect, BtnColorDetectWinAdd, BtnColorDetectWinClose
    global BtnColorQuickSelectedOff, BtnColorQuickAllAppsOff, BtnColorQuickAllMonsOff
    oldDef := ColorDefault
    ColorDefault := "#" Th("btnDefault")
    if BtnColorMonOvrOff = oldDef
        BtnColorMonOvrOff := ColorDefault
    if BtnColorAppOvrOff = oldDef
        BtnColorAppOvrOff := ColorDefault
    if BtnColorDetect = oldDef
        BtnColorDetect := ColorDefault
    if BtnColorRefresh = oldDef
        BtnColorRefresh := ColorDefault
    if BtnColorIdentifyMons = oldDef
        BtnColorIdentifyMons := ColorDefault
    if BtnColorRemoveApp = oldDef
        BtnColorRemoveApp := ColorDefault
    if BtnColorResetAppOvr = oldDef
        BtnColorResetAppOvr := ColorDefault
    if BtnColorFixConflicts = oldDef
        BtnColorFixConflicts := ColorDefault
    if BtnColorQuickActions = oldDef
        BtnColorQuickActions := ColorDefault
    if BtnColorHkSet = oldDef
        BtnColorHkSet := ColorDefault
    if BtnColorHkClear = oldDef
        BtnColorHkClear := ColorDefault
    if BtnColorHkReset = oldDef
        BtnColorHkReset := ColorDefault
    if BtnColorResetOverrides = oldDef
        BtnColorResetOverrides := ColorDefault
    if BtnColorResetWinMixer = oldDef
        BtnColorResetWinMixer := ColorDefault
    if BtnColorResetSettings = oldDef
        BtnColorResetSettings := ColorDefault
    if BtnColorDetectWinDetect = oldDef
        BtnColorDetectWinDetect := ColorDefault
    if BtnColorDetectWinAdd = oldDef
        BtnColorDetectWinAdd := ColorDefault
    if BtnColorDetectWinClose = oldDef
        BtnColorDetectWinClose := ColorDefault
    if BtnColorQuickSelectedOff = oldDef
        BtnColorQuickSelectedOff := ColorDefault
    if BtnColorQuickAllAppsOff = oldDef
        BtnColorQuickAllAppsOff := ColorDefault
    if BtnColorQuickAllMonsOff = oldDef
        BtnColorQuickAllMonsOff := ColorDefault
    ApplyMenuTheme()
}

; Tray menu and title-bar menus (undocumented uxtheme ordinals; Windows 10 1903+).
ApplyMenuTheme() {
    if OsBuild() < 18362
        return
    try {
        hUx := DllCall("LoadLibrary", "Str", "uxtheme.dll", "Ptr")
        fnSet := DllCall("GetProcAddress", "Ptr", hUx, "Ptr", 135, "Ptr")
        fnFlush := DllCall("GetProcAddress", "Ptr", hUx, "Ptr", 136, "Ptr")
        if fnSet
            DllCall(fnSet, "Int", 2)                    ; ForceDark
        if fnFlush
            DllCall(fnFlush)
    }
}

ApplyThemeToWindow(guiObj) {
    for h in ThemedLVs.Clone() {
        if !DllCall("IsWindow", "Ptr", h)
            ThemedLVs.Delete(h)
    }
    build := OsBuild()
    native := build >= 18362
    try {
        if build >= 17763 {
            v := 1                                      ; dark title bar
            if DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", guiObj.Hwnd, "Int", 20, "Int*", v, "Int", 4) != 0
                DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", guiObj.Hwnd, "Int", 19, "Int*", v, "Int", 4)
        }
    }
    lists := []
    groups := []
    for hwnd, ctrl in guiObj {
        try {
            t := ctrl.Type
            if t = "Edit" {
                ctrl.Opt("Background" Th("editBg"))
                if !HotkeyBoxMeta.Has(hwnd)
                    ctrl.Opt("c" Th("text"))
                if native
                    DllCall("uxtheme\SetWindowTheme", "Ptr", hwnd, "Str", "DarkMode_CFD", "Ptr", 0)
            } else if t = "ListView" {
                ctrl.Opt("Background" Th("listBg") " c" Th("text"))
                if native
                    DllCall("uxtheme\SetWindowTheme", "Ptr", hwnd, "Str", "DarkMode_Explorer", "Ptr", 0)
                ThemedLVs[hwnd] := true                         ; rows and selection drawn in OnWmNotify (both themes)
                ctrl.Opt("-Grid")                               ; grid lines drawn in gridLine instead (both themes)
                lists.Push(ctrl)                                ; header replaced by a strip in hdrBg (both themes)
            } else if native && (t = "DDL" || t = "ComboBox") {
                DllCall("uxtheme\SetWindowTheme", "Ptr", hwnd, "Str", "DarkMode_CFD", "Ptr", 0)
                if t = "DDL"
                    DdlSubclass(hwnd)                           ; closed box and list text in ddlBg / ddlText
            } else if t = "GroupBox" {
                groups.Push(ctrl)                               ; replaced by DrawGroupFrame below (both themes)
            } else if t = "CheckBox" {
                DarkCheckSubclass(hwnd)                         ; painted by the script in the theme colors (both themes)
                ctrl.SetFont("s9 Norm c" Th("text"), "Segoe UI")
            } else if t = "Radio" {
                ctrl.Opt("-Theme")
                ctrl.SetFont("s9 Norm c" Th("text"), "Segoe UI")
            } else if native && t = "Button" && !BtnColorMap.Has(hwnd) {
                DllCall("uxtheme\SetWindowTheme", "Ptr", hwnd, "Str", "DarkMode_Explorer", "Ptr", 0)
            }
        }
    }
    for g in groups {                                           ; after the loop: adding controls while enumerating is unsafe
        try DrawGroupFrame(guiObj, g)
    }
    for lv in lists {
        try ReplaceListHeader(guiObj, lv)
    }
    if groups.Length
        guiObj.SetFont("s9 Norm c" Th("text"), "Segoe UI")
}

; Group boxes are hidden and replaced by 1 px lines in the "frame" palette color plus a
; title in "frameTitle", so both can be set per theme (a native frame ignores colors).
DrawGroupFrame(guiObj, g) {
    g.GetPos(&x, &y, &w, &h)
    title := g.Text
    g.Visible := false
    lineOpt := " Background" Th("frame")
    top := y + 7                                                ; middle of the title line
    guiObj.AddText("x" x " y" top " w1 h" Max(1, h - 7) lineOpt, "")
    guiObj.AddText("x" (x + w - 1) " y" top " w1 h" Max(1, h - 7) lineOpt, "")
    guiObj.AddText("x" x " y" (y + h - 1) " w" w " h1" lineOpt, "")
    if title = "" {
        guiObj.AddText("x" x " y" top " w" w " h1" lineOpt, "")
        return
    }
    guiObj.SetFont("s9 Bold c" Th("frameTitle"), "Segoe UI")
    tt := guiObj.AddText("x" (x + 8) " y" y " Background" Th("bg"), title)
    tt.GetPos(&tx, , &tw)
    guiObj.AddText("x" x " y" top " w" Max(1, tx - 2 - x) " h1" lineOpt, "")
    guiObj.AddText("x" (tx + tw + 2) " y" top " w" Max(1, x + w - (tx + tw + 2)) " h1" lineOpt, "")
}

; The native list header cannot be recolored. It is hidden, the list is
; moved down by the header's height, and a strip of plain controls using the hdrBg /
; hdrText / hdrLine palette colors is drawn in the freed space, so nothing overlaps
; the list. Column titles and widths are read from the list before the header goes.
ReplaceListHeader(guiObj, lv) {
    hHdr := SendMessage(0x101F, 0, 0, lv)                      ; LVM_GETHEADER
    if !hHdr
        return
    scale := A_ScreenDPI / 96
    rcH := Buffer(16, 0)
    DllCall("GetWindowRect", "Ptr", hHdr, "Ptr", rcH)
    hdrPx := NumGet(rcH, 12, "Int") - NumGet(rcH, 4, "Int")
    if hdrPx <= 0
        return
    hdrLeftPx := NumGet(rcH, 0, "Int")

    bold := false                                              ; follow the header font weight
    hFont := SendMessage(0x0031, 0, 0, hHdr)                   ; WM_GETFONT
    if hFont {
        lf := Buffer(92, 0)
        if DllCall("GetObjectW", "Ptr", hFont, "Int", 92, "Ptr", lf)
            bold := NumGet(lf, 16, "Int") >= 600
    }
    cols := []
    rcIt := Buffer(16, 0)
    Loop SendMessage(0x1200, 0, 0, hHdr) {                      ; HDM_GETITEMCOUNT
        SendMessage(0x1207, A_Index - 1, rcIt.Ptr, hHdr)        ; HDM_GETITEMRECT
        title := ""
        try title := lv.GetText(0, A_Index)                     ; row 0 = column header text
        cols.Push({l: NumGet(rcIt, 0, "Int"), r: NumGet(rcIt, 8, "Int"), title: title})
    }

    ; list's outer rect in GUI units, and where its header started (border offset)
    lv.GetPos(&lx, &ly, &lw, &lh)
    rcL := Buffer(16, 0)
    DllCall("GetWindowRect", "Ptr", lv.Hwnd, "Ptr", rcL)
    inset := Round((hdrLeftPx - NumGet(rcL, 0, "Int")) / scale)
    hd := Max(1, Round(hdrPx / scale))

    lv.Opt("+0x4000")                                           ; LVS_NOCOLUMNHEADER
    lv.Move(lx, ly + hd, lw, lh - hd)

    fontOpt := (bold ? "s9 Bold c" : "s9 Norm c") Th("hdrText")
    bgOpt := " Background" Th("hdrBg")
    lineOpt := " Background" Th("hdrLine")
    guiObj.AddText("x" lx " y" ly " w" lw " h" hd " +0x100" bgOpt, "")
    for c in cols {
        cl := lx + inset + Round(c.l / scale)
        cw := Round((c.r - c.l) / scale)
        tc := guiObj.AddText("x" (cl + 6) " y" ly " w" Max(1, cw - 8) " h" (hd - 1) " +0x4380" bgOpt, c.title)
        tc.SetFont(fontOpt, "Segoe UI")                         ; 0x4380 = ENDELLIPSIS | NOTIFY | CENTERIMAGE | NOPREFIX
        guiObj.AddText("x" (cl + cw - 1) " y" (ly + 4) " w1 h" Max(1, hd - 8) lineOpt, "")
    }
    guiObj.AddText("x" lx " y" (ly + hd - 1) " w" lw " h1" lineOpt, "")
}


; ------------------------------ COLOR BUTTONS -------------------------------
; ------------------------------ CHECKBOXES ----------------------------------
; Windows draws a white box for checkboxes whatever the theme, and AutoHotkey handles their
; draw notifications itself, so each checkbox (both themes) is subclassed and painted
; here: box in checkBg / checkBorder (checkOnBg + checkMark when ticked), text in text /
; muted, lighter outline under the mouse. Messages that make the button paint itself
; directly (click, tick, enable, focus...) run with its drawing switched off, then it is
; repainted here, off-screen first, so it never flickers.
DarkCheckSubclass(hwnd) {
    DarkChecks[hwnd] := {hot: false, dirty: false}
    DllCall("comctl32\SetWindowSubclass", "Ptr", hwnd, "Ptr", DarkCheckCallback(), "UPtr", 0x5341, "UPtr", 0)
}

DarkCheckCallback() {
    static cb := CallbackCreate(DarkCheckProc, "F", 6)
    return cb
}

; Any error here (e.g. while the program is closing) must never show a popup: the
; checkbox then simply gets Windows' own handling.
DarkCheckProc(hWnd, uMsg, wParam, lParam, uId, refData) {
    if !DarkChecksActive
        return DllCall("comctl32\DefSubclassProc", "Ptr", hWnd, "UInt", uMsg, "Ptr", wParam, "Ptr", lParam, "Ptr")
    try
        return DarkCheckProcBody(hWnd, uMsg, wParam, lParam, uId)
    catch
        return DllCall("comctl32\DefSubclassProc", "Ptr", hWnd, "UInt", uMsg, "Ptr", wParam, "Ptr", lParam, "Ptr")
}

; Unhooks every painted checkbox before the program closes (its windows are destroyed after
; the exit handlers, when the script can no longer run this code).
UnhookDarkChecks(*) {
    global DarkChecksActive
    DarkChecksActive := false
    for h in DarkChecks.Clone()
        try DllCall("comctl32\RemoveWindowSubclass", "Ptr", h, "Ptr", DarkCheckCallback(), "UPtr", 0x5341)
    DarkChecks.Clear()
    for h in PaintedDdls.Clone()
        try DllCall("comctl32\RemoveWindowSubclass", "Ptr", h, "Ptr", DdlCallback(), "UPtr", 0x5344)
    PaintedDdls.Clear()
}

DarkCheckProcBody(hWnd, uMsg, wParam, lParam, uId) {
    static selfDraw := Map(0x0F1, 1, 0x0F3, 1, 0x0F5, 1, 0x0201, 1, 0x0202, 1, 0x0203, 1, 0x000A, 1, 0x000C, 1
                         , 0x0007, 1, 0x0008, 1, 0x0100, 1, 0x0101, 1, 0x0215, 1, 0x0128, 1, 0x0200, 1, 0x02A3, 1)
    if uMsg = 0x000F {                                 ; WM_PAINT: all ours
        if DarkChecks.Has(hWnd)
            DarkChecks[hWnd].dirty := false
        ps := Buffer(A_PtrSize = 8 ? 72 : 64, 0)
        hdc := DllCall("BeginPaint", "Ptr", hWnd, "Ptr", ps, "Ptr")
        PaintDarkCheckbox(hWnd, hdc)
        DllCall("EndPaint", "Ptr", hWnd, "Ptr", ps)
        return 0
    }
    if uMsg = 0x0014                                   ; WM_ERASEBKGND: done in WM_PAINT
        return 1
    if uMsg = 0x0082 {                                 ; WM_NCDESTROY: unhook before the window goes
        DllCall("comctl32\RemoveWindowSubclass", "Ptr", hWnd, "Ptr", DarkCheckCallback(), "UPtr", uId)
        try DarkChecks.Delete(hWnd)
        return DllCall("comctl32\DefSubclassProc", "Ptr", hWnd, "UInt", uMsg, "Ptr", wParam, "Ptr", lParam, "Ptr")
    }
    if uMsg = 0x02A3 && DarkChecks.Has(hWnd)           ; WM_MOUSELEAVE: not hot any more
        DarkChecks[hWnd].hot := false
    if !selfDraw.Has(uMsg)
        return DllCall("comctl32\DefSubclassProc", "Ptr", hWnd, "UInt", uMsg, "Ptr", wParam, "Ptr", lParam, "Ptr")

    before := DllCall("SendMessageW", "Ptr", hWnd, "UInt", 0xF2, "Ptr", 0, "Ptr", 0, "Ptr")            ; BM_GETSTATE (checked / pushed / focus)
    DllCall("SendMessageW", "Ptr", hWnd, "UInt", 0x000B, "Ptr", 0, "Ptr", 0)    ; WM_SETREDRAW off
    r := DllCall("comctl32\DefSubclassProc", "Ptr", hWnd, "UInt", uMsg, "Ptr", wParam, "Ptr", lParam, "Ptr")
    DllCall("SendMessageW", "Ptr", hWnd, "UInt", 0x000B, "Ptr", 1, "Ptr", 0)    ; WM_SETREDRAW on
    changed := DllCall("SendMessageW", "Ptr", hWnd, "UInt", 0xF2, "Ptr", 0, "Ptr", 0, "Ptr") != before
    if uMsg = 0x0200 && DarkChecks.Has(hWnd) && !DarkChecks[hWnd].hot {        ; mouse entered
        DarkChecks[hWnd].hot := true
        tme := Buffer(A_PtrSize = 8 ? 24 : 16, 0)
        NumPut("UInt", tme.Size, tme, 0), NumPut("UInt", 0x2, tme, 4), NumPut("Ptr", hWnd, tme, 8)
        DllCall("TrackMouseEvent", "Ptr", tme)
        changed := true
    }
    ; A repaint is the last message Windows delivers, and switching the drawing off and on
    ; drops one that is still waiting, so a pending repaint is asked for again until done.
    if DarkChecks.Has(hWnd) && (changed || uMsg != 0x0200 || DarkChecks[hWnd].dirty) {
        DarkChecks[hWnd].dirty := true
        DllCall("InvalidateRect", "Ptr", hWnd, "Ptr", 0, "Int", 0)
    }
    return r
}

PaintDarkCheckbox(hwnd, hdcOut) {
    rc := Buffer(16, 0)
    DllCall("GetClientRect", "Ptr", hwnd, "Ptr", rc)
    w := NumGet(rc, 8, "Int"), h := NumGet(rc, 12, "Int")
    if w <= 0 || h <= 0
        return
    hdc := DllCall("CreateCompatibleDC", "Ptr", hdcOut, "Ptr")          ; off-screen, then one copy
    bmp := DllCall("CreateCompatibleBitmap", "Ptr", hdcOut, "Int", w, "Int", h, "Ptr")
    oldBmp := DllCall("SelectObject", "Ptr", hdc, "Ptr", bmp, "Ptr")

    enabled := DllCall("IsWindowEnabled", "Ptr", hwnd)
    state := DllCall("SendMessageW", "Ptr", hwnd, "UInt", 0xF2, "Ptr", 0, "Ptr", 0, "Ptr")             ; BM_GETSTATE
    checked := state & 0x3                             ; 1 ticked, 2 grey
    pushed := state & 0x4
    hot := enabled && DarkChecks.Has(hwnd) && DarkChecks[hwnd].hot

    br := DllCall("CreateSolidBrush", "UInt", HexToBgr(Th("bg")), "Ptr")
    DllCall("FillRect", "Ptr", hdc, "Ptr", rc, "Ptr", br)
    DllCall("DeleteObject", "Ptr", br)

    sc := A_ScreenDPI / 96
    bs := Round(13 * sc)
    bx := 0, by := (h - bs) // 2
    on := checked != 0
    fill := on ? Th("checkOnBg") : Th("checkBg")
    if pushed
        fill := AdjustHexColor(fill, 16)
    edge := on ? Th("checkOnBg") : (hot ? Th("text") : Th("checkBorder"))
    if !enabled {
        fill := on ? AdjustHexColor(Th("checkOnBg"), -40) : Th("btnDisBg")
        edge := Th("btnDisBorder")
    }
    box := Buffer(16, 0)
    NumPut("Int", bx, "Int", by, "Int", bx + bs, "Int", by + bs, box)
    br := DllCall("CreateSolidBrush", "UInt", HexToBgr(fill), "Ptr")
    DllCall("FillRect", "Ptr", hdc, "Ptr", box, "Ptr", br)
    DllCall("DeleteObject", "Ptr", br)
    br := DllCall("CreateSolidBrush", "UInt", HexToBgr(edge), "Ptr")
    DllCall("FrameRect", "Ptr", hdc, "Ptr", box, "Ptr", br)
    DllCall("DeleteObject", "Ptr", br)

    DllCall("SetBkMode", "Ptr", hdc, "Int", 1)         ; TRANSPARENT
    if checked = 2 {                                   ; grey state: a bar
        bar := Buffer(16, 0)
        NumPut("Int", bx + 3, "Int", by + bs // 2 - 1, "Int", bx + bs - 3, "Int", by + bs // 2 + 1, bar)
        br := DllCall("CreateSolidBrush", "UInt", HexToBgr(Th("checkMark")), "Ptr")
        DllCall("FillRect", "Ptr", hdc, "Ptr", bar, "Ptr", br)
        DllCall("DeleteObject", "Ptr", br)
    } else if checked = 1 {                            ; tick: Marlett "a"
        hMark := DllCall("CreateFontW", "Int", -(bs - 1), "Int", 0, "Int", 0, "Int", 0, "Int", 400, "UInt", 0, "UInt", 0, "UInt", 0
            , "UInt", 2, "UInt", 0, "UInt", 0, "UInt", 5, "UInt", 0, "Str", "Marlett", "Ptr")
        old := DllCall("SelectObject", "Ptr", hdc, "Ptr", hMark, "Ptr")
        DllCall("SetTextColor", "Ptr", hdc, "UInt", HexToBgr(enabled ? Th("checkMark") : Th("btnDisFg")))
        DllCall("DrawTextW", "Ptr", hdc, "Str", "a", "Int", 1, "Ptr", box, "UInt", 0x25)   ; CENTER | VCENTER | SINGLELINE
        DllCall("SelectObject", "Ptr", hdc, "Ptr", old)
        DllCall("DeleteObject", "Ptr", hMark)
    }

    len := DllCall("GetWindowTextLengthW", "Ptr", hwnd)
    if len > 0 {
        buf := Buffer((len + 1) * 2, 0)
        DllCall("GetWindowTextW", "Ptr", hwnd, "Ptr", buf, "Int", len + 1)
        hFont := DllCall("SendMessageW", "Ptr", hwnd, "UInt", 0x31, "Ptr", 0, "Ptr", 0, "Ptr")         ; WM_GETFONT
        oldF := hFont ? DllCall("SelectObject", "Ptr", hdc, "Ptr", hFont, "Ptr") : 0
        DllCall("SetTextColor", "Ptr", hdc, "UInt", HexToBgr(enabled ? Th("text") : Th("muted")))
        tr := Buffer(16, 0)
        NumPut("Int", bx + bs + Round(5 * sc), "Int", 0, "Int", w, "Int", h, tr)
        DllCall("DrawTextW", "Ptr", hdc, "Ptr", buf, "Int", len, "Ptr", tr, "UInt", 0x100024 | 0x8000)   ; VCENTER|SINGLELINE|HIDEPREFIX|END_ELLIPSIS
        if oldF
            DllCall("SelectObject", "Ptr", hdc, "Ptr", oldF, "Ptr")
    }

    DllCall("BitBlt", "Ptr", hdcOut, "Int", 0, "Int", 0, "Int", w, "Int", h, "Ptr", hdc, "Int", 0, "Int", 0, "UInt", 0x00CC0020)  ; SRCCOPY
    DllCall("SelectObject", "Ptr", hdc, "Ptr", oldBmp, "Ptr")
    DllCall("DeleteObject", "Ptr", bmp)
    DllCall("DeleteDC", "Ptr", hdc)
}

; ------------------------------ DROP-DOWN LISTS -----------------------------
; Windows' dark drop-downs draw their text in bright white whatever color they are given, so
; the closed box is painted here (ddlBg / ddlText, brighter under the mouse like the buttons)
; and the open list gets its colors through WM_CTLCOLORLISTBOX (ddlListBg / ddlText).
; The box may draw itself directly when its selection changes: it is repainted right away,
; before the screen is updated, so that never shows.
DdlSubclass(hwnd) {
    if PaintedDdls.Has(hwnd)
        return
    PaintedDdls[hwnd] := {hot: false}
    DllCall("comctl32\SetWindowSubclass", "Ptr", hwnd, "Ptr", DdlCallback(), "UPtr", 0x5344, "UPtr", 0)
    DllCall("InvalidateRect", "Ptr", hwnd, "Ptr", 0, "Int", 0)
}

DdlCallback() {
    static cb := CallbackCreate(DdlProc, "F", 6)
    return cb
}

DdlProc(hWnd, uMsg, wParam, lParam, uId, refData) {
    if !DarkChecksActive
        return DllCall("comctl32\DefSubclassProc", "Ptr", hWnd, "UInt", uMsg, "Ptr", wParam, "Ptr", lParam, "Ptr")
    try
        return DdlProcBody(hWnd, uMsg, wParam, lParam, uId)
    catch
        return DllCall("comctl32\DefSubclassProc", "Ptr", hWnd, "UInt", uMsg, "Ptr", wParam, "Ptr", lParam, "Ptr")
}

DdlProcBody(hWnd, uMsg, wParam, lParam, uId) {
    ; messages after which the box may have drawn itself: paint it again at once
    static redrawAfter := Map(0x0007, 1, 0x0008, 1, 0x000A, 1, 0x000C, 1, 0x0100, 1, 0x0101, 1, 0x0102, 1
                            , 0x0111, 1, 0x014E, 1, 0x014F, 1, 0x0201, 1, 0x0202, 1, 0x0203, 1, 0x0215, 1, 0x020A, 1)
    if uMsg = 0x000F {                                 ; WM_PAINT: all ours
        ps := Buffer(A_PtrSize = 8 ? 72 : 64, 0)
        hdc := DllCall("BeginPaint", "Ptr", hWnd, "Ptr", ps, "Ptr")
        PaintDdl(hWnd, hdc)
        DllCall("EndPaint", "Ptr", hWnd, "Ptr", ps)
        return 0
    }
    if uMsg = 0x0014                                   ; WM_ERASEBKGND: done in WM_PAINT
        return 1
    if uMsg = 0x0134 {                                 ; WM_CTLCOLORLISTBOX: the open list
        bg := Th("ddlListBg") != "" ? Th("ddlListBg") : Th("editBg")
        DllCall("SetTextColor", "Ptr", wParam, "UInt", HexToBgr(Th("ddlText") != "" ? Th("ddlText") : Th("text")))
        DllCall("SetBkColor", "Ptr", wParam, "UInt", HexToBgr(bg))
        return DdlBrush(bg)
    }
    if uMsg = 0x0082 {                                 ; WM_NCDESTROY: unhook before the window goes
        DllCall("comctl32\RemoveWindowSubclass", "Ptr", hWnd, "Ptr", DdlCallback(), "UPtr", uId)
        try PaintedDdls.Delete(hWnd)
        return DllCall("comctl32\DefSubclassProc", "Ptr", hWnd, "UInt", uMsg, "Ptr", wParam, "Ptr", lParam, "Ptr")
    }
    r := DllCall("comctl32\DefSubclassProc", "Ptr", hWnd, "UInt", uMsg, "Ptr", wParam, "Ptr", lParam, "Ptr")
    if !PaintedDdls.Has(hWnd)
        return r
    st := PaintedDdls[hWnd]
    if uMsg = 0x0200 && !st.hot {                      ; mouse entered
        st.hot := true
        tme := Buffer(A_PtrSize = 8 ? 24 : 16, 0)
        NumPut("UInt", tme.Size, tme, 0), NumPut("UInt", 0x2, tme, 4), NumPut("Ptr", hWnd, tme, 8)
        DllCall("TrackMouseEvent", "Ptr", tme)
        DdlRepaint(hWnd)
    } else if uMsg = 0x02A3 {                          ; WM_MOUSELEAVE
        st.hot := false
        DdlRepaint(hWnd)
    } else if redrawAfter.Has(uMsg) {
        DdlRepaint(hWnd)
    }
    return r
}

; A choice in the open list reaches the window, not the drop-down: repaint it then too.
OnDdlCommand(wParam, lParam, msg, hwnd) {
    if lParam && PaintedDdls.Has(lParam) && DarkChecksActive {
        code := (wParam >> 16) & 0xFFFF
        if code = 1 || code = 8 || code = 9 || code = 10        ; CBN_SELCHANGE / CLOSEUP / SELENDOK / SELENDCANCEL
            try DdlRepaint(lParam)
    }
}

DdlRepaint(hwnd) {
    DllCall("InvalidateRect", "Ptr", hwnd, "Ptr", 0, "Int", 0)
    DllCall("UpdateWindow", "Ptr", hwnd)
}

DdlBrush(hex) {
    static brushes := Map()
    if !brushes.Has(hex)
        brushes[hex] := DllCall("CreateSolidBrush", "UInt", HexToBgr(hex), "Ptr")
    return brushes[hex]
}

PaintDdl(hwnd, hdcOut) {
    rc := Buffer(16, 0)
    DllCall("GetClientRect", "Ptr", hwnd, "Ptr", rc)
    w := NumGet(rc, 8, "Int"), h := NumGet(rc, 12, "Int")
    if w <= 0 || h <= 0
        return
    hdc := DllCall("CreateCompatibleDC", "Ptr", hdcOut, "Ptr")          ; off-screen, then one copy
    bmp := DllCall("CreateCompatibleBitmap", "Ptr", hdcOut, "Int", w, "Int", h, "Ptr")
    oldBmp := DllCall("SelectObject", "Ptr", hdc, "Ptr", bmp, "Ptr")

    enabled := DllCall("IsWindowEnabled", "Ptr", hwnd)
    dropped := DllCall("SendMessageW", "Ptr", hwnd, "UInt", 0x0157, "Ptr", 0, "Ptr", 0, "Ptr")     ; CB_GETDROPPEDSTATE
    hot := enabled && PaintedDdls.Has(hwnd) && PaintedDdls[hwnd].hot
    base := Th("ddlBg") != "" ? Th("ddlBg") : Th("btnDefault")
    lift := Integer(Th("hoverLift"))
    if !enabled {
        bg := Th("btnDisBg"), fg := Th("btnDisFg"), bdr := Th("btnDisBorder")
    } else {
        bg := dropped ? AdjustHexColor(base, -(lift + 20)) : hot ? AdjustHexColor(base, -lift) : base
        fg := Th("ddlText") != "" ? Th("ddlText") : Th("text")
        bdr := (hot || dropped) && Th("hoverBorder") != "" ? Th("hoverBorder") : AdjustHexColor(base, -25)
    }
    br := DllCall("CreateSolidBrush", "UInt", HexToBgr(bg), "Ptr")
    DllCall("FillRect", "Ptr", hdc, "Ptr", rc, "Ptr", br)
    DllCall("DeleteObject", "Ptr", br)
    br := DllCall("CreateSolidBrush", "UInt", HexToBgr(bdr), "Ptr")
    DllCall("FrameRect", "Ptr", hdc, "Ptr", rc, "Ptr", br)
    DllCall("DeleteObject", "Ptr", br)

    sc := A_ScreenDPI / 96
    arrowW := Round(18 * sc)
    DllCall("SetBkMode", "Ptr", hdc, "Int", 1)         ; TRANSPARENT
    DllCall("SetTextColor", "Ptr", hdc, "UInt", HexToBgr(fg))

    ; arrow: Marlett "6"
    hMark := DllCall("CreateFontW", "Int", -Round(10 * sc), "Int", 0, "Int", 0, "Int", 0, "Int", 400, "UInt", 0, "UInt", 0, "UInt", 0
        , "UInt", 2, "UInt", 0, "UInt", 0, "UInt", 5, "UInt", 0, "Str", "Marlett", "Ptr")
    old := DllCall("SelectObject", "Ptr", hdc, "Ptr", hMark, "Ptr")
    ar := Buffer(16, 0)
    NumPut("Int", w - arrowW, "Int", 0, "Int", w - 2, "Int", h, ar)
    DllCall("DrawTextW", "Ptr", hdc, "Str", "6", "Int", 1, "Ptr", ar, "UInt", 0x25)   ; CENTER | VCENTER | SINGLELINE
    DllCall("SelectObject", "Ptr", hdc, "Ptr", old)
    DllCall("DeleteObject", "Ptr", hMark)

    ; the chosen entry
    sel := DllCall("SendMessageW", "Ptr", hwnd, "UInt", 0x0147, "Ptr", 0, "Ptr", 0, "Ptr")         ; CB_GETCURSEL
    if sel >= 0 {
        len := DllCall("SendMessageW", "Ptr", hwnd, "UInt", 0x0149, "Ptr", sel, "Ptr", 0, "Ptr")  ; CB_GETLBTEXTLEN
        if len > 0 {
            buf := Buffer((len + 1) * 2, 0)
            DllCall("SendMessageW", "Ptr", hwnd, "UInt", 0x0148, "Ptr", sel, "Ptr", buf, "Ptr")   ; CB_GETLBTEXT
            hFont := DllCall("SendMessageW", "Ptr", hwnd, "UInt", 0x31, "Ptr", 0, "Ptr", 0, "Ptr") ; WM_GETFONT
            oldF := hFont ? DllCall("SelectObject", "Ptr", hdc, "Ptr", hFont, "Ptr") : 0
            tr := Buffer(16, 0)
            NumPut("Int", Round(6 * sc), "Int", 0, "Int", w - arrowW, "Int", h, tr)
            DllCall("DrawTextW", "Ptr", hdc, "Ptr", buf, "Int", len, "Ptr", tr, "UInt", 0x8824)  ; VCENTER|SINGLELINE|NOPREFIX|END_ELLIPSIS
            if oldF
                DllCall("SelectObject", "Ptr", hdc, "Ptr", oldF, "Ptr")
        }
    }

    DllCall("BitBlt", "Ptr", hdcOut, "Int", 0, "Int", 0, "Int", w, "Int", h, "Ptr", hdc, "Int", 0, "Int", 0, "UInt", 0x00CC0020)  ; SRCCOPY
    DllCall("SelectObject", "Ptr", hdc, "Ptr", oldBmp, "Ptr")
    DllCall("DeleteObject", "Ptr", bmp)
    DllCall("DeleteDC", "Ptr", hdc)
}

; ------------------------------ CHANGE ONLY WHEN DIFFERENT -------------------
; Setting a control to what it already shows still repaints it, and many refreshes run
; after every button: these change a control only when the new state differs (no flicker).
SetCtrlText(ctrl, txt) {
    if ctrl.Text != txt
        ctrl.Text := txt
}
SetCtrlValue(ctrl, v) {
    if ctrl.Value != v
        ctrl.Value := v
}
SetCtrlEnabled(ctrl, on) {
    on := on ? 1 : 0
    if ctrl.Enabled != on
        ctrl.Enabled := on
}
SetCtrlColor(ctrl, hex) {                              ; text color ("RRGGBB")
    if CtrlColorCache.Get(ctrl.Hwnd, "") != hex {
        ctrl.Opt("c" hex)
        CtrlColorCache[ctrl.Hwnd] := hex
    }
}
; Refills a drop-down list only when its entries change; otherwise just moves the selection.
SetDdlItems(ddl, labels, chosenIdx) {
    key := ""
    for l in labels
        key .= l "`n"
    if DdlItemCache.Get(ddl.Hwnd, "") == key && SendMessage(0x146, 0, 0, ddl) = labels.Length {   ; CB_GETCOUNT
        if ddl.Value != chosenIdx
            ddl.Choose(chosenIdx)
        return
    }
    ddl.Delete()
    ddl.Add(labels)
    ddl.Choose(chosenIdx)
    DdlItemCache[ddl.Hwnd] := key
}

AddColoredButton(guiObj, opts, text, colorHex := "") {
    guiObj.SetFont("cDefault")
    btn := guiObj.AddButton(opts, text)
    SetButtonColor(btn, colorHex)
    guiObj.SetFont("c" Th("text"))     ; "cDefault" above would leave later labels black
    return btn
}

SetButtonColor(btn, bgHex := "", fgHex := "", borderHex := "") {
    if !IsObject(btn)
        return

    clean := NormalizeHexColor(bgHex)
    if clean = "" {
        MapDel(BtnColorMap, btn.Hwnd)
        btn.Redraw()
        return
    }

    isLight := GetAutoContrastHex(clean) = "111111"
    autoFg := (fgHex != "") ? NormalizeHexColor(fgHex) : ButtonTextColor(isLight)
    if autoFg = ""
        autoFg := "FFFFFF"
    autoBdr := (borderHex != "") ? NormalizeHexColor(borderHex) : AdjustHexColor(clean, isLight ? -45 : -25)

    if BtnColorMap.Has(btn.Hwnd) {                     ; same colors: no repaint (avoids flicker)
        cur := BtnColorMap[btn.Hwnd]
        if cur.bg = clean && cur.fg = autoFg && cur.border = autoBdr
            return
    }
    BtnColorMap[btn.Hwnd] := {
        ctrl: btn,
        bg: clean,
        fg: autoFg,
        border: autoBdr
    }
    btn.Redraw()
}

OnWmNotify(wParam, lParam, msg, hwnd) {
    if NumGet(lParam, A_PtrSize * 2, "Int") != -12 ; NM_CUSTOMDRAW
        return
    ctrlHwnd := NumGet(lParam, 0, "Ptr")
    if ThemedLVs.Has(ctrlHwnd)
        return DrawThemedListRow(lParam, ctrlHwnd)
    if DarkChecks.Has(ctrlHwnd)                        ; painted by its subclass (DarkCheckProc)
        return 0x4                                     ; CDRF_SKIPDEFAULT, should this ever arrive
    if !BtnColorMap.Has(ctrlHwnd)
        return

    stage := NumGet(lParam, (A_PtrSize = 8) ? 24 : 12, "UInt")
    if stage != 1 ; CDDS_PREPAINT
        return 0

    cfg   := BtnColorMap[ctrlHwnd]
    ctrl  := cfg.ctrl
    hdc   := NumGet(lParam, (A_PtrSize = 8) ? 32 : 16, "Ptr")
    rcPtr := lParam + ((A_PtrSize = 8) ? 40 : 20)
    state := NumGet(lParam, (A_PtrSize = 8) ? 64 : 40, "UInt")

    isDisabled := !ctrl.Enabled || (state & 0x4) ; CDIS_DISABLED
    isPressed  := (state & 0x1)                  ; CDIS_SELECTED
    isFocused  := (state & 0x10)                 ; CDIS_FOCUS
    isHover    := (ctrlHwnd = HoveredBtnHwnd) || (state & 0x40) ; CDIS_HOT

    if isDisabled {
        bg := Th("btnDisBg"), fg := Th("btnDisFg"), bdr := Th("btnDisBorder")
    } else if isPressed {
        ; every button: a bit darker still than on hover
        bg := AdjustHexColor(cfg.bg, -(Integer(Th("hoverLift")) + 20)), fg := cfg.fg, bdr := cfg.border
    } else if isHover {
        ; every button gets darker by hoverLift (THEME)
        bg := AdjustHexColor(cfg.bg, -Integer(Th("hoverLift")))
        fg := cfg.fg
        bdr := Th("hoverBorder") != "" ? Th("hoverBorder") : cfg.border
    } else {
        bg := cfg.bg, fg := cfg.fg, bdr := cfg.border
    }

    hBg := DllCall("CreateSolidBrush", "UInt", HexToBgr(bg), "Ptr")
    DllCall("FillRect", "Ptr", hdc, "Ptr", rcPtr, "Ptr", hBg)
    DllCall("DeleteObject", "Ptr", hBg)

    hBdr := DllCall("CreateSolidBrush", "UInt", HexToBgr(bdr), "Ptr")
    DllCall("FrameRect", "Ptr", hdc, "Ptr", rcPtr, "Ptr", hBdr)
    DllCall("DeleteObject", "Ptr", hBdr)

    hFont := SendMessage(0x0031, 0, 0, ctrlHwnd) ; WM_GETFONT
    oldFont := hFont ? DllCall("SelectObject", "Ptr", hdc, "Ptr", hFont, "Ptr") : 0

    rcTxt := Buffer(16, 0)
    NumPut("Int", NumGet(rcPtr, 0, "Int") + (isPressed ? 1 : 0), rcTxt, 0)
    NumPut("Int", NumGet(rcPtr, 4, "Int") + (isPressed ? 1 : 0), rcTxt, 4)
    NumPut("Int", NumGet(rcPtr, 8, "Int") + (isPressed ? 1 : 0), rcTxt, 8)
    NumPut("Int", NumGet(rcPtr, 12, "Int") + (isPressed ? 1 : 0), rcTxt, 12)

    DllCall("SetBkMode", "Ptr", hdc, "Int", 1) ; TRANSPARENT
    DllCall("SetTextColor", "Ptr", hdc, "UInt", HexToBgr(fg))
    DllCall("DrawTextW", "Ptr", hdc, "WStr", ctrl.Text, "Int", -1, "Ptr", rcTxt.Ptr, "UInt", 0x25) ; DT_CENTER | DT_VCENTER | DT_SINGLELINE

    if oldFont
        DllCall("SelectObject", "Ptr", hdc, "Ptr", oldFont)

    ; focus outline only after the keyboard was used (Tab), in the text color
    if isFocused && !isDisabled && (state & 0x200) {   ; CDIS_SHOWKEYBOARDCUES
        rcFoc := Buffer(16, 0)
        NumPut("Int", NumGet(rcPtr, 0, "Int") + 3, rcFoc, 0)
        NumPut("Int", NumGet(rcPtr, 4, "Int") + 3, rcFoc, 4)
        NumPut("Int", NumGet(rcPtr, 8, "Int") - 3, rcFoc, 8)
        NumPut("Int", NumGet(rcPtr, 12, "Int") - 3, rcFoc, 12)
        hFoc := DllCall("CreateSolidBrush", "UInt", HexToBgr(fg), "Ptr")
        DllCall("FrameRect", "Ptr", hdc, "Ptr", rcFoc.Ptr, "Ptr", hFoc)
        DllCall("DeleteObject", "Ptr", hFoc)
    }

    return 4 ; CDRF_SKIPDEFAULT
}
OnWmMouseMove(wParam, lParam, msg, hwnd) {
    global HoveredBtnHwnd
    HoverTipCheck(hwnd)
    if BtnColorMap.Has(hwnd) {
        if HoveredBtnHwnd != hwnd {
            prev := HoveredBtnHwnd
            HoveredBtnHwnd := hwnd
            if prev
                DllCall("InvalidateRect", "Ptr", prev, "Ptr", 0, "Int", 0)
            DllCall("InvalidateRect", "Ptr", hwnd, "Ptr", 0, "Int", 0)

            tme := Buffer(A_PtrSize = 8 ? 24 : 16, 0)
            NumPut("UInt", tme.Size, tme, 0)
            NumPut("UInt", 0x2, tme, 4) ; TME_LEAVE
            NumPut("Ptr", hwnd, tme, 8)
            DllCall("TrackMouseEvent", "Ptr", tme.Ptr)
        }
    } else if HoveredBtnHwnd != 0 {
        prev := HoveredBtnHwnd
        HoveredBtnHwnd := 0
        DllCall("InvalidateRect", "Ptr", prev, "Ptr", 0, "Int", 0)
    }
    if ThemedLVs.Has(hwnd)
        return ListHoverMove(hwnd, lParam)
}

OnWmMouseLeave(wParam, lParam, msg, hwnd) {
    global HoveredBtnHwnd
    if HoveredBtnHwnd = hwnd {
        HoveredBtnHwnd := 0
        DllCall("InvalidateRect", "Ptr", hwnd, "Ptr", 0, "Int", 0)
    }
    if ListHotRow.Get(hwnd, -1) >= 0 {
        old := ListHotRow[hwnd]
        ListHotRow[hwnd] := -1
        SendMessage(0x1015, old, old, hwnd)        ; LVM_REDRAWITEMS
    }
}

; The tables draw their own hover row in both themes (rowHover; a colored row gets darker,
; like the buttons). The message is not passed on, so the dark list style does not paint
; its own hover over the row colors.
ListHoverMove(hLv, lParam) {
    x := lParam & 0xFFFF, y := (lParam >> 16) & 0xFFFF
    x := x > 0x7FFF ? x - 0x10000 : x, y := y > 0x7FFF ? y - 0x10000 : y
    ht := Buffer(24, 0)                            ; LVHITTESTINFO
    NumPut("Int", x, "Int", y, ht)
    row := SendMessage(0x1012, 0, ht.Ptr, hLv)     ; LVM_HITTEST
    row := (row = 0xFFFFFFFF || row = -1 || row > 0x7FFFFFFF) ? -1 : row
    old := ListHotRow.Get(hLv, -1)
    if row != old {
        ListHotRow[hLv] := row
        if old >= 0
            SendMessage(0x1015, old, old, hLv)     ; LVM_REDRAWITEMS
        if row >= 0
            SendMessage(0x1015, row, row, hLv)
        if ListRowTips.Has(hLv) {                  ; this row's full names as the list's tooltip
            ToolTip(, , , 5)
            if (t := ListRowTips[hLv].Get(row, "")) != "" {
                HoverTips[hLv] := t
                SetTimer(HoverTipShow.Bind(hLv), -600)
            } else if HoverTips.Has(hLv) {
                HoverTips.Delete(hLv)
            }
        }
        tme := Buffer(A_PtrSize = 8 ? 24 : 16, 0)
        NumPut("UInt", tme.Size, tme, 0)
        NumPut("UInt", 0x2, tme, 4)                ; TME_LEAVE
        NumPut("Ptr", hLv, tme, 8)
        DllCall("TrackMouseEvent", "Ptr", tme.Ptr)
    }
    return 0
}

NormalizeHexColor(hex) {
    static named := Map(
        "BLACK", "000000", "WHITE", "FFFFFF", "RED", "DC2626",
        "GREEN", "15803D", "BLUE", "1E40AF", "GRAY", "4B5563",
        "GREY", "4B5563", "ORANGE", "D97706", "YELLOW", "EAB308"
    )
    s := Trim(String(hex))
    if s = ""
        return ""
    if named.Has(StrUpper(s))
        return named[StrUpper(s)]
    s := RegExReplace(s, "^(?:#|0x)", "")
    if RegExMatch(s, "^([0-9A-Fa-f])([0-9A-Fa-f])([0-9A-Fa-f])$", &m)
        return StrUpper(m[1] m[1] m[2] m[2] m[3] m[3])
    return RegExMatch(s, "^[0-9A-Fa-f]{6}$") ? StrUpper(s) : ""
}

; Button text: btnText on dark buttons ("" = text), btnTextLight on light ones.
ButtonTextColor(isLight) {
    if isLight
        return Th("btnTextLight") != "" ? Th("btnTextLight") : "111111"
    return Th("btnText") != "" ? Th("btnText") : Th("text")
}

GetAutoContrastHex(hex) {
    c := Integer("0x" hex)
    r := (c >> 16) & 0xFF
    g := (c >> 8) & 0xFF
    b := c & 0xFF
    luma := (r * 299 + g * 587 + b * 114) // 1000
    return (luma > 150) ? "111111" : "FFFFFF"
}

; NM_CUSTOMDRAW for a ListView (both themes). Text, row and selection colors come from
; the palette (text / listBg / selText / selBg), so the selected row looks the same whether
; or not its list has focus. In dark mode grid lines are drawn too, in gridLine.
; Every row is drawn by DrawListRowOwn (both themes), grid lines afterwards.
DrawThemedListRow(lParam, hLv) {
    Critical
    x64 := (A_PtrSize = 8)
    stage := NumGet(lParam, x64 ? 24 : 12, "UInt")
    if stage = 0x1                                     ; CDDS_PREPAINT
        return 0x20 | 0x10                             ; CDRF_NOTIFYITEMDRAW | CDRF_NOTIFYPOSTPAINT
    if stage = 0x10001 {                               ; CDDS_ITEMPREPAINT: the whole row is drawn here
        item := NumGet(lParam, x64 ? 56 : 36, "UPtr")
        hdc := NumGet(lParam, x64 ? 32 : 16, "Ptr")
        return DrawListRowOwn(hLv, hdc, item) ? 0x4 : 0    ; CDRF_SKIPDEFAULT (or let Windows draw it)
    }
    if stage = 0x2 {                                   ; CDDS_POSTPAINT: grid lines (both themes)
        DrawListGrid(NumGet(lParam, x64 ? 32 : 16, "Ptr"), hLv)
        return 0
    }
    return 0
}

; Draws one table row completely: background, checkbox and the text of every column.
; Windows' dark list style paints selected / hovered rows its own way and ignores the
; colors it is given, so the rows are not left to it at all.
;   normal row   : listBg / text, rowHover under the mouse
;   selected row : selBg / selText
;   colored row  : its own color (LvRowColors, e.g. an app whose override is on), darker
;                  under the mouse, ovrRowText (or black / white)
;   selected colored row : selBg, text in selOvrText (its own color when ""), and a strip
;                  of its own color on the left edge (selOvrStrip px)
DrawListRowOwn(hLv, hdc, item) {
    rc := Buffer(16, 0)                                ; left = 0 -> LVIR_BOUNDS
    if !SendMessage(0x100E, item, rc.Ptr, hLv)         ; LVM_GETITEMRECT
        return false
    sel := SendMessage(0x102C, item, 0x2, hLv) & 0x2   ; LVM_GETITEMSTATE / LVIS_SELECTED
    hot := (ListHotRow.Get(hLv, -1) = item)
    own := ListRowColor(hLv, item)
    ; Each kind of row has its own background, text, hover lift and hover text (THEME maps):
    ;   override on : BtnColorAppOvrOn / ovrRowText / ovrRowHoverLift / ovrRowHoverText
    ;   selected    : selBg            / selText    / selHoverLift    / selHoverText
    ;   both        : selBg            / selOvrText / selHoverLift    / selHoverText, + strip
    ;   normal      : rowBg (listBg)   / rowText (text) / rowHoverLift / rowHoverText
    ; A lift darkens the background under the mouse (negative = brighter, 0 = no change);
    ; an empty hover text keeps the row's own text color.
    if own != "" && sel {
        base := Th("selBg"), lift := Th("selHoverLift"), hTxt := Th("selHoverText")
        txt := Th("selOvrText") != "" ? Th("selOvrText") : own
    } else if own != "" {
        base := own, lift := Th("ovrRowHoverLift"), txt := Th("ovrRowText"), hTxt := Th("ovrRowHoverText")
    } else if sel {
        base := Th("selBg"), lift := Th("selHoverLift"), txt := Th("selText"), hTxt := Th("selHoverText")
    } else {
        base := Th("rowBg") != "" ? Th("rowBg") : Th("listBg")
        lift := Th("rowHoverLift"), hTxt := Th("rowHoverText")
        txt := Th("rowText") != "" ? Th("rowText") : Th("text")
    }
    bg := (hot && IsNumber(lift) && lift != 0) ? AdjustHexColor(base, -Integer(lift)) : base
    if hot && hTxt != ""
        fg := hTxt
    else
        fg := txt != "" ? txt : GetAutoContrastHex(bg)          ; ovrRowText "" = black or white
    br := DllCall("CreateSolidBrush", "UInt", HexToBgr(bg), "Ptr")
    DllCall("FillRect", "Ptr", hdc, "Ptr", rc, "Ptr", br)
    DllCall("DeleteObject", "Ptr", br)
    stripW := Th("selOvrStrip")
    if sel && own != "" && IsInteger(stripW) && stripW > 0 {   ; selected colored row: strip in its own color
        fr := Buffer(16, 0)
        DllCall("RtlMoveMemory", "Ptr", fr, "Ptr", rc, "UPtr", 16)
        NumPut("Int", NumGet(rc, 0, "Int") + Integer(stripW), fr, 8)
        br := DllCall("CreateSolidBrush", "UInt", HexToBgr(own), "Ptr")
        DllCall("FillRect", "Ptr", hdc, "Ptr", fr, "Ptr", br)
        DllCall("DeleteObject", "Ptr", br)
    }

    ; checkbox (the list's own state images, so it keeps the theme's look)
    if SendMessage(0x1037, 0, 0, hLv) & 0x4 {         ; LVM_GETEXTENDEDLISTVIEWSTYLE / LVS_EX_CHECKBOXES
        himl := SendMessage(0x1002, 2, 0, hLv)         ; LVM_GETIMAGELIST(LVSIL_STATE)
        stImg := (SendMessage(0x102C, item, 0xF000, hLv) >> 12) & 0xF
        if himl && stImg {
            cw := 0, ch := 0
            DllCall("comctl32\ImageList_GetIconSize", "Ptr", himl, "Int*", &cw, "Int*", &ch)
            ic := Buffer(16, 0)
            NumPut("Int", 1, ic, 0)                    ; LVIR_ICON: the state image sits just left of it
            SendMessage(0x100E, item, ic.Ptr, hLv)
            ix := NumGet(ic, 0, "Int") - cw
            iy := NumGet(ic, 4, "Int") + (NumGet(ic, 12, "Int") - NumGet(ic, 4, "Int") - ch) // 2
            DllCall("comctl32\ImageList_Draw", "Ptr", himl, "Int", stImg - 1, "Ptr", hdc, "Int", ix, "Int", iy, "UInt", 1)
        }
    }

    ; text of every column, in the list's font
    hFont := SendMessage(0x31, 0, 0, hLv)              ; WM_GETFONT
    oldFont := hFont ? DllCall("SelectObject", "Ptr", hdc, "Ptr", hFont, "Ptr") : 0
    DllCall("SetBkMode", "Ptr", hdc, "Int", 1)         ; TRANSPARENT
    DllCall("SetTextColor", "Ptr", hdc, "UInt", HexToBgr(fg))
    hHdr := SendMessage(0x101F, 0, 0, hLv)             ; LVM_GETHEADER
    cols := hHdr ? SendMessage(0x1200, 0, 0, hHdr) : 1 ; HDM_GETITEMCOUNT
    buf := Buffer(1024, 0)
    lvi := Buffer(A_PtrSize = 8 ? 88 : 60, 0)          ; LVITEMW
    sr := Buffer(16, 0)
    Loop cols {
        c := A_Index - 1
        NumPut("Int", c, lvi, 8)                                       ; iSubItem
        NumPut("Ptr", buf.Ptr, lvi, A_PtrSize = 8 ? 24 : 20)           ; pszText
        NumPut("Int", 511, lvi, A_PtrSize = 8 ? 32 : 24)               ; cchTextMax
        n := SendMessage(0x1073, item, lvi.Ptr, hLv)                   ; LVM_GETITEMTEXTW
        if n <= 0
            continue
        NumPut("Int", c = 0 ? 2 : 0, "Int", c, sr)                     ; LVIR_LABEL for column 0, LVIR_BOUNDS for the others
        if !SendMessage(0x1038, item, sr.Ptr, hLv)                     ; LVM_GETSUBITEMRECT
            continue
        NumPut("Int", NumGet(sr, 0, "Int") + (c = 0 ? 2 : 6), sr, 0)   ; same padding as Windows
        NumPut("Int", NumGet(sr, 8, "Int") - 4, sr, 8)
        DllCall("DrawTextW", "Ptr", hdc, "Ptr", buf, "Int", n, "Ptr", sr, "UInt", 0x8824)   ; VCENTER|SINGLELINE|NOPREFIX|END_ELLIPSIS
    }
    if oldFont
        DllCall("SelectObject", "Ptr", hdc, "Ptr", oldFont, "Ptr")
    return true
}

; Own background color of a list row ("" = the normal colors).
ListRowColor(hLv, item) {
    return (LvRowColors.Has(hLv) && LvRowColors[hLv].Has(item)) ? LvRowColors[hLv][item] : ""
}

; Grid lines in gridLine over the whole list (both themes). The empty part below the last
; row is painted first, so Windows' own lines there do not show next to these.
DrawListGrid(hdc, hLv) {
    rc := Buffer(16, 0)
    DllCall("GetClientRect", "Ptr", hLv, "Ptr", rc)
    cliR := NumGet(rc, 8, "Int"), cliB := NumGet(rc, 12, "Int")
    cnt := SendMessage(0x1004, 0, 0, hLv)              ; LVM_GETITEMCOUNT
    emptyTop := 0
    if cnt > 0 {
        lr := Buffer(16, 0)                            ; left = 0 -> LVIR_BOUNDS
        if SendMessage(0x100E, cnt - 1, lr.Ptr, hLv)   ; last row
            emptyTop := Max(0, NumGet(lr, 12, "Int"))
    }
    if emptyTop < cliB {
        er := Buffer(16, 0)
        NumPut("Int", 0, "Int", emptyTop, "Int", cliR, "Int", cliB, er)
        bg := DllCall("CreateSolidBrush", "UInt", HexToBgr(Th("listBg")), "Ptr")
        DllCall("FillRect", "Ptr", hdc, "Ptr", er, "Ptr", bg)
        DllCall("DeleteObject", "Ptr", bg)
    }
    top := 0
    hHdr := SendMessage(0x101F, 0, 0, hLv)            ; LVM_GETHEADER
    if hHdr && DllCall("IsWindowVisible", "Ptr", hHdr) {
        hr := Buffer(16, 0)
        DllCall("GetWindowRect", "Ptr", hHdr, "Ptr", hr)
        top := NumGet(hr, 12, "Int") - NumGet(hr, 4, "Int")
    }
    originX := 0, rowY := 0, rowH := 0
    if SendMessage(0x1004, 0, 0, hLv) > 0 {           ; LVM_GETITEMCOUNT
        ir := Buffer(16, 0)                            ; left = 0 -> LVIR_BOUNDS
        if SendMessage(0x100E, SendMessage(0x1027, 0, 0, hLv), ir.Ptr, hLv) {   ; LVM_GETITEMRECT(LVM_GETTOPINDEX)
            originX := NumGet(ir, 0, "Int")
            rowY := NumGet(ir, 12, "Int")
            rowH := rowY - NumGet(ir, 4, "Int")
        }
    }
    ln := Buffer(16, 0)
    if Th("gridLineV") != "" {                        ; column lines ("" = none)
        brV := DllCall("CreateSolidBrush", "UInt", HexToBgr(Th("gridLineV")), "Ptr")
        x := originX
        Loop hHdr ? SendMessage(0x1200, 0, 0, hHdr) : 0 {  ; HDM_GETITEMCOUNT
            x += SendMessage(0x101D, A_Index - 1, 0, hLv) ; LVM_GETCOLUMNWIDTH
            NumPut("Int", x - 1, "Int", top, "Int", x, "Int", cliB, ln)
            DllCall("FillRect", "Ptr", hdc, "Ptr", ln, "Ptr", brV)
        }
        DllCall("DeleteObject", "Ptr", brV)
    }
    br := DllCall("CreateSolidBrush", "UInt", HexToBgr(Th("gridLine")), "Ptr")
    if rowH > 0 {
        y := rowY
        while y <= cliB {
            NumPut("Int", 0, "Int", y - 1, "Int", cliR, "Int", y, ln)
            DllCall("FillRect", "Ptr", hdc, "Ptr", ln, "Ptr", br)
            y += rowH
        }
    }
    DllCall("DeleteObject", "Ptr", br)
}

HexToBgr(hex) {
    c := Integer("0x" hex)
    return ((c & 0xFF) << 16) | (c & 0xFF00) | ((c >> 16) & 0xFF)
}

AdjustHexColor(hex, delta) {
    c := Integer("0x" hex)
    r := Max(0, Min(255, ((c >> 16) & 0xFF) + delta))
    g := Max(0, Min(255, ((c >> 8) & 0xFF) + delta))
    b := Max(0, Min(255, (c & 0xFF) + delta))
    return Format("{:02X}{:02X}{:02X}", r, g, b)
}
