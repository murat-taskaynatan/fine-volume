# logi-fine-volume

Fine-grained macOS volume control for Logitech keyboards using Logi Options+.

This project builds two tiny macOS helper apps:

- `Logi Fine Volume Down.app`
- `Logi Fine Volume Up.app`

Each app changes the system output volume by an exact step and shows a small custom HUD. This avoids relying on Logitech media keys being intercepted correctly by Karabiner.

## Why this exists

Some Logitech keyboards on macOS, including MX-series devices, send media keys through Logi Options+ in a way that does not reliably reach Karabiner as raw keyboard events. The result is that:

- normal media volume works
- Karabiner remaps may not trigger
- custom shortcut fallbacks may beep instead of being handled

This repo avoids that path by letting Logi Options+ launch small apps directly.

The generated apps are background-only bundles. They do not use the AppleScript applet runtime, which helps avoid the visible blink/focus disturbance that can happen when launching hidden AppleScript apps repeatedly.

## Repo layout

- `src/fine_volume_down.applescript`
- `src/fine_volume_up.applescript`
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

The generated apps will be written to:

```text
dist/Logi Fine Volume Down.app
dist/Logi Fine Volume Up.app
```

Each generated app contains:

- an AppleScript that sets the new exact volume
- a small background HUD binary that displays the current volume percentage

## Install

After building, either:

1. Leave the apps in `dist/` and select them directly from Logi Options+, or
2. Copy them to `/Applications` for easier browsing in app pickers.

Example:

```sh
cp -R "dist/Logi Fine Volume Down.app" /Applications/
cp -R "dist/Logi Fine Volume Up.app" /Applications/
```

## Configure Logi Options+

1. Open Logi Options+.
2. Select your Logitech keyboard.
3. Reassign the `Volume Down` key.
4. Choose an action that launches an application.
5. Select `Logi Fine Volume Down.app`.
6. Reassign the `Volume Up` key.
7. Select `Logi Fine Volume Up.app`.

Depending on your version of Logi Options+, this may appear as:

- `Smart Actions`
- `Application`
- `Open application`

## Change the step size

Both scripts use:

```applescript
set step to 2
```

Change that value in:

- `src/fine_volume_down.applescript`
- `src/fine_volume_up.applescript`

Then rebuild the apps:

```sh
./scripts/build_apps.sh
```

## Verify

After assigning the apps in Logi Options+:

- press volume up once and confirm the system volume increases by a small exact amount
- press volume down once and confirm it decreases by the same amount
- confirm there is no repeated beep from a failed keyboard shortcut
- confirm a small custom volume HUD appears without stealing focus

## Troubleshooting

- If Logi Options+ cannot find the apps, copy them to `/Applications`.
- If the button still behaves like normal macOS volume, make sure the key is assigned to the helper app and not to the default media action.
- If nothing happens, try launching the generated app manually from Finder once to confirm macOS allows it to run.
- If the active window blinks when a helper runs, rebuild with the current version of this repo and replace the older helper apps. Older builds used AppleScript applets, which were more likely to disturb the frontmost app.
- If you changed the scripts, rebuild before retesting.

## Step-by-step guide

See [INSTRUCTIONS.md](INSTRUCTIONS.md) for a shorter setup walkthrough.
