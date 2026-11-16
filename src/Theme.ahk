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
    for k in ThemeKeys {
        ThemeColors["light"][k] := String(THEME_LIGHT.Get(k, "FF00FF"))
        ThemeColors["dark"][k] := String(THEME_DARK.Get(k, "FF00FF"))
    }
}


ThemeIniValue(v) {
    return v = "" ? "none" : v
}

Th(key) {
    return ThemeColors[DarkTheme ? "dark" : "light"].Get(key, "FF00FF")
}

OsBuild() {
    return RegExMatch(A_OSVersion, "\.(\d+)$", &m) ? Integer(m[1]) : 0
}

; Gives "default" buttons the theme's button color. Only buttons still set to
; ColorDefault change; a button you gave its own color (e.g. Color10) keeps it.
ApplyTheme() {
    global ColorDefault
    global BtnColorMonOvrOff, BtnColorAppOvrOff, BtnColorDetect, BtnColorRefresh, BtnColorIdentifyMons, BtnColorRemoveApp, BtnColorResetAppOvr, BtnColorFixConflicts, BtnColorQuickActions, BtnColorHkSet, BtnColorHkClear, BtnColorHkReset, BtnColorResetOverrides, BtnColorResetWinMixer, BtnColorDetectWinDetect, BtnColorDetectWinAdd, BtnColorDetectWinClose
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
            DllCall(fnSet, "Int", DarkTheme ? 2 : 3)    ; ForceDark / ForceLight
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
    native := DarkTheme && build >= 18362
    try {
        if build >= 17763 {
            v := DarkTheme ? 1 : 0
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
                if DarkTheme {
                    ctrl.Opt("-Grid")                           ; native grid lines are bright; drawn subtly instead
                    lists.Push(ctrl)
                }
            } else if native && (t = "DDL" || t = "ComboBox") {
                DllCall("uxtheme\SetWindowTheme", "Ptr", hwnd, "Str", "DarkMode_CFD", "Ptr", 0)
            } else if t = "GroupBox" {
                groups.Push(ctrl)                               ; replaced by DrawGroupFrame below (both themes)
            } else if DarkTheme && (t = "CheckBox" || t = "Radio") {
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

; Dark mode: the native list header cannot be recolored. It is hidden, the list is
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

OnDarkThemeChanged(*) {
    global DarkTheme
    DarkTheme := (ChkDarkTheme.Value = 1)
    ApplyTheme()
    SaveSettings()
    SetTimer(RebuildForTheme, -20)       ; rebuild outside the check box's own event
}

RebuildForTheme() {
    global GuiDirty
    if IsObject(DetectWindow)
        CloseDetectWindow()               ; reopens in the new theme
    GuiDirty := true
    RebuildMainGuiIfNeeded(true)
}

; ------------------------------ COLOR BUTTONS -------------------------------
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

    autoFg := (fgHex != "") ? NormalizeHexColor(fgHex) : GetAutoContrastHex(clean)
    if autoFg = ""
        autoFg := "FFFFFF"
    autoBdr := (borderHex != "") ? NormalizeHexColor(borderHex) : AdjustHexColor(clean, autoFg = "111111" ? -45 : -25)

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

    if isFocused && !isDisabled {
        rcFoc := Buffer(16, 0)
        NumPut("Int", NumGet(rcPtr, 0, "Int") + 3, rcFoc, 0)
        NumPut("Int", NumGet(rcPtr, 4, "Int") + 3, rcFoc, 4)
        NumPut("Int", NumGet(rcPtr, 8, "Int") - 3, rcFoc, 8)
        NumPut("Int", NumGet(rcPtr, 12, "Int") - 3, rcFoc, 12)
        DllCall("DrawFocusRect", "Ptr", hdc, "Ptr", rcFoc.Ptr)
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
}

OnWmMouseLeave(wParam, lParam, msg, hwnd) {
    global HoveredBtnHwnd
    if HoveredBtnHwnd = hwnd {
        HoveredBtnHwnd := 0
        DllCall("InvalidateRect", "Ptr", hwnd, "Ptr", 0, "Int", 0)
    }
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
DrawThemedListRow(lParam, hLv) {
    Critical
    x64 := (A_PtrSize = 8)
    stage := NumGet(lParam, x64 ? 24 : 12, "UInt")
    if stage = 0x1                                     ; CDDS_PREPAINT
        return 0x20 | 0x10                             ; CDRF_NOTIFYITEMDRAW | CDRF_NOTIFYPOSTPAINT
    if stage = 0x10001 {                               ; CDDS_ITEMPREPAINT
        item := NumGet(lParam, x64 ? 56 : 36, "UPtr")
        stateOff := x64 ? 64 : 40
        sel := SendMessage(0x102C, item, 0x2, hLv) & 0x2      ; LVM_GETITEMSTATE / LVIS_SELECTED
        ; drop SELECTED | FOCUS | HOT so Windows does not paint its own highlight over ours
        NumPut("UInt", NumGet(lParam, stateOff, "UInt") & ~0x51, lParam, stateOff)
        NumPut("UInt", HexToBgr(Th(sel ? "selText" : "text")), lParam, x64 ? 80 : 48)    ; clrText
        NumPut("UInt", HexToBgr(Th(sel ? "selBg" : "listBg")), lParam, x64 ? 84 : 52)    ; clrTextBk
        return 0x2 | 0x10                              ; CDRF_NEWFONT | CDRF_NOTIFYPOSTPAINT
    }
    if stage = 0x10002 {                               ; CDDS_ITEMPOSTPAINT
        ; the dark theme still frames the selected / focused row in bright blue:
        ; paint a 2 px edge in the row's own color over that frame
        item := NumGet(lParam, x64 ? 56 : 36, "UPtr")
        st := SendMessage(0x102C, item, 0x3, hLv)      ; LVM_GETITEMSTATE: LVIS_FOCUSED | LVIS_SELECTED
        if st {
            rc := Buffer(16, 0)                        ; left = 0 -> LVIR_BOUNDS
            if SendMessage(0x100E, item, rc.Ptr, hLv) {
                hdc := NumGet(lParam, x64 ? 32 : 16, "Ptr")
                br := DllCall("CreateSolidBrush", "UInt", HexToBgr(Th((st & 0x2) ? "selBg" : "listBg")), "Ptr")
                Loop 2 {
                    DllCall("FrameRect", "Ptr", hdc, "Ptr", rc, "Ptr", br)
                    DllCall("InflateRect", "Ptr", rc, "Int", -1, "Int", -1)
                }
                DllCall("DeleteObject", "Ptr", br)
            }
        }
        return 0
    }
    if stage = 0x2 {                                   ; CDDS_POSTPAINT (light mode keeps the native grid)
        if DarkTheme
            DrawListGrid(NumGet(lParam, x64 ? 32 : 16, "Ptr"), hLv)
        return 0
    }
    return 0
}

DrawListGrid(hdc, hLv) {
    rc := Buffer(16, 0)
    DllCall("GetClientRect", "Ptr", hLv, "Ptr", rc)
    cliR := NumGet(rc, 8, "Int"), cliB := NumGet(rc, 12, "Int")
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
    br := DllCall("CreateSolidBrush", "UInt", HexToBgr(Th("gridLine")), "Ptr")
    ln := Buffer(16, 0)
    x := originX
    Loop hHdr ? SendMessage(0x1200, 0, 0, hHdr) : 0 {  ; HDM_GETITEMCOUNT
        x += SendMessage(0x101D, A_Index - 1, 0, hLv) ; LVM_GETCOLUMNWIDTH
        NumPut("Int", x - 1, "Int", top, "Int", x, "Int", cliB, ln)
        DllCall("FillRect", "Ptr", hdc, "Ptr", ln, "Ptr", br)
    }
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
