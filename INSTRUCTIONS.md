# Instructions

## Quick setup

1. Build the helper apps:

```sh
./scripts/build_apps.sh
```

2. Install the hotkey helper:

```sh
cp -R "dist/Logi Fine Volume Hotkeys.app" "$HOME/Applications/"
mkdir -p "$HOME/Library/LaunchAgents"
cp "dist/com.murat-taskaynatan.logi-fine-volume.hotkeys.plist" "$HOME/Library/LaunchAgents/"
launchctl bootstrap "gui/$(id -u)" "$HOME/Library/LaunchAgents/com.murat-taskaynatan.logi-fine-volume.hotkeys.plist"
launchctl kickstart -k "gui/$(id -u)/com.murat-taskaynatan.logi-fine-volume.hotkeys"
```

3. Open Logi Options+.
4. Select your Logitech keyboard.
5. Change the `Volume Down` button action to `Keystroke Assignment`.
6. Record `Control + Option + Command + J`.
7. Change the `Volume Up` button action to `Keystroke Assignment`.
8. Record `Control + Option + Command + K`.

After the helper launches, use its menu bar icon to:

- enable or disable fine-volume hotkeys
- enable or disable the custom overlay
- change the live step size used by the hotkeys

Why this helper is needed:

- Logi Options+ usually intercepts the Logitech button first instead of passing a clean raw event straight to macOS
- a plain keystroke assignment is not enough on its own because macOS needs a running app to listen for that shortcut
- Karabiner is unreliable here because it often does not receive a stable original hardware event from the Logitech side
- this helper is the listener that catches the Logi shortcut and changes volume directly

## What the helper does

- `Control + Option + Command + J` lowers output volume by the configured step
- `Control + Option + Command + K` raises output volume by the configured step
- volume is clamped between `0` and `100`
- the helper unmutes output when adjusting volume
- the helper shows a small custom volume HUD because the built-in macOS media overlay is not available through this workaround
- the helper runs at login through a user LaunchAgent
- the helper shows a menu bar icon with persistent toggles for hotkeys and overlay display

## Change the amount

For day-to-day use, change the amount from the helper's menu bar icon:

1. Open `Logi Fine Volume` in the menu bar.
2. Open `Step Size`.
3. Choose the percentage you want.

That change applies immediately and is saved.

If you want to change the build-time default for new installs, edit:

- [build_apps.sh](scripts/build_apps.sh)

Change `STEP_SIZE`, then rebuild:

```sh
./scripts/build_apps.sh
```

## Troubleshooting

- If a key triggers the macOS alert sound, the hotkey helper is not running or the button is assigned to the wrong keystroke.
- If the volume changes by the normal large step, the key is still mapped to Logitech's default media control.
- If nothing happens, open `~/Applications/Logi Fine Volume Hotkeys.app` manually once and try again.
- If the overlay does not appear, check the helper's menu bar icon and make sure `Show Overlay` is enabled.
- If the hotkeys work but the amount is wrong, check the helper's `Step Size` menu.
- If you change `STEP_SIZE`, rebuild and reinstall both the app and the LaunchAgent plist.
