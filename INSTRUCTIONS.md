# Instructions

## Quick setup

1. Build the tools:

```sh
./scripts/build_apps.sh
```

2. Install the menu bar helper:

```sh
cp -R "dist/Fine Volume Hotkeys.app" "$HOME/Applications/"
mkdir -p "$HOME/Library/LaunchAgents"
cp "dist/com.murat-taskaynatan.fine-volume.hotkeys.plist" "$HOME/Library/LaunchAgents/"
launchctl bootstrap "gui/$(id -u)" "$HOME/Library/LaunchAgents/com.murat-taskaynatan.fine-volume.hotkeys.plist"
launchctl kickstart -k "gui/$(id -u)/com.murat-taskaynatan.fine-volume.hotkeys"
```

3. If you want the CLI too:

```sh
install -m 755 "dist/fine-volume" /usr/local/bin/fine-volume
```

If `/usr/local/bin` is not writable, install it to `~/bin/fine-volume` instead and point your controller software at that full path.

## Logitech MX Creative Console or MX Keys

1. Open Logi Options+.
2. Select your device.
3. Change `Volume Down` to `Keystroke Assignment`.
4. Record `Control + Option + Command + J`.
5. Change `Volume Up` to `Keystroke Assignment`.
6. Record `Control + Option + Command + K`.

Why this helper is needed:

- Logi Options+ often intercepts the Logitech control before macOS sees a clean raw hardware event.
- A plain keystroke assignment is only half the solution because macOS still needs a running app to listen for that shortcut.
- Karabiner is unreliable here because it often does not receive a stable original Logitech event.
- `Fine Volume Hotkeys.app` is the listener that catches the shortcut and changes volume directly.

## Stream Deck or other consoles

Pick one trigger style:

### Send the hotkeys

- `Control + Option + Command + J`
- `Control + Option + Command + K`

### Launch the helper apps

```sh
cp -R "dist/Fine Volume Down.app" "$HOME/Applications/"
cp -R "dist/Fine Volume Up.app" "$HOME/Applications/"
```

Then point your console software at:

- `~/Applications/Fine Volume Down.app`
- `~/Applications/Fine Volume Up.app`

### Run the CLI

```sh
fine-volume down
fine-volume up
```

If your controller software does not inherit your shell `PATH`, use the full path to the binary instead of only `fine-volume`.

## What the helper does

- changes output volume by the configured exact step
- clamps volume between `0` and `100`
- unmutes output when adjusting volume
- can show a small custom volume HUD
- runs at login through a user LaunchAgent
- shows a menu bar icon with controls for hotkeys, overlay, step size, and shortcuts

## Change the amount

From the menu bar:

1. Open `Fine Volume`.
2. Open `Step Size`.
3. Choose the percentage you want.

From the CLI:

```sh
fine-volume step-size 5
```

## Change the shortcuts

From the menu bar:

1. Open `Fine Volume`.
2. Open `Shortcuts`.
3. Choose the shortcut you want to change.
4. Press the new shortcut.

From the CLI:

```sh
fine-volume shortcut down Control+Option+Command+H
fine-volume shortcut up Control+Option+Command+L
fine-volume shortcuts reset
```

## Troubleshooting

- If a Logitech control triggers the macOS alert sound, the helper is not running or Logi Options+ is sending a different shortcut.
- If the volume changes by the normal large step, the control is still mapped to the default media action.
- If Karabiner works with the built-in keyboard but not the Logitech control, Logi Options+ probably intercepted the original event first.
- If Stream Deck or another console can run shell commands cleanly, `fine-volume down` and `fine-volume up` are usually the most direct setup.
- If the overlay does not appear, check the menu bar icon and make sure `Show Overlay` is enabled.
- If the amount is wrong, use `fine-volume status` or check the helper's `Step Size` menu.
