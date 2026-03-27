# Fine Volume

Fine-grained macOS volume control for Logitech MX Creative Console, MX Keys, Stream Deck, and other programmable controllers.

The GitHub repo still uses the older `logi-fine-volume` name, but the helper apps are now generic because the same approach works well beyond Logitech hardware.

This project builds four small macOS tools:

- `Fine Volume Hotkeys.app`
- `Fine Volume Down.app`
- `Fine Volume Up.app`
- `fine-volume`

The recommended path is `Fine Volume Hotkeys.app`. It runs in the background, shows a menu bar icon, listens for two configurable global shortcuts, changes the system output volume by an exact step, and can show a small custom HUD.

## Why this exists

Different controller ecosystems hand off volume actions in different ways:

- Logitech MX Creative Console, MX Keys, and other Logi Options+ devices often send the button through Logi Options+ first.
- Stream Deck and similar consoles usually can send a keystroke, launch an app, or run a command directly.
- Macro pads and automation tools often only know how to trigger a shortcut or shell command.

The common problem is that these tools usually do **not** give you a built-in "fine volume" action for macOS. They give you a way to trigger something else.

This repo provides that "something else": a local helper that performs exact volume math on the Mac instead of relying on the normal large macOS media-key step.

### Why a normal keystroke assignment is not enough

If your controller software sends a shortcut like `Control + Option + Command + J`, that shortcut still needs a listener.

Without a listener:

- the shortcut is just a key combo
- macOS has nothing attached to it
- you often hear a beep
- volume does not change

`Fine Volume Hotkeys.app` is the listener. It stays running in the background and handles the shortcut locally.

### Why Karabiner often does not solve Logitech's path

Karabiner works best when it can see the original hardware event.

For Logitech MX Creative Console, MX Keys, and similar Logi Options+ devices, that is often not what happens. Logi Options+ tends to intercept the button first, then emits:

- a media action
- a custom keystroke
- an app launch
- a Smart Action result

That means Karabiner may never receive a stable raw Logitech event to remap. In practice, that can show up as:

- regular large macOS volume steps
- remaps that only work sometimes
- shortcuts that only partly fire
- custom Logitech actions collapsing into the wrong behavior after some uptime

This helper avoids that dependency by using the most stable output that controller software can usually send: a shortcut, an app launch, or a command.

### Why this helper still helps with Stream Deck and other consoles

Stream Deck and similar consoles are usually easier than Logitech because they can already run a shortcut, open an app, or call a command directly.

The reason this helper is still useful there is different:

- it gives you exact volume steps instead of the default large media-key step
- it keeps settings in one place
- it gives you an optional custom overlay
- it provides a reusable CLI for other automation tools

So Logitech needs this helper mostly because of the event path. Stream Deck and other consoles benefit mostly because of the precise local volume control.

## Trigger options

You can drive Fine Volume in three ways:

### 1. Global hotkeys

Best for:

- Logitech MX Creative Console
- MX Keys
- other devices managed by Logi Options+
- controllers that can emit a shortcut reliably

Default shortcuts:

- `Control + Option + Command + J` = volume down
- `Control + Option + Command + K` = volume up

These can be changed later from the menu bar helper or the CLI.

### 2. App launch

Best for:

- Stream Deck
- consoles that can launch apps directly
- button decks that do better with app actions than with global shortcuts

Apps:

- `Fine Volume Down.app`
- `Fine Volume Up.app`

These helper apps can show the custom HUD and do not require the menu bar helper to be the listener.

### 3. CLI

Best for:

- Stream Deck command actions
- Keyboard Maestro
- BetterTouchTool
- Hammerspoon
- Raycast scripts
- Alfred workflows
- other consoles or automation tools that can run a shell command

Examples:

```sh
fine-volume down
fine-volume up
fine-volume step-size 3
fine-volume status
```

The CLI changes volume directly. It is the simplest path for command-capable tools.

## Repo layout

- `src/volume_common.swift`
- `src/volume_runner.swift`
- `src/volume_hotkeys.swift`
- `src/volume_hud.swift`
- `src/fine_volume_cli.swift`
- `scripts/build_apps.sh`
- `INSTRUCTIONS.md`

## Requirements

- macOS
- `osascript` available on the system
- `xcrun swiftc` available on the system

Optional, depending on your controller:

- Logi Options+
- Stream Deck software
- another automation or console app that can send shortcuts, launch apps, or run commands

## Build

Run:

```sh
./scripts/build_apps.sh
```

The generated output is written to:

```text
dist/Fine Volume Down.app
dist/Fine Volume Up.app
dist/Fine Volume Hotkeys.app
dist/fine-volume
dist/com.murat-taskaynatan.fine-volume.hotkeys.plist
```

## Install

### Hotkey helper

Recommended install:

