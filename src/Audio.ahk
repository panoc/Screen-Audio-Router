; Screen Audio Router - Copyright (C) 2026 panoc
; Licensed under the GNU GPL v3 or later. See LICENSE.
; ============================================================================
; Screen Audio Router  -  src\Audio.ahk
; Native audio (device list, per-app routing), SoundVolumeView fallback, mixer reset
; Part of ScreenAudioRouter.ahk (included at its end). Functions only.
; ============================================================================

; ------------------------------ WINDOWS VOLUME MIXER RESET ------------------
ResetWindowsVolumeMixer(*) {
    global AllMode, AllMonitorsMode
    res := MsgBox(
        "Reset all Windows per-app sound devices in the Volume Mixer back to Default, clear active overrides, and deactivate Routing until you activate it again?`n`n"
        . "Existing application volume levels and mute states will NOT be changed.",
        "Reset Windows Mixer",
        "YesNo Icon?"
    )
    if res != "Yes"
        return

    Tip("Resetting Windows Mixer devices & deactivating routing...")

    ; 1. Clear Windows 10/11 per-app Audio DefaultEndpoint & PolicyConfig registry stores (device routing only)
    regPaths := [
        "HKEY_CURRENT_USER\Software\Microsoft\Multimedia\Audio\DefaultEndpoint",
        "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Audio\PolicyConfig\PropertyStore",
        "HKEY_CURRENT_USER\Software\Microsoft\Internet Explorer\LowRegistry\Audio\PolicyConfig\PropertyStore"
    ]
    for rp in regPaths {
        subkeys := []
        try {
            Loop Reg, rp, "K" {
                subkeys.Push(rp "\" A_LoopRegName)
            }
        }
        for sk in subkeys {
            try RegDeleteKey(sk)
        }
    }

    ; 2. Reset all app device assignments (volumes untouched): natively in one call (beta),
    ;    otherwise with SoundVolumeView per app
    nativeReset := false
    if NativeAudio && IsObject(f := AudioPolicyFactory())
        nativeReset := (ComCall(27, f, "Int") = 0)     ; ClearAllPersistedApplicationDefaultEndpoints
    if !nativeReset && FileExist(SVV) {
        snap := GetProcessSnapshot()
        svvApps := GetSvvAudioSessions(snap.pidToExe)
        targets := []
        seenTargets := Map()
        seenTargets.CaseSense := false

        for item in svvApps {
            if item.itemId != "" && !seenTargets.Has(item.itemId) {
                seenTargets[item.itemId] := true
                targets.Push(item.itemId)
            }
            if item.exe != "" && !seenTargets.Has(item.exe) {
                seenTargets[item.exe] := true
                targets.Push(item.exe)
            }
        }
        for app in Apps {
            if !seenTargets.Has(app) {
                seenTargets[app] := true
                targets.Push(app)
            }
        }

        ; One SoundVolumeView launch per batch (it accepts several commands per call)
        ; instead of two launches per target.
        batchCmd := ""
        batchN := 0
        for tgt in targets {
            batchCmd .= Format(' /SetAppDefault "{1}" all "{2}" /SetAppDefault "{3}" all "{2}"', DEFAULT_DEVICE, tgt, DEFAULT_CAPTURE_DEVICE)
            batchN++
            if batchN >= MIXER_BATCH_SIZE {
                try RunWait('"' SVV '"' batchCmd, , "Hide")
                batchCmd := ""
                batchN := 0
            }
        }
        if batchCmd != ""
            try RunWait('"' SVV '"' batchCmd, , "Hide")
    }

    ; 3. Clear all active overrides and deactivate Routing completely
    AppOverrideActive.Clear()
    AllMode := false
    Released.Clear()
    Loop MAX_MONITORS
        MonitorOverrideActive[A_Index] := false
    AllMonitorsMode := false
    PrevMonitorOverrideActive.Clear()
    LastRouted.Clear()

    SaveState()
    SetMasterRoutingEnabled(false, false)
    RefreshSelectedAppPanel()

    ShowOsdToast("Windows Mixer Reset — Routing Deactivated", 1)
    Tip("Windows Mixer reset to Default (volumes kept) — Routing deactivated")
}

; ------------------------------ NATIVE AUDIO (BETA) -------------------------
; Device list through Windows' audio API (IMMDeviceEnumerator), and per-app routing
; through the same undocumented interface Windows' own Settings page, EarTrumpet and
; SoundVolumeView use (AudioPolicyConfig). Its id changed with Windows 10 21H2, so the
; right one is picked by build. Anything that fails falls back to SoundVolumeView.

; Active playback devices (flow 0) or recording devices (flow 1): [{label, id, eid}], id in
; SoundVolumeView's form "<adapter>\Device\<name>\Render" (or \Capture), eid = Windows'
; endpoint id. Throws on failure.
NativeEnumDevices(flow := 0) {
    enum := ComObject("{BCDE0395-E52F-467C-8E3D-C4579291692E}", "{A95664D2-9614-4F35-A746-DE8DB63617E6}")
    pColl := 0
    ComCall(3, enum, "Int", flow, "UInt", 1, "Ptr*", &pColl)          ; EnumAudioEndpoints(eRender / eCapture, ACTIVE)
    coll := ComValue(13, pColl)
    cnt := 0
    ComCall(3, coll, "UInt*", &cnt)                                     ; GetCount
    devs := []
    Loop cnt {
        pDev := 0
        ComCall(4, coll, "UInt", A_Index - 1, "Ptr*", &pDev)            ; Item
        dev := ComValue(13, pDev)
        pId := 0
        ComCall(5, dev, "Ptr*", &pId)                                   ; GetId
        eid := StrGet(pId, "UTF-16")
        DllCall("ole32\CoTaskMemFree", "Ptr", pId)
        pStore := 0
        ComCall(4, dev, "UInt", 0, "Ptr*", &pStore)                     ; OpenPropertyStore(STGM_READ)
        store := ComValue(13, pStore)
        name := PropStoreString(store, "{a45c254e-df1c-4efd-8020-67d146a850e0}", 2)        ; endpoint name
        adapter := PropStoreString(store, "{b3f8fa53-0004-438e-9003-51a46e139bfc}", 6)     ; adapter name
        if adapter = ""
            adapter := PropStoreString(store, "{026e516e-b814-414b-83cd-856d6fef4822}", 2)
        if name = "" || adapter = ""
            continue
        devs.Push({label: name, id: adapter "\Device\" name (flow ? "\Capture" : "\Render"), eid: eid})
    }
    return devs
}

PropStoreString(store, fmtid, pid) {
    key := Buffer(20, 0)
    DllCall("ole32\CLSIDFromString", "WStr", fmtid, "Ptr", key)
    NumPut("UInt", pid, key, 16)
    pv := Buffer(A_PtrSize = 8 ? 24 : 16, 0)
    v := ""
    if ComCall(5, store, "Ptr", key, "Ptr", pv, "Int") = 0 {           ; GetValue
        if NumGet(pv, 0, "UShort") = 31                                 ; VT_LPWSTR
            v := StrGet(NumGet(pv, 8, "Ptr"), "UTF-16")
        DllCall("ole32\PropVariantClear", "Ptr", pv)
    }
    return v
}

; The per-app audio policy object, or "" when this Windows has none (before 1803).
AudioPolicyFactory() {
    static f := "", tried := false
    global NativeNote
    if tried
        return f
    tried := true
    if OsBuild() < 17134 {
        NativeNote := "Per-app routing needs Windows 10 1803 or newer"
        return f
    }
    iid := OsBuild() >= 21390 ? "{ab3d4648-e242-459f-b02f-541c70306324}" : "{2a59116d-6c4f-45e0-a74f-707e3fef9258}"
    cls := "Windows.Media.Internal.AudioPolicyConfig"
    hs := 0
    if DllCall("combase\WindowsCreateString", "WStr", cls, "UInt", StrLen(cls), "Ptr*", &hs, "Int") != 0
        return f
    guid := Buffer(16, 0)
    DllCall("ole32\IIDFromString", "WStr", iid, "Ptr", guid)
    p := 0
    hr := DllCall("combase\RoGetActivationFactory", "Ptr", hs, "Ptr", guid, "Ptr*", &p, "Int")
    DllCall("combase\WindowsDeleteString", "Ptr", hs)
    if hr != 0 || !p {
        NativeNote := Format("Audio policy interface not available (0x{1:08X})", hr & 0xFFFFFFFF)
        return f
    }
    f := ComValue(13, p)
    return f
}

; Sends the given processes to an endpoint (eid ""= back to the Windows default).
; flow 0 = playback, 1 = recording (microphone).
; Returns false when it could not, so the caller falls back to SoundVolumeView.
NativeSetAppDevice(pids, eid, flow := 0) {
    global NativeNote
    if !pids.Length || !IsObject(f := AudioPolicyFactory())
        return false
    hs := 0
    if eid != "" {
        ; device interface class: audio render / audio capture
        full := "\\?\SWD#MMDEVAPI#" eid (flow ? "#{2eef81be-33fa-4800-9670-1cd474972c3f}" : "#{e6327cad-dcec-4949-ae8a-991e976a79d2}")
        if DllCall("combase\WindowsCreateString", "WStr", full, "UInt", StrLen(full), "Ptr*", &hs, "Int") != 0
            return false
    }
    ; Windows keeps the choice per app, so one accepted process is enough. Some processes
    ; are refused (a browser's sandboxed helpers, or one that just closed): those are
    ; ignored, and only an app with no accepted process falls back to SoundVolumeView.
    okCount := 0, lastHr := 0
    for pid in pids {
        for role in [0, 1, 2] {                                         ; eConsole, eMultimedia, eCommunications (calls)
            hr := ComCall(25, f, "UInt", pid, "Int", flow, "Int", role, "Ptr", hs, "Int")   ; SetPersistedDefaultAudioEndpoint
            if hr = 0
                okCount++
            else
                lastHr := hr
        }
    }
    if hs
        DllCall("combase\WindowsDeleteString", "Ptr", hs)
    if !okCount
        NativeNote := Format("Native routing failed for every process ({1}) (0x{2:08X})", pids.Length, lastHr & 0xFFFFFFFF)
    return okCount > 0
}

; Re-reads the native device list (at most once a second). True when it was re-read.
RefreshNativeDeviceList() {
    static last := 0
    global CachedDevices, DevicesStale, CachedMics
    if !NativeAudio || A_TickCount - last < 1000
        return false
    last := A_TickCount
    try {
        devs := FinishDeviceList(NativeEnumDevices(0))
        CachedDevices := devs
        DevicesStale := false
        try CachedMics := FinishDeviceList(NativeEnumDevices(1))
        return true
    }
    return false
}

; ------------------------------ AUDIO / WINDOWS -----------------------------
; Routes an app's playback device and its microphone. mic: a recording device id or
; DEFAULT_CAPTURE_DEVICE, "" = leave the microphone alone, "auto" (resets) = the Windows
; default microphone while microphones are switched.
SetDevice(app, dev, mic := "auto") {
    if !ScanRunning.Has(app) && !AppRunning(app)
        return
    SetAppEndpoint(app, dev, 0)
    if mic = "auto"                                ; resets: back to the Windows default microphone
        mic := MicRoutingActive() ? DEFAULT_CAPTURE_DEVICE : ""
    if mic != ""
        SetAppEndpoint(app, mic, 1)
}

; One device for one app: flow 0 = playback, 1 = microphone. Native first, then SoundVolumeView.
SetAppEndpoint(app, dev, flow := 0) {
    isDefault := (dev = DEFAULT_DEVICE || dev = DEFAULT_CAPTURE_DEVICE)
    what := flow ? " microphone" : ""
    dev := isDefault ? (flow ? DEFAULT_CAPTURE_DEVICE : DEFAULT_DEVICE) : ResolveDeviceId(dev)
    if NativeAudio {
        eid := ""
        if !isDefault {
            d := FindCachedDevice(dev)
            if !IsObject(d) && RefreshNativeDeviceList() {     ; list out of date (device just came back)
                dev := ResolveDeviceId(dev)
                d := FindCachedDevice(dev)
            }
            eid := (IsObject(d) && d.HasOwnProp("eid")) ? d.eid : ""
        }
        if (isDefault || eid != "") && NativeSetAppDevice(ScanPids.Get(app, []), eid, flow)
            return
        LogLine("  native" what " routing not possible for " app (eid = "" && !isDefault ? " (device id unknown)" : "  " NativeNote))
    }
    if !FileExist(SVV) {
        LogLine("  " app what " not routed: SoundVolumeView.exe not found")
        return
    }
    LogLine("  " app what " routed with SoundVolumeView")
    Run(Format('"{1}" /SetAppDefault "{2}" all "{3}"', SVV, dev, app), , "Hide")
}

; ------------------------------ MICROPHONES ---------------------------------
; Each playback device can have a microphone paired with it (Devices window).
;  - A monitor's microphone is the one paired with its Output.
;  - An app uses the microphone of the monitor it is on.
;  - Overrides (app, monitor, All-Apps, All-Monitors, temporary) change only the sound,
;    unless that app or monitor has "Mic override" ticked: then, while its override is on,
;    it uses the microphone chosen there (by default the one paired with the override device).
; Nothing paired and no Mic override = microphones are left alone.
MicRoutingActive() {
    return MicsFollowOutput && (ActivePairCount() > 0 || AppMicOn.Count > 0 || MonMicOn.Count > 0)
}

; Pairs that are not paused (Devices window, "Pair" box).
ActivePairCount() {
    n := 0
    for k in DeviceMics
        if !DevicePairOff.Has(k)
            n++
    return n
}

; Microphone paired with a playback device, or the Windows default microphone.
PairedMicOf(dev) {
    if dev = "" || dev = DEFAULT_DEVICE || dev = DISABLED_MONITOR
        return DEFAULT_CAPTURE_DEVICE
    k := DevKey(dev)
    if DevicePairOff.Has(k)                         ; pair paused
        return DEFAULT_CAPTURE_DEVICE
    m := DeviceMics.Get(k, "")
    return m != "" ? m : DEFAULT_CAPTURE_DEVICE
}

; Microphone of a monitor's Mic override / of an app's Mic override.
MonMicTarget(mon) {
    d := MonMicDevice.Get(mon, "")
    return d != "" ? d : PairedMicOf(MonitorOverrideRules.Get(mon, DEFAULT_DEVICE))
}
AppMicTarget(app) {
    d := AppMicDevice.Get(app, "")
    return d != "" ? d : PairedMicOf(AppOverrideDevice(app))
}

; The microphone a monitor gives the apps on it.
MonitorMic(mon) {
    if !mon || mon > DetectedMonCount || DisableMonitorRouting || IsMonitorDisabled(mon)
        return DEFAULT_CAPTURE_DEVICE
    if MonitorOverrideActive.Get(mon, false) && MonMicOn.Has(mon)
        return MonMicTarget(mon)
    return PairedMicOf(MonitorRules.Get(mon, DEFAULT_DEVICE))
}

; Microphone for an app on a monitor: {mic, missing}. A microphone that is not connected
; falls back to the Windows default (missing = that microphone).
MicForApp(app, mon) {
    if !DisableAppRouting && AppOverrideActive.Get(app, false) && AppMicOn.Has(app)
        want := AppMicTarget(app)
    else
        want := MonitorMic(mon)
    if want = DEFAULT_CAPTURE_DEVICE || DevicePresent(want)
        return {mic: want, missing: ""}
    return {mic: DEFAULT_CAPTURE_DEVICE, missing: want}
}

; Puts the microphone of every running tracked app back to the Windows default
; (when microphone routing is switched off or the last pair is removed).
ResetTrackedAppMics() {
    for app, enabled in Apps {
        if enabled && AppRunning(app)
            SetAppEndpoint(app, DEFAULT_CAPTURE_DEVICE, 1)
    }
}

; Makes a microphone the Windows default recording device, for all three roles (normal,
; multimedia, communications), like SoundSwitch does. For apps that ignore their own
; per-app microphone ("Set as Windows default mic" in the Per-App section).
SetSystemDefaultMic(micId) {
    if micId = "" || micId = DEFAULT_CAPTURE_DEVICE
        return false
    d := FindCachedDevice(micId)
    if NativeAudio && IsObject(d) && d.HasOwnProp("eid") {
        try {
            ; CPolicyConfigClient / IPolicyConfig (undocumented, used by SoundSwitch and others)
            pc := ComObject("{870af99c-171d-4f9e-af0d-e63df40c2bc9}", "{f8679f50-850a-41cf-9c72-430f290290c8}")
            ok := 0
            for role in [0, 1, 2]
                ok += (ComCall(13, pc, "WStr", d.eid, "Int", role, "Int") = 0)   ; SetDefaultEndpoint
            if ok {
                LogLine("  Windows default microphone -> " ShortDeviceName(micId))
                return true
            }
        }
    }
    if FileExist(SVV) {
        Run(Format('"{1}" /SetDefault "{2}" all', SVV, ResolveDeviceId(micId)), , "Hide")
        LogLine("  Windows default microphone -> " ShortDeviceName(micId) " (SoundVolumeView)")
        return true
    }
    LogLine("  Windows default microphone not changed: no way to set it")
    return false
}

FocusedApp() {
    try {
        winHwnd := WinExist("A")
        if !winHwnd
            return ""
        exe := GetEffectiveWindowExe(winHwnd)
        if exe != "" && Apps.Has(exe)
            return exe
    }
    return ""
}

; ------------------------------ SVV DEVICE PARSER ---------------------------
; Playback devices. The microphone list (CachedMics) is read at the same time.
GetDevices() {
    global NativeNote, CachedMics
    if NativeAudio {
        try {
            devs := FinishDeviceList(NativeEnumDevices(0))
            try CachedMics := FinishDeviceList(NativeEnumDevices(1))
            return devs
        } catch as e {
            NativeNote := "Native device list failed : " e.Message
        }
    }
    devs := FinishDeviceList(SvvEnumDevices(&mics))
    CachedMics := FinishDeviceList(IsObject(mics) ? mics : [])
    return devs
}

; Raw playback device list from SoundVolumeView ({label, id}), or [] when it is not
; available. The recording devices go to mics.
SvvEnumDevices(&mics := "") {
    mics := []
    if !FileExist(SVV)
        return []
    tmp := A_Temp "\ScreenAudioRouter_devices.csv"
    try FileDelete(tmp)
    cmd := Format('"{1}" /SaveFileEncoding 3 /scomma "{2}" /Columns "Name,Type,Direction,Device State,Command-Line Friendly ID"', SVV, tmp)
    try RunWait(cmd, , "Hide")
    if !FileExist(tmp)
        return []
    text := FileRead(tmp, "UTF-8")
    try FileDelete(tmp)

    rows := []
    for line in StrSplit(text, "`n", "`r") {
        if Trim(line) != ""
            rows.Push(ParseCsvLine(line))
    }
    if rows.Length < 2
        return []
    rows[1][1] := LTrim(rows[1][1], Chr(0xFEFF))

    hdr := Map()
    hdr.CaseSense := false
    for i, name in rows[1] {
        hdr[name] := i
    }
    for need in ["Name", "Type", "Direction", "Command-Line Friendly ID"] {
        if !hdr.Has(need)
            return []
    }

    devs := []
    seen := Map()
    seen.CaseSense := false
    Loop rows.Length - 1 {
        r := rows[A_Index + 1]
        dir := Field(r, hdr, "Direction")
        if Field(r, hdr, "Type") != "Device" || (dir != "Render" && dir != "Capture")
            continue
        state := Field(r, hdr, "Device State")
        if state != "" && state != "Active"
            continue
        id := Field(r, hdr, "Command-Line Friendly ID")
        if id = ""
            continue
        if dir = "Capture"
            mics.Push({label: Field(r, hdr, "Name"), id: id})
        else
            devs.Push({label: Field(r, hdr, "Name"), id: id})
    }
    return devs
}

; Learns identical devices, builds the "Name  [Adapter]" labels and applies display names.
FinishDeviceList(devs) {
    seen := Map()
    seen.CaseSense := false
    cnt := Map()
    cnt.CaseSense := false
    for d in devs {
        nn := NormDevId(d.id)
        cnt[nn] := cnt.Get(nn, 0) + 1
    }
    for nn, c in cnt {
        if c >= 2
            LearnIdentical(nn)
    }
    for d in devs {
        ; "Name  [Adapter]"; Windows' "2- " stays visible when you own two of the device
        rx := MultiDevNames.Has(NormDevId(d.id)) ? "^(.+?)\\Device\\" : "^(?:\d+-\s*)?(.+?)\\Device\\"
        label := d.label
        if RegExMatch(d.id, rx, &mm)
            label .= "  [" mm[1] "]"
        base := label, k := 1
        while seen.Has(label)
            label := base " #" (++k)
        seen[label] := true
        d.winLabel := label
    }
    ApplyDeviceAliases(devs)
    return devs
}

Field(row, hdr, name) {
    if !hdr.Has(name)
        return ""
    i := hdr[name]
    return i <= row.Length ? row[i] : ""
}

ParseCsvLine(line) {
    fields := []
    field := ""
    inQuotes := false
    i := 1
    len := StrLen(line)
    while i <= len {
        c := SubStr(line, i, 1)
        if inQuotes {
            if c = '"' {
                if SubStr(line, i + 1, 1) = '"' {
                    field .= '"'
                    i++
                } else {
                    inQuotes := false
                }
            } else {
                field .= c
            }
        } else if c = '"' {
            inQuotes := true
        } else if c = "," {
            fields.Push(field)
            field := ""
        } else {
            field .= c
        }
        i++
    }
    fields.Push(field)
    return fields
}
