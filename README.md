# Logi Fine Volume

Fine-grained macOS volume control for Logitech keyboards using Logi Options+.

This project builds three tiny macOS helper apps:

- `Logi Fine Volume Down.app`
- `Logi Fine Volume Up.app`
- `Logi Fine Volume Hotkeys.app`

The recommended path is the hotkey helper. It runs in the background, shows a menu bar icon, listens for two Logi-assigned keystrokes, changes the system output volume by an exact step, and can show a small custom HUD.

## Why this exists

Some Logitech keyboards on macOS, including MX-series devices, send media keys through Logi Options+ in a way that does not reliably reach Karabiner as raw keyboard events. The result is that:

- normal media volume works
- Karabiner remaps may not trigger
- custom shortcut fallbacks may beep instead of being handled

This repo avoids that path by using a local background helper instead of Logitech's normal media-key flow.

The generated helper apps are native Swift bundles. They do not use the AppleScript applet runtime, which helps avoid the visible blink and focus disturbance that can happen when launching hidden AppleScript apps repeatedly.

If you are using something like an MX Creative Console, MX Keys, or another Logitech device that is managed by Logi Options+, the important detail is this:

your button press usually does **not** go straight from the keyboard into macOS as a simple raw key that other tools can reliably remap.

Instead, the path often looks more like this:

1. You press a Logitech button.
2. Logi Options+ receives that button press first.
3. Logi Options+ decides what to emit next:
   - a normal media action
   - a custom keystroke
   - a Smart Action
   - an app launch
4. macOS only sees the result of that Logitech step.

That extra Logitech layer is why the usual solutions break down.

### Why a normal keystroke assignment is not enough

You can tell Logi Options+ to send a shortcut like `Control + Option + Command + J`, but that shortcut does nothing by itself.

macOS still needs **some running app** to listen for that shortcut and decide what to do with it.

Without a listener:

- the shortcut is just an unused key combo
- macOS treats it like an unhandled shortcut
- you often hear a beep
- volume does not change

So the keystroke assignment is only half of the solution. This repo provides the other half: the small background helper that listens for the shortcut and then changes the volume directly.

### Why Karabiner usually does not solve it here

Karabiner works best when it can see the **original hardware event**.

For many Logitech media buttons and console actions, that is not what happens. Logi Options+ often intercepts the device input first and turns it into some other software-level action before Karabiner gets a reliable raw event to remap.

In practice, that leads to problems like:

- Karabiner never sees the real original key event
- media buttons still do the default big macOS volume step
- custom remaps work inconsistently or only sometimes
- one Logitech action can drift into another when Smart Actions are involved

That is why this repo does **not** depend on Karabiner for the actual volume logic.

### Why this tool works

This helper takes the most stable part of the Logitech path and keeps the rest under local control:

1. Logi Options+ sends one simple keystroke combo.
2. `Logi Fine Volume Hotkeys.app` catches that combo.
3. The helper changes macOS volume directly by the exact step you configured.
4. The helper optionally shows its own overlay.

That means:

- Logitech only has to emit a shortcut
- the volume math is done locally and predictably
- you get exact small steps
- you do not need Karabiner to understand the Logitech hardware event
- you can enable or disable the hotkeys and overlay from the menu bar

## Repo layout

- `src/volume_common.swift`
- `src/volume_runner.swift`
- `src/volume_hotkeys.swift`
- `src/volume_hud.swift`
- `scripts/build_apps.sh`
- `INSTRUCTIONS.md`

## Requirements

- macOS
- Logi Options+
- `osascript` available on the system
- `xcrun swiftc` available on the system

## Build

Run:

```sh
./scripts/build_apps.sh
```

The generated output will be written to:

```text
dist/Logi Fine Volume Down.app
dist/Logi Fine Volume Up.app
dist/Logi Fine Volume Hotkeys.app
dist/com.murat-taskaynatan.logi-fine-volume.hotkeys.plist
```

Each generated app contains:

- a native binary that sets the new exact volume
- a small background HUD binary that displays the current volume percentage

## Install

Recommended install:

```sh
cp -R "dist/Logi Fine Volume Hotkeys.app" "$HOME/Applications/"
mkdir -p "$HOME/Library/LaunchAgents"
cp "dist/com.murat-taskaynatan.logi-fine-volume.hotkeys.plist" "$HOME/Library/LaunchAgents/"
launchctl bootstrap "gui/$(id -u)" "$HOME/Library/LaunchAgents/com.murat-taskaynatan.logi-fine-volume.hotkeys.plist"
launchctl kickstart -k "gui/$(id -u)/com.murat-taskaynatan.logi-fine-volume.hotkeys"
```

Optional fallback:

```sh
cp -R "dist/Logi Fine Volume Down.app" "$HOME/Applications/"
cp -R "dist/Logi Fine Volume Up.app" "$HOME/Applications/"
```

The fallback app-launch path still exists for manual testing, but the hotkey helper is the recommended setup because it avoids the Logi Smart Actions instability where both buttons can collapse onto the same app after some uptime.

## Menu Bar Controls

After the hotkey helper starts, it appears in the macOS menu bar with a speaker icon.

The menu provides:

- `Enable Fine Volume` to turn the global hotkeys on or off
- `Show Overlay` to enable or disable the custom volume HUD

Those settings persist between launches because the helper stores them in a shared preferences domain.

## Configure Logi Options+

1. Open Logi Options+.
2. Select your Logitech keyboard.
3. Reassign the `Volume Down` key.
4. Choose `Keystroke Assignment`.
5. Record `Control + Option + Command + J`.
6. Reassign the `Volume Up` key.
7. Record `Control + Option + Command + K`.

The hotkey helper listens for those shortcuts globally and adjusts volume in exact steps.

If you still want the old app-launch path, assign the down and up apps directly instead, but it is less reliable over time.

## Change the step size

Edit `STEP_SIZE` in:

- `scripts/build_apps.sh`

Then rebuild the apps:

```sh
./scripts/build_apps.sh
```

## Verify

After assigning the hotkeys in Logi Options+:

- press `Volume Down` once and confirm the volume decreases by the configured step
- press `Volume Up` once and confirm the volume increases by the configured step
- confirm there is no repeated beep from an unhandled shortcut
- confirm a small custom volume HUD appears
- confirm the helper shows a menu bar icon
- confirm the menu bar toggles can disable hotkeys and the overlay independently

## Troubleshooting

- If the hotkeys beep, the background helper is not running. Reload the LaunchAgent and confirm `Logi Fine Volume Hotkeys.app` is running.
- If the volume still behaves like the normal large macOS step, make sure the MX Keys buttons are assigned to the keystrokes above rather than the default media action.
- If nothing happens, launch `Logi Fine Volume Hotkeys.app` manually once from `~/Applications` and try again.
- If the overlay does not appear, make sure `Show Overlay` is enabled from the menu bar icon.
- If you changed `STEP_SIZE`, rebuild and reinstall the generated app and LaunchAgent plist.

## Step-by-step guide

See [INSTRUCTIONS.md](INSTRUCTIONS.md) for a shorter setup walkthrough.
