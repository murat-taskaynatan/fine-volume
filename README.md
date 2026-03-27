# logi-fine-volume

Fine-grained macOS volume control for Logitech keyboards using Logi Options+ Smart Actions.

This repo contains two AppleScripts and a build script that generate small macOS app bundles:

- `Logi Fine Volume Down.app`
- `Logi Fine Volume Up.app`

Each app adjusts the system output volume by an exact step without relying on Karabiner remaps for the Logitech media keys.

## Files

- `src/fine_volume_down.applescript`
- `src/fine_volume_up.applescript`
- `scripts/build_apps.sh`

## Build

```sh
./scripts/build_apps.sh
```

The script writes the generated apps to `dist/`.

## Use With Logi Options+

1. Open Logi Options+.
2. Create two Smart Actions or application-launch assignments.
3. Assign volume down to `dist/Logi Fine Volume Down.app`.
4. Assign volume up to `dist/Logi Fine Volume Up.app`.

## Change Step Size

Edit `step` in both AppleScript files.
