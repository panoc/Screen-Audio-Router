# Screen Audio Router

**Send each app's sound to the speakers or headphones of the monitor its window is on.**

Drag Spotify to your TV and its music plays on the TV. Drag it back to your desk monitor and it plays on your desk speakers. Every tracked app follows its own window, and you can override any of it with a hotkey or from a window's title bar.

Screen Audio Router is a small Windows tray app written in [AutoHotkey v2](https://www.autohotkey.com/). It needs no driver and no virtual audio cable. It uses the same per-app output setting you find in Windows *Settings → Sound → Volume mixer*, and changes it automatically.

<!-- Screenshot: put your image in docs/ and remove the comment marks around the next line -->
<!-- ![Screen Audio Router main window](docs/main-window-dark.png) -->

---

## Contents

- [Features](#features)
- [How it works](#how-it-works)
- [Requirements](#requirements)
- [Installation](#installation)
- [Quick start](#quick-start)
- [Using Screen Audio Router](#using-screen-audio-router)
- [Hotkeys](#hotkeys)
- [Settings and files](#settings-and-files)
- [Customizing colors and theme](#customizing-colors-and-theme)
- [Running and compiling from source](#running-and-compiling-from-source)
- [Troubleshooting](#troubleshooting)
- [Known limitations](#known-limitations)
- [Credits](#credits)
- [License](#license)

---

## Features

- **Audio follows the window.** Give each monitor an output device. When a tracked app's window moves to another monitor, its sound moves with it.
- **Works with any app.** You choose which apps it manages, and every other app is left alone.
- **No rule means Windows default.** A monitor without an output device plays on the Windows default device.
- **Overrides with hotkeys:**
  - **Focused app.** Send the app you are using to another device.
  - **All apps.** Send every tracked app to one device.
  - **All monitors.** Make every monitor play on one device.
  - **One monitor or one app.** Give any monitor or app its own hotkey.

  Pressing the hotkey again ends the override. The app then goes to the device of the monitor it is on *now*.
- **Temporary override.** Use another device until the override ends, without changing the saved one.
- **Follow monitor on or off, per app.** Pin an app to one device wherever its window is.
- **Title-bar menu.** Ctrl+Right-Click on any window's title bar (the mouse combination is selectable) to:
  - add the app;
  - pick its override or temporary device;
  - choose which of its windows the sound follows.
- **Apps with several windows** (browsers, for example). The sound follows the first window, a window you pick, or the window you used last.
- **Missing device handling:**
  - A warning, with an optional sound, when an assigned device is unplugged.
  - A fallback in the meantime: override → monitor output → Windows default.
  - When the device comes back, routing is restored automatically.
- **Identical devices** (for example two of the same USB sound card) are told apart.
- **Devices window.** Give devices short display names and hide devices from the lists where you don't need them.
- **Replace Device.** Move every rule from one device to another in one step, for example after a Windows update renamed it.
- **Tray icon.** It shows the routing state (all on, partly off, off), and extra icons show active overrides.
- **Comfort features:** light and dark theme, tooltips on every option, start with Windows, start in the tray, remembers its window position.
- **No helper tools needed.** It talks to Windows directly. NirSoft SoundVolumeView is only an optional fallback (see [Native audio](#native-audio-and-soundvolumeview)).

---

## How it works

Windows lets every program have its own output device. You can see this under *Settings → System → Sound → Volume mixer*, where each app has an "Output device" list. Screen Audio Router changes that setting for you whenever it is needed.

1. **It watches windows.** Windows reports every focus change, finished move and minimize. A slow timer double-checks in case an event was missed.
2. **It finds the monitor.** For each tracked app it looks at the window its sound follows and checks which monitor that window is on.
3. **It picks a device.** It goes down the list below and uses the first rule that applies. If that device is unplugged, it moves on to the next rule.
4. **It routes the app.** It tells Windows to send that app's audio to the chosen device, and does nothing if the app is already there.

```mermaid
flowchart TD
    A[Tracked app] --> B{App override on?<br/>incl. temporary}
    B -- yes --> Z1[App override device]
    B -- no --> C{All-Apps override on?}
    C -- yes --> Z2[All-Apps device]
    C -- no --> D{Follow monitor off?}
    D -- yes --> Z3[App's fixed device]
    D -- no --> E{Monitor disabled?}
    E -- yes --> Z0[Windows default device]
    E -- no --> F{All-Monitors override on?}
    F -- yes --> Z4[All-Monitors device]
    F -- no --> G{Monitor override on?}
    G -- yes --> Z5[Monitor override device]
    G -- no --> H{Monitor has an output?}
    H -- yes --> Z6[Monitor output device]
    H -- no --> Z0
```

Ending an override never sends an app back to an "old" device. The app always returns to whatever the rules say for the monitor it is on at that moment.

---

## Requirements

- **Windows 10 version 1803 or newer.** Developed and tested on Windows 11 with three monitors.
- **Up to 4 monitors.**
- **To run the script instead of the exe:** [AutoHotkey v2](https://www.autohotkey.com/).
- **Optional:** [SoundVolumeView](https://www.nirsoft.net/utils/sound_volume_view.html) by NirSoft, as a fallback.

---

## Installation

### Option 1: the exe (easiest)

1. Download `Screen Audio Router.exe` from the [Releases](../../releases/latest) page.
2. Put it in a folder of its own, for example `C:\Tools\Screen Audio Router\`. Its settings file will be created next to it.
3. Run it.

No installer is needed and nothing is written outside that folder, except the "Start with Windows" entry if you turn it on.

### Option 2: the script

1. Install [AutoHotkey v2](https://www.autohotkey.com/).
2. Download this repository with **Code → Download ZIP**, or clone it.
3. Run `ScreenAudioRouter.ahk`. The `src` and `res` folders must stay next to it.

> The script and the exe can't run at the same time. If one is running, close it before you start the other.

---

## Quick start

1. **Open the window.** Double-click the tray icon, or right-click it and choose **Open Screen Audio Router**.
2. **Identify your monitors.** Click **Identify Mons** to see which number belongs to which screen.
3. **Give each monitor an output.** In each monitor block, choose a device in the **Output** list. Leave it on *Windows Default* if that monitor has no speakers of its own.
4. **Add the apps you want routed:**
   - click **Detect Apps…**, select running apps and click **Add Selected to Tracked**, **or**
   - Ctrl+Right-Click the app's title bar and choose **Add "app.exe" to Tracked Apps**.
5. **Apply.** Click **Apply**, then move the app's window to another monitor. Its sound follows.

---

## Using Screen Audio Router

### Main window

<!-- ![Main window, light theme](docs/main-window-light.png) -->

| Area | What it does |
|---|---|
| **Tracked Applications** | The apps that are routed. Untick an app to pause routing for it without removing it. |
| **Routed Audio Output Status** | Where every tracked app is playing right now, and why: monitor, override, fixed or missing device. |
| **Per-App Override & Shortcut** | For the selected app: override device, override on/off, a hotkey, *Follow focused window* and *Follow monitor*. |
| **Global Override Settings & Conflict Guard** | The devices used by the All-Apps and All-Monitors overrides, and the conflict guard. |
| **Global Monitor Rules & Overrides** | One block per monitor: **Output**, override device (**Ovrd**), override on/off and a hotkey. |
| **Global Hotkeys & Quick Actions** | The global hotkeys (click a box, then press the keys), plus buttons for the same actions. |
| **Routing Controls & Options** | Turn routing off (all, monitors only or apps only), title-bar menu, tracking, startup and theme. |

Hover over any option to see a tooltip that explains it.

### Overrides

| Override | Effect | Ends when |
|---|---|---|
| **App override** | One app plays on its override device on every monitor. | You press its hotkey again, untick it, or reset it. |
| **Temporary override** | Same as an app override, but with a device picked just for now. The saved override device is kept. | The override ends. The temporary device is then forgotten. |
| **Monitor override** | Everything on that monitor plays on the monitor's **Ovrd** device. | You press the hotkey or button again. |
| **All-Apps override** | Every tracked app plays on one device. | You press the hotkey again. |
| **All-Monitors override** | Every monitor plays on one device. It ends any single-monitor overrides first. | You press the hotkey again. |

When an override ends, the app goes back to the device for the monitor it is on *now*.

The **Conflict Guard** ("Avoid contradicting overrides") stops you from setting up overrides that cancel each other, for example a monitor override that uses the same device as that monitor's normal output. The **Fix** button next to it resolves existing ones.

### Follow monitor (per app)

When **Follow monitor** is unticked, the app always plays on the device you choose next to it, whatever monitor its window is on.

This is handy for an app that should never move, for example a voice chat that stays on your headset. Overrides, temporary overrides and the All-Apps override still apply on top.

### Apps with several windows

Browsers and some other apps have one sound for all their windows. Screen Audio Router has to pick one window to follow:

- **Default:** the app's first window.
- **Audio follows this window:** use this item in a window's title-bar menu to pick that window instead. It is not saved; after a restart the first window is used again.
- **Follow focused window:** the sound follows whichever window of the app you used last. Turn it on for all apps in *Routing Controls*, or per app in the *Per-App* section.

### Title-bar menu

Ctrl+Right-Click (or the combination you chose) on a window's title bar:

| On a tracked app | On an untracked app |
|---|---|
| Override on/off | Add to Tracked Apps (screen rules) |
| Select Override Device ▸ | Add & Override Audio ▸ device |
| Temporarily Override ▸ | |
| Audio follows this window | |
| Enable Audio Routing for this app | |
| Remove from Script | |

Turn on **All apps** next to the title-bar menu setting to get the menu on every window, not only tracked ones.

### Tray icon

- **Main icon:** routing on, partly off, or off. Hover over it for a summary of where everything plays.
- **Extra icons:** one appears for each active monitor override, All-Monitors override, All-Apps override or app override. Right-click one to end that override; left-click opens the window.
- **Right-click menu:**
  - open the window;
  - reset overrides;
  - **Replace Device…**;
  - **Settings ▸** export, import, or open the settings folder;
  - **Beta ▸** native audio and the debug log;
  - **Start with Windows**.

### Devices window

Click **Devices…** to:

- give devices short **display names** (the Windows name is kept underneath);
- choose in which lists each device appears (Output, Monitor ovr, App ovr, Temp ovr), so long lists stay short.

### When a device is unplugged

- **A warning appears:** you get a notification (optionally with a sound) and the status list marks the device as missing.
- **The app falls back meanwhile:** override → monitor output → Windows default.
- **Plug the device back in:** routing is restored within seconds. This includes after sleep and when Windows gives the device a slightly different name (for example "2- Speakers").
- **If a device was really renamed or replaced:** use **Replace Device…** to move all its rules to the new one.

---

## Hotkeys

| Default | Action |
|---|---|
| `Ctrl+Alt+O` | Override on/off for the **focused** tracked app |
| `Ctrl+Alt+Shift+O` | **All-Apps** override on/off |
| `Ctrl+Alt+M` | **All-Monitors** override on/off |
| `Ctrl+Alt+R` | Re-apply routing now |
| *(none)* | Per-monitor override on/off. Set it in each monitor block. |
| *(none)* | Per-app override on/off. Set it in the Per-App section. |
| `Ctrl+Right-Click` on a title bar | Title-bar menu (selectable) |

To change a hotkey, click its box and press the new keys. Mouse buttons work too. Use **Clear** to remove a hotkey and **Reset** to restore the default.

---

## Settings and files

| File | What it is |
|---|---|
| `ScreenAudioRouter.ini` | All your settings. Created next to the exe or script on first save. |
| `ScreenAudioRouter.ini.<version>.bak` | Automatic backup made the first time a new version starts. |
| `ScreenAudioRouter.log` | Only when *Beta → Debug log* is on. It is capped at 1 MB. |

- **Move to another PC:** use **Settings → Export settings…** and **Import settings…** in the tray menu.
- **Start with Windows:** adds an entry under `HKCU\…\Run`. If you move the exe, untick the option and tick it again.

---

## Customizing colors and theme

All colors are at the top of `ScreenAudioRouter.ahk`:

- **`BUTTON COLORS`**: a small palette (`Color1` … `Color10`) and one line per button that picks a color from it, including separate on and off colors for the toggle buttons.
- **`THEME`**: the full light and dark palettes (`THEME_LIGHT`, `THEME_DARK`), plus `APP_TITLE_SIZE`. These cover backgrounds, text, frames, table headers, selection and the hover darkening.

Edit, save, and reload the script, or recompile the exe.

---

## Running and compiling from source

```
Screen Audio Router\
├─ ScreenAudioRouter.ahk   main file: run this, compile this (version, colors, theme, startup)
├─ src\
│  ├─ Gui.ahk              main window, Detect / Devices / Replace Device windows
│  ├─ Routing.ahk          routing rules, overrides, window tracking, display and device changes
│  ├─ Audio.ahk            native audio, SoundVolumeView fallback, mixer reset
│  ├─ Tray.ahk             tray menu and icons, title-bar menu, notifications
│  ├─ Theme.ahk            light / dark drawing of buttons, tables and frames
│  ├─ Hotkeys.ahk          hotkeys and the capture boxes
│  └─ Settings.ahk         INI, backup, debug log, single instance, autostart
└─ res\                    the 9 icons and sor-icons.dll
```

**To compile:**

1. Open **Ahk2Exe**, which comes with AutoHotkey.
2. Choose **only `ScreenAudioRouter.ahk`** as the source. The `src` files and the `res` icons are built into the exe automatically.
3. Choose a 64-bit AutoHotkey v2 base file and compile.

The result needs nothing else, apart from `SoundVolumeView.exe` if you want the fallback.

**Icons** are looked up in this order:

1. built into the exe;
2. `res\sor-icons.dll`;
3. the `.ico` files in `res\`;
4. AutoHotkey's own icon.

### Native audio and SoundVolumeView

Screen Audio Router lists devices and routes apps by talking to Windows directly. If that fails for an app, or you turn **Beta → Native audio** off, it uses NirSoft's free [SoundVolumeView](https://www.nirsoft.net/utils/sound_volume_view.html) instead.

To have that fallback, download `SoundVolumeView.exe` and put it **next to the exe or the `.ahk`**. It is not included in this repository.

**Beta → Compare device IDs with SoundVolumeView** checks that both ways see the same devices.

---

## Troubleshooting

**An app doesn't switch device.**
- Make sure it is ticked in *Tracked Applications* and that routing isn't turned off.
- Some apps choose their own output device in their own settings (many games, DAWs, Discord's output setting). Set those apps to *Default* in their own settings.
- Some apps only switch when playback restarts. Pause and play again.

**A browser plays on the wrong monitor.** Its sound follows one window. Use *Audio follows this window* in the title-bar menu, or turn on *Follow focused window* for it.

**The status says a device is missing, but it's plugged in.** Click **Refresh Devices**. If Windows really gave it a new identity, use **Replace Device…**.

**Hotkey doesn't work.** Another program or Windows may already use it. The window says so when a shortcut couldn't be registered. Pick another one.

**"Start with Windows" stopped working after moving the exe.** Untick and tick it again.

**Something else.** Turn on **Beta → Debug log** in the tray menu, reproduce the problem, then use **Open debug log**. Attach the log when you [open an issue](../../issues).

---

## Known limitations

- **Undocumented Windows interface.** Per-app routing uses a Windows interface that Microsoft has not documented (the same one SoundVolumeView and similar tools use). A future Windows update could change it. SoundVolumeView is then the fallback.
- **Output devices only.** Microphones are not routed.
- **Up to 4 monitors.**
- **Same app, different monitors.** Windows has one output device per app, not per window. So two windows of the same app on different monitors share one device.

---

## Credits

- Built with [AutoHotkey v2](https://www.autohotkey.com/).
- Optional fallback: [SoundVolumeView](https://www.nirsoft.net/utils/sound_volume_view.html) by NirSoft. It is not bundled; please download it from NirSoft.
- Inspired by the idea behind ScreenSound, rebuilt around per-app rules, overrides and hotkeys.

---

## License

<!-- Pick a license, add it as a LICENSE file, and name it here, e.g.: -->
Released under the MIT License. See [LICENSE](LICENSE).
