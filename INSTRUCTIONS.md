# Instructions

## Quick setup

1. Build the helper apps:

```sh
./scripts/build_apps.sh
```

2. Copy them to `/Applications`:

```sh
cp -R "dist/Logi Fine Volume Down.app" /Applications/
cp -R "dist/Logi Fine Volume Up.app" /Applications/
```

3. Open Logi Options+.
4. Select your Logitech keyboard.
5. Change the `Volume Down` button action to launch `Logi Fine Volume Down.app`.
6. Change the `Volume Up` button action to launch `Logi Fine Volume Up.app`.

## What the apps do

- `Logi Fine Volume Down.app` lowers output volume by `2`
- `Logi Fine Volume Up.app` raises output volume by `2`
- volume is clamped between `0` and `100`
- the apps unmute output when adjusting volume
- the generated apps are background-only to reduce frontmost-window flicker
- the apps show a small custom volume HUD because the built-in macOS media overlay is not available through this workaround

## Change the amount

Edit:

- [fine_volume_down.applescript](src/fine_volume_down.applescript)
- [fine_volume_up.applescript](src/fine_volume_up.applescript)

Change:

```applescript
set step to 2
```

Then rebuild:

```sh
./scripts/build_apps.sh
```

## Troubleshooting

- If Logi Options+ does not show the generated apps, use the copies in `/Applications`.
- If a key beeps, it is probably still assigned to a keystroke shortcut instead of an application action.
- If the volume changes by the normal large step, the key is still mapped to Logitech's default media control.
- If the active window blinks, replace older generated apps with a fresh build from this version of the repo.
