import Carbon
import Foundation

enum FineVolumeCLIError: Error {
  case usage(String)
}

private let cliBundleIdentifier = "\(fineVolumeIdentifierPrefix).cli"

func printUsage() {
  let usage = """
  Usage:
    fine-volume up
    fine-volume down
    fine-volume status
    fine-volume step-size <1-10>
    fine-volume hotkeys <on|off>
    fine-volume overlay <on|off>
    fine-volume shortcut <down|up> <Control+Option+Command+J>
    fine-volume shortcut <down|up> default
    fine-volume shortcuts reset
  """
  print(usage)
}

func printStatus() {
  print("Hotkeys: \(fineVolumeHotkeysEnabled() ? "on" : "off")")
  print("Overlay: \(fineVolumeOverlayEnabled() ? "on" : "off")")
  print("Step size: \(fineVolumeStepSize())%")
  print("Volume Down shortcut: \(hotkeyDisplayString(fineVolumeDownHotkey()))")
  print("Volume Up shortcut: \(hotkeyDisplayString(fineVolumeUpHotkey()))")
}

func parseToggle(_ value: String) -> Bool? {
  switch value.lowercased() {
  case "on", "true", "enabled":
    return true
  case "off", "false", "disabled":
    return false
  default:
    return nil
  }
}

func performCLIAdjustment(step: Int, source: String) {
  performVolumeStep(
    step: step,
    source: source,
    bundleURL: nil,
    bundleIdentifier: cliBundleIdentifier,
    bundlePath: URL(fileURLWithPath: CommandLine.arguments.first ?? "fine-volume").path
  )
}

func setShortcut(direction: String, value: String) throws {
  if value.lowercased() == "default" {
    if direction == "down" {
      setFineVolumeDownHotkey(HotkeyDescriptor(keyCode: UInt32(kVK_ANSI_J), modifiers: UInt32(cmdKey | optionKey | controlKey)))
      print("Volume Down shortcut reset to \(hotkeyDisplayString(fineVolumeDownHotkey()))")
    } else {
      setFineVolumeUpHotkey(HotkeyDescriptor(keyCode: UInt32(kVK_ANSI_K), modifiers: UInt32(cmdKey | optionKey | controlKey)))
      print("Volume Up shortcut reset to \(hotkeyDisplayString(fineVolumeUpHotkey()))")
    }
    return
  }

  guard let descriptor = parseHotkeyDescriptor(value) else {
    throw FineVolumeCLIError.usage("Could not parse shortcut: \(value)")
  }

  let otherShortcut = direction == "down" ? fineVolumeUpHotkey() : fineVolumeDownHotkey()
  if descriptor == otherShortcut {
    throw FineVolumeCLIError.usage("Volume Up and Volume Down cannot use the same shortcut")
  }

  if direction == "down" {
    setFineVolumeDownHotkey(descriptor)
    print("Volume Down shortcut set to \(hotkeyDisplayString(descriptor))")
  } else {
    setFineVolumeUpHotkey(descriptor)
    print("Volume Up shortcut set to \(hotkeyDisplayString(descriptor))")
  }
}

func runCLI(arguments: [String]) throws {
  guard let command = arguments.first else {
    printUsage()
    return
  }

  switch command {
  case "up":
    performCLIAdjustment(step: fineVolumeStepSize(), source: "cli_up")
  case "down":
    performCLIAdjustment(step: -fineVolumeStepSize(), source: "cli_down")
  case "status":
    printStatus()
  case "step-size":
    guard arguments.count == 2, let stepSize = Int(arguments[1]) else {
      throw FineVolumeCLIError.usage("Usage: fine-volume step-size <1-10>")
    }
    setFineVolumeStepSize(stepSize)
    print("Step size set to \(fineVolumeStepSize())%")
  case "hotkeys":
    guard arguments.count == 2, let enabled = parseToggle(arguments[1]) else {
      throw FineVolumeCLIError.usage("Usage: fine-volume hotkeys <on|off>")
    }
    setFineVolumeHotkeysEnabled(enabled)
    print("Hotkeys \(enabled ? "enabled" : "disabled")")
  case "overlay":
    guard arguments.count == 2, let enabled = parseToggle(arguments[1]) else {
      throw FineVolumeCLIError.usage("Usage: fine-volume overlay <on|off>")
    }
    setFineVolumeOverlayEnabled(enabled)
    if !enabled {
      hideHUDService()
    }
    print("Overlay \(enabled ? "enabled" : "disabled")")
  case "shortcut":
    guard arguments.count >= 3 else {
      throw FineVolumeCLIError.usage("Usage: fine-volume shortcut <down|up> <shortcut|default>")
    }

    let direction = arguments[1].lowercased()
    guard direction == "down" || direction == "up" else {
      throw FineVolumeCLIError.usage("Shortcut direction must be down or up")
    }

    let value = arguments.dropFirst(2).joined(separator: " ")
    try setShortcut(direction: direction, value: value)
  case "shortcuts":
    guard arguments.count == 2, arguments[1].lowercased() == "reset" else {
      throw FineVolumeCLIError.usage("Usage: fine-volume shortcuts reset")
    }
    resetFineVolumeHotkeysToDefault()
    print("Shortcuts reset to defaults")
  case "help", "--help", "-h":
    printUsage()
  default:
    throw FineVolumeCLIError.usage("Unknown command: \(command)")
  }
}

@main
struct FineVolumeCLI {
  static func main() {
    registerSharedDefaults()

    do {
      try runCLI(arguments: Array(CommandLine.arguments.dropFirst()))
    } catch FineVolumeCLIError.usage(let message) {
      fputs("\(message)\n\n", stderr)
      printUsage()
      exit(1)
    } catch {
      fputs("Unexpected error: \(error)\n", stderr)
      exit(1)
    }
  }
}