```sh
cp -R "dist/Fine Volume Hotkeys.app" "$HOME/Applications/"
mkdir -p "$HOME/Library/LaunchAgents"
cp "dist/com.murat-taskaynatan.fine-volume.hotkeys.plist" "$HOME/Library/LaunchAgents/"
launchctl bootstrap "gui/$(id -u)" "$HOME/Library/LaunchAgents/com.murat-taskaynatan.fine-volume.hotkeys.plist"
launchctl kickstart -k "gui/$(id -u)/com.murat-taskaynatan.fine-volume.hotkeys"
```

### Optional app-launch helpers

```sh
cp -R "dist/Fine Volume Down.app" "$HOME/Applications/"
cp -R "dist/Fine Volume Up.app" "$HOME/Applications/"
```

### Optional CLI

If you want `fine-volume` on your shell path:

```sh
install -m 755 "dist/fine-volume" /usr/local/bin/fine-volume
```

If you prefer a user-local install:

```sh
mkdir -p "$HOME/bin"
install -m 755 "dist/fine-volume" "$HOME/bin/fine-volume"
```

If your controller software does not use your shell `PATH`, point it at the full binary path instead of only `fine-volume`.

## Menu bar controls

After the hotkey helper starts, it appears in the macOS menu bar with a speaker icon.

The menu provides:

- `Enable Fine Volume`
- `Show Overlay`
- `Step Size`
- `Shortcuts`

The `Shortcuts` menu lets you:

- view the current volume-down and volume-up shortcuts
- record a new shortcut for either action
- reset both shortcuts back to the defaults

These settings persist between launches.

## Configure Logitech MX Creative Console or MX Keys

1. Open Logi Options+.
2. Select your device.
3. Change the `Volume Down` control to `Keystroke Assignment`.
4. Record `Control + Option + Command + J`.
5. Change the `Volume Up` control to `Keystroke Assignment`.
6. Record `Control + Option + Command + K`.

If you later change the shortcuts from the Fine Volume menu bar app, update the Logi Options+ assignments to match.

## Configure Stream Deck or other consoles

Use whichever trigger style your controller software handles best:

### Option A: send the hotkeys

- `Control + Option + Command + J`
- `Control + Option + Command + K`

### Option B: launch the helper apps

- `~/Applications/Fine Volume Down.app`
- `~/Applications/Fine Volume Up.app`

### Option C: run the CLI

```sh
fine-volume down
fine-volume up
```

For tools that support shell commands cleanly, the CLI is usually the simplest setup.

If your tool does not inherit your shell `PATH`, use the full path such as `~/bin/fine-volume` instead.

## Change the step size

For normal use, change it from the menu bar:

1. Open `Fine Volume` in the menu bar.
2. Open `Step Size`.
3. Choose the percentage you want.

You can also change it from the CLI:

```sh
fine-volume step-size 5
```

## Change the shortcuts

From the menu bar:

1. Open `Fine Volume`.
2. Open `Shortcuts`.
3. Choose `Set Volume Down Shortcut...` or `Set Volume Up Shortcut...`.
4. Press the new shortcut.

From the CLI:

```sh
fine-volume shortcut down Control+Option+Command+H
fine-volume shortcut up Control+Option+Command+L
fine-volume shortcuts reset
```

## CLI reference

```sh
fine-volume up
fine-volume down
fine-volume status
fine-volume step-size 1
fine-volume hotkeys on
fine-volume hotkeys off
fine-volume overlay on
fine-volume overlay off
fine-volume shortcut down Control+Option+Command+J
fine-volume shortcut up Shift+Command+F18
fine-volume shortcuts reset
```

## Verify

After setup:

- confirm `Volume Down` decreases by the configured step
- confirm `Volume Up` increases by the configured step
- confirm there is no repeated macOS alert sound from an unhandled shortcut
- confirm the menu bar icon appears if you are using the hotkey helper
- confirm the `Step Size` and `Shortcuts` menus apply changes immediately
- confirm Stream Deck or your other console triggers the exact action you assigned

## Troubleshooting

- If a Logitech control still uses the normal large macOS volume step, it is still mapped to Logitech's default media action instead of a Fine Volume trigger.
- If a custom shortcut causes the macOS alert sound, the hotkey helper is not running or the controller shortcut does not match the helper shortcut.
- If Karabiner works on the built-in keyboard but not on a Logitech control, that usually means Logi Options+ intercepted the original event before Karabiner could remap it.
- If Stream Deck or another console can run commands directly, prefer `fine-volume up` and `fine-volume down` instead of trying to force the default media key path.
- If the overlay does not appear, make sure `Show Overlay` is enabled from the Fine Volume menu bar icon.
- If the amount is wrong, check the helper's `Step Size` menu or run `fine-volume status`.
- If you changed defaults in `scripts/build_apps.sh`, rebuild and reinstall the generated apps and LaunchAgent plist.

## Step-by-step guide

See [INSTRUCTIONS.md](INSTRUCTIONS.md) for a shorter setup walkthrough.
