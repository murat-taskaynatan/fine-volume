import AppKit
import Carbon
import Darwin
import Foundation

func clamp(_ value: Int) -> Int {
  max(0, min(100, value))
}

struct HotkeyDescriptor: Equatable {
  let keyCode: UInt32
  let modifiers: UInt32
}

private struct SupportedHotkeyKey {
  let code: UInt32
  let displayName: String
  let tokens: [String]
}

let fineVolumeIdentifierPrefix = "com.murat-taskaynatan.fine-volume"
let hudNotificationName = Notification.Name("\(fineVolumeIdentifierPrefix).hud-update")
let settingsNotificationName = Notification.Name("\(fineVolumeIdentifierPrefix).settings-update")
let hudPIDFile = URL(fileURLWithPath: NSTemporaryDirectory())
  .appendingPathComponent("\(fineVolumeIdentifierPrefix).hud.pid")
let logFileURL = FileManager.default.homeDirectoryForCurrentUser
  .appendingPathComponent("Library")
  .appendingPathComponent("Logs")
  .appendingPathComponent("fine-volume.log")
let settingsSuiteName = "\(fineVolumeIdentifierPrefix).shared"
let legacySettingsSuiteName = "com.murat-taskaynatan.logi-fine-volume.shared"
let settingsMigrationKey = "settings_migrated_v2"
let hotkeysEnabledKey = "hotkeys_enabled"
let overlayEnabledKey = "overlay_enabled"
let stepSizeKey = "step_size"
let downHotkeyKeyCodeKey = "down_hotkey_key_code"
let downHotkeyModifiersKey = "down_hotkey_modifiers"
let upHotkeyKeyCodeKey = "up_hotkey_key_code"
let upHotkeyModifiersKey = "up_hotkey_modifiers"

private let supportedHotkeyKeys: [SupportedHotkeyKey] = [
  SupportedHotkeyKey(code: UInt32(kVK_ANSI_A), displayName: "A", tokens: ["a"]),
  SupportedHotkeyKey(code: UInt32(kVK_ANSI_B), displayName: "B", tokens: ["b"]),
  SupportedHotkeyKey(code: UInt32(kVK_ANSI_C), displayName: "C", tokens: ["c"]),
  SupportedHotkeyKey(code: UInt32(kVK_ANSI_D), displayName: "D", tokens: ["d"]),
  SupportedHotkeyKey(code: UInt32(kVK_ANSI_E), displayName: "E", tokens: ["e"]),
  SupportedHotkeyKey(code: UInt32(kVK_ANSI_F), displayName: "F", tokens: ["f"]),
  SupportedHotkeyKey(code: UInt32(kVK_ANSI_G), displayName: "G", tokens: ["g"]),
  SupportedHotkeyKey(code: UInt32(kVK_ANSI_H), displayName: "H", tokens: ["h"]),
  SupportedHotkeyKey(code: UInt32(kVK_ANSI_I), displayName: "I", tokens: ["i"]),
  SupportedHotkeyKey(code: UInt32(kVK_ANSI_J), displayName: "J", tokens: ["j"]),
  SupportedHotkeyKey(code: UInt32(kVK_ANSI_K), displayName: "K", tokens: ["k"]),
  SupportedHotkeyKey(code: UInt32(kVK_ANSI_L), displayName: "L", tokens: ["l"]),
  SupportedHotkeyKey(code: UInt32(kVK_ANSI_M), displayName: "M", tokens: ["m"]),
  SupportedHotkeyKey(code: UInt32(kVK_ANSI_N), displayName: "N", tokens: ["n"]),
  SupportedHotkeyKey(code: UInt32(kVK_ANSI_O), displayName: "O", tokens: ["o"]),
  SupportedHotkeyKey(code: UInt32(kVK_ANSI_P), displayName: "P", tokens: ["p"]),
  SupportedHotkeyKey(code: UInt32(kVK_ANSI_Q), displayName: "Q", tokens: ["q"]),
  SupportedHotkeyKey(code: UInt32(kVK_ANSI_R), displayName: "R", tokens: ["r"]),
  SupportedHotkeyKey(code: UInt32(kVK_ANSI_S), displayName: "S", tokens: ["s"]),
  SupportedHotkeyKey(code: UInt32(kVK_ANSI_T), displayName: "T", tokens: ["t"]),
  SupportedHotkeyKey(code: UInt32(kVK_ANSI_U), displayName: "U", tokens: ["u"]),
  SupportedHotkeyKey(code: UInt32(kVK_ANSI_V), displayName: "V", tokens: ["v"]),
  SupportedHotkeyKey(code: UInt32(kVK_ANSI_W), displayName: "W", tokens: ["w"]),
  SupportedHotkeyKey(code: UInt32(kVK_ANSI_X), displayName: "X", tokens: ["x"]),
  SupportedHotkeyKey(code: UInt32(kVK_ANSI_Y), displayName: "Y", tokens: ["y"]),
  SupportedHotkeyKey(code: UInt32(kVK_ANSI_Z), displayName: "Z", tokens: ["z"]),
  SupportedHotkeyKey(code: UInt32(kVK_ANSI_0), displayName: "0", tokens: ["0"]),
  SupportedHotkeyKey(code: UInt32(kVK_ANSI_1), displayName: "1", tokens: ["1"]),
  SupportedHotkeyKey(code: UInt32(kVK_ANSI_2), displayName: "2", tokens: ["2"]),
  SupportedHotkeyKey(code: UInt32(kVK_ANSI_3), displayName: "3", tokens: ["3"]),
  SupportedHotkeyKey(code: UInt32(kVK_ANSI_4), displayName: "4", tokens: ["4"]),
  SupportedHotkeyKey(code: UInt32(kVK_ANSI_5), displayName: "5", tokens: ["5"]),
  SupportedHotkeyKey(code: UInt32(kVK_ANSI_6), displayName: "6", tokens: ["6"]),
  SupportedHotkeyKey(code: UInt32(kVK_ANSI_7), displayName: "7", tokens: ["7"]),
  SupportedHotkeyKey(code: UInt32(kVK_ANSI_8), displayName: "8", tokens: ["8"]),
  SupportedHotkeyKey(code: UInt32(kVK_ANSI_9), displayName: "9", tokens: ["9"]),
  SupportedHotkeyKey(code: UInt32(kVK_ANSI_Minus), displayName: "-", tokens: ["-", "minus", "hyphen"]),
  SupportedHotkeyKey(code: UInt32(kVK_ANSI_Equal), displayName: "=", tokens: ["=", "equal", "equals"]),
  SupportedHotkeyKey(code: UInt32(kVK_ANSI_LeftBracket), displayName: "[", tokens: ["[", "leftbracket", "lbracket"]),
  SupportedHotkeyKey(code: UInt32(kVK_ANSI_RightBracket), displayName: "]", tokens: ["]", "rightbracket", "rbracket"]),
  SupportedHotkeyKey(code: UInt32(kVK_ANSI_Backslash), displayName: "\\", tokens: ["\\", "backslash"]),
  SupportedHotkeyKey(code: UInt32(kVK_ANSI_Semicolon), displayName: ";", tokens: [";", "semicolon"]),
  SupportedHotkeyKey(code: UInt32(kVK_ANSI_Quote), displayName: "'", tokens: ["'", "quote", "apostrophe"]),
  SupportedHotkeyKey(code: UInt32(kVK_ANSI_Comma), displayName: ",", tokens: [",", "comma"]),
  SupportedHotkeyKey(code: UInt32(kVK_ANSI_Period), displayName: ".", tokens: [".", "period", "dot"]),
  SupportedHotkeyKey(code: UInt32(kVK_ANSI_Slash), displayName: "/", tokens: ["/", "slash"]),
  SupportedHotkeyKey(code: UInt32(kVK_ANSI_Grave), displayName: "`", tokens: ["`", "grave", "backtick"]),
  SupportedHotkeyKey(code: UInt32(kVK_Return), displayName: "Return", tokens: ["return", "enter"]),
  SupportedHotkeyKey(code: UInt32(kVK_Tab), displayName: "Tab", tokens: ["tab"]),
  SupportedHotkeyKey(code: UInt32(kVK_Space), displayName: "Space", tokens: ["space"]),
  SupportedHotkeyKey(code: UInt32(kVK_Delete), displayName: "Delete", tokens: ["delete", "backspace"]),
  SupportedHotkeyKey(code: UInt32(kVK_ForwardDelete), displayName: "Forward Delete", tokens: ["forwarddelete", "del"]),
  SupportedHotkeyKey(code: UInt32(kVK_Escape), displayName: "Escape", tokens: ["escape", "esc"]),
  SupportedHotkeyKey(code: UInt32(kVK_LeftArrow), displayName: "Left Arrow", tokens: ["leftarrow", "left"]),
  SupportedHotkeyKey(code: UInt32(kVK_RightArrow), displayName: "Right Arrow", tokens: ["rightarrow", "right"]),
  SupportedHotkeyKey(code: UInt32(kVK_DownArrow), displayName: "Down Arrow", tokens: ["downarrow", "down"]),
  SupportedHotkeyKey(code: UInt32(kVK_UpArrow), displayName: "Up Arrow", tokens: ["uparrow", "up"]),
  SupportedHotkeyKey(code: UInt32(kVK_Home), displayName: "Home", tokens: ["home"]),
  SupportedHotkeyKey(code: UInt32(kVK_End), displayName: "End", tokens: ["end"]),
  SupportedHotkeyKey(code: UInt32(kVK_PageUp), displayName: "Page Up", tokens: ["pageup"]),
  SupportedHotkeyKey(code: UInt32(kVK_PageDown), displayName: "Page Down", tokens: ["pagedown"]),
  SupportedHotkeyKey(code: UInt32(kVK_F1), displayName: "F1", tokens: ["f1"]),
  SupportedHotkeyKey(code: UInt32(kVK_F2), displayName: "F2", tokens: ["f2"]),
  SupportedHotkeyKey(code: UInt32(kVK_F3), displayName: "F3", tokens: ["f3"]),
  SupportedHotkeyKey(code: UInt32(kVK_F4), displayName: "F4", tokens: ["f4"]),
  SupportedHotkeyKey(code: UInt32(kVK_F5), displayName: "F5", tokens: ["f5"]),
  SupportedHotkeyKey(code: UInt32(kVK_F6), displayName: "F6", tokens: ["f6"]),
  SupportedHotkeyKey(code: UInt32(kVK_F7), displayName: "F7", tokens: ["f7"]),
  SupportedHotkeyKey(code: UInt32(kVK_F8), displayName: "F8", tokens: ["f8"]),
  SupportedHotkeyKey(code: UInt32(kVK_F9), displayName: "F9", tokens: ["f9"]),
  SupportedHotkeyKey(code: UInt32(kVK_F10), displayName: "F10", tokens: ["f10"]),
  SupportedHotkeyKey(code: UInt32(kVK_F11), displayName: "F11", tokens: ["f11"]),
  SupportedHotkeyKey(code: UInt32(kVK_F12), displayName: "F12", tokens: ["f12"]),
  SupportedHotkeyKey(code: UInt32(kVK_F13), displayName: "F13", tokens: ["f13"]),
  SupportedHotkeyKey(code: UInt32(kVK_F14), displayName: "F14", tokens: ["f14"]),
  SupportedHotkeyKey(code: UInt32(kVK_F15), displayName: "F15", tokens: ["f15"]),
  SupportedHotkeyKey(code: UInt32(kVK_F16), displayName: "F16", tokens: ["f16"]),
  SupportedHotkeyKey(code: UInt32(kVK_F17), displayName: "F17", tokens: ["f17"]),
  SupportedHotkeyKey(code: UInt32(kVK_F18), displayName: "F18", tokens: ["f18"]),
  SupportedHotkeyKey(code: UInt32(kVK_F19), displayName: "F19", tokens: ["f19"]),
  SupportedHotkeyKey(code: UInt32(kVK_F20), displayName: "F20", tokens: ["f20"]),
]

private let defaultHotkeyModifiers = UInt32(cmdKey | optionKey | controlKey)

func normalizedStepSize(_ value: Int) -> Int {
  max(1, min(10, value))
}

func normalizedHotkeyModifiers(_ value: UInt32) -> UInt32 {
  let allowedModifiers = UInt32(cmdKey | optionKey | controlKey | shiftKey)
  return value & allowedModifiers
}

private func defaultHotkey(for direction: String) -> HotkeyDescriptor {
  let defaultKeyCode: Int

  switch direction {
  case "down":
    defaultKeyCode = Bundle.main.object(forInfoDictionaryKey: "LFVDownKeyCodeDefault") as? Int ?? Int(kVK_ANSI_J)
  default:
    defaultKeyCode = Bundle.main.object(forInfoDictionaryKey: "LFVUpKeyCodeDefault") as? Int ?? Int(kVK_ANSI_K)
  }

  let defaultModifiers = Bundle.main.object(forInfoDictionaryKey: "LFVHotkeyModifiersDefault") as? Int
    ?? Int(defaultHotkeyModifiers)

  return HotkeyDescriptor(
    keyCode: UInt32(defaultKeyCode),
    modifiers: normalizedHotkeyModifiers(UInt32(defaultModifiers))
  )
}

func sharedDefaults() -> UserDefaults {
  UserDefaults(suiteName: settingsSuiteName) ?? .standard
}

func synchronizeSharedDefaults() {
  CFPreferencesAppSynchronize(settingsSuiteName as CFString)
}

private func migrateLegacySharedDefaultsIfNeeded() {
  let defaults = sharedDefaults()
  if defaults.bool(forKey: settingsMigrationKey) {
    return
  }

  guard let legacyDefaults = UserDefaults(suiteName: legacySettingsSuiteName) else {
    defaults.set(true, forKey: settingsMigrationKey)
    synchronizeSharedDefaults()
    return
  }

  for key in [hotkeysEnabledKey, overlayEnabledKey, stepSizeKey] {
    if defaults.object(forKey: key) == nil, let value = legacyDefaults.object(forKey: key) {
      defaults.set(value, forKey: key)
    }
  }

  defaults.set(true, forKey: settingsMigrationKey)
  synchronizeSharedDefaults()
}

func registerSharedDefaults() {
  let downDefault = defaultHotkey(for: "down")
  let upDefault = defaultHotkey(for: "up")

  sharedDefaults().register(defaults: [
    hotkeysEnabledKey: true,
    overlayEnabledKey: true,
    stepSizeKey: normalizedStepSize(Bundle.main.object(forInfoDictionaryKey: "LFVStepSizeDefault") as? Int ?? 2),
    downHotkeyKeyCodeKey: Int(downDefault.keyCode),
    downHotkeyModifiersKey: Int(downDefault.modifiers),
    upHotkeyKeyCodeKey: Int(upDefault.keyCode),
    upHotkeyModifiersKey: Int(upDefault.modifiers),
  ])
  migrateLegacySharedDefaultsIfNeeded()
}

func fineVolumeHotkeysEnabled() -> Bool {
  registerSharedDefaults()
  return sharedDefaults().bool(forKey: hotkeysEnabledKey)
}

private func postSettingsUpdate(changedKey: String) {
  DistributedNotificationCenter.default().postNotificationName(
    settingsNotificationName,
    object: nil,
    userInfo: ["key": changedKey],
    deliverImmediately: true
  )
}

func setFineVolumeHotkeysEnabled(_ enabled: Bool) {
  let defaults = sharedDefaults()
  defaults.set(enabled, forKey: hotkeysEnabledKey)
  synchronizeSharedDefaults()
  postSettingsUpdate(changedKey: hotkeysEnabledKey)
}

func fineVolumeOverlayEnabled() -> Bool {
  registerSharedDefaults()
  return sharedDefaults().bool(forKey: overlayEnabledKey)
}

func setFineVolumeOverlayEnabled(_ enabled: Bool) {
  let defaults = sharedDefaults()
  defaults.set(enabled, forKey: overlayEnabledKey)
  synchronizeSharedDefaults()
  postSettingsUpdate(changedKey: overlayEnabledKey)
}

func fineVolumeStepSize() -> Int {
  registerSharedDefaults()
  return normalizedStepSize(sharedDefaults().integer(forKey: stepSizeKey))
}

func setFineVolumeStepSize(_ stepSize: Int) {
  let defaults = sharedDefaults()
  defaults.set(normalizedStepSize(stepSize), forKey: stepSizeKey)
  synchronizeSharedDefaults()
  postSettingsUpdate(changedKey: stepSizeKey)
}

private func hotkeyDescriptor(
  keyCodeKey: String,
  modifiersKey: String,
  fallbackDirection: String
) -> HotkeyDescriptor {
  registerSharedDefaults()
  let defaults = sharedDefaults()
  let fallback = defaultHotkey(for: fallbackDirection)
  let keyCode = UInt32(defaults.object(forKey: keyCodeKey) as? Int ?? Int(fallback.keyCode))
  let modifiers = UInt32(defaults.object(forKey: modifiersKey) as? Int ?? Int(fallback.modifiers))

  return HotkeyDescriptor(
    keyCode: keyCode,
    modifiers: normalizedHotkeyModifiers(modifiers)
  )
}

private func setHotkeyDescriptor(
  _ descriptor: HotkeyDescriptor,
  keyCodeKey: String,
  modifiersKey: String
) {
  let defaults = sharedDefaults()
  defaults.set(Int(descriptor.keyCode), forKey: keyCodeKey)
  defaults.set(Int(normalizedHotkeyModifiers(descriptor.modifiers)), forKey: modifiersKey)
  synchronizeSharedDefaults()
}

func fineVolumeDownHotkey() -> HotkeyDescriptor {
  hotkeyDescriptor(
    keyCodeKey: downHotkeyKeyCodeKey,
    modifiersKey: downHotkeyModifiersKey,
    fallbackDirection: "down"
  )
}

func fineVolumeUpHotkey() -> HotkeyDescriptor {
  hotkeyDescriptor(
    keyCodeKey: upHotkeyKeyCodeKey,
    modifiersKey: upHotkeyModifiersKey,
    fallbackDirection: "up"
  )
}

func setFineVolumeDownHotkey(_ descriptor: HotkeyDescriptor) {
  setHotkeyDescriptor(
    descriptor,
    keyCodeKey: downHotkeyKeyCodeKey,
    modifiersKey: downHotkeyModifiersKey
  )
  postSettingsUpdate(changedKey: downHotkeyKeyCodeKey)
}

func setFineVolumeUpHotkey(_ descriptor: HotkeyDescriptor) {
  setHotkeyDescriptor(
    descriptor,
    keyCodeKey: upHotkeyKeyCodeKey,
    modifiersKey: upHotkeyModifiersKey
  )
  postSettingsUpdate(changedKey: upHotkeyKeyCodeKey)
}

func resetFineVolumeHotkeysToDefault() {
  setHotkeyDescriptor(
    defaultHotkey(for: "down"),
    keyCodeKey: downHotkeyKeyCodeKey,
    modifiersKey: downHotkeyModifiersKey
  )
  setHotkeyDescriptor(
    defaultHotkey(for: "up"),
    keyCodeKey: upHotkeyKeyCodeKey,
    modifiersKey: upHotkeyModifiersKey
  )
  postSettingsUpdate(changedKey: "hotkeys_reset")
}

func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
  var modifiers: UInt32 = 0
  let normalizedFlags = flags.intersection(.deviceIndependentFlagsMask)

  if normalizedFlags.contains(.control) {
    modifiers |= UInt32(controlKey)
  }
  if normalizedFlags.contains(.option) {
    modifiers |= UInt32(optionKey)
  }
  if normalizedFlags.contains(.shift) {
    modifiers |= UInt32(shiftKey)
  }
  if normalizedFlags.contains(.command) {
    modifiers |= UInt32(cmdKey)
  }

  return normalizedHotkeyModifiers(modifiers)
}

func modifierFlags(fromCarbon modifiers: UInt32) -> NSEvent.ModifierFlags {
  var flags: NSEvent.ModifierFlags = []

  if modifiers & UInt32(controlKey) != 0 {
    flags.insert(.control)
  }
  if modifiers & UInt32(optionKey) != 0 {
    flags.insert(.option)
  }
  if modifiers & UInt32(shiftKey) != 0 {
    flags.insert(.shift)
  }
  if modifiers & UInt32(cmdKey) != 0 {
    flags.insert(.command)
  }

  return flags
}

private func supportedKey(for keyCode: UInt32) -> SupportedHotkeyKey? {
  supportedHotkeyKeys.first { $0.code == keyCode }
}

private func supportedKey(for token: String) -> SupportedHotkeyKey? {
  let normalizedToken = token
    .trimmingCharacters(in: .whitespacesAndNewlines)
    .lowercased()
    .replacingOccurrences(of: " ", with: "")
  return supportedHotkeyKeys.first { $0.tokens.contains(normalizedToken) }
}

func hotkeyDescriptor(from event: NSEvent) -> HotkeyDescriptor? {
  let keyCode = UInt32(event.keyCode)
  let modifiers = carbonModifiers(from: event.modifierFlags)

  guard modifiers != 0, supportedKey(for: keyCode) != nil else {
    return nil
  }

  return HotkeyDescriptor(keyCode: keyCode, modifiers: modifiers)
}

private func modifierDisplayTokens(_ modifiers: UInt32) -> [String] {
  var tokens: [String] = []

  if modifiers & UInt32(controlKey) != 0 {
    tokens.append("Control")
  }
  if modifiers & UInt32(optionKey) != 0 {
    tokens.append("Option")
  }
  if modifiers & UInt32(shiftKey) != 0 {
    tokens.append("Shift")
  }
  if modifiers & UInt32(cmdKey) != 0 {
    tokens.append("Command")
  }

  return tokens
}

func hotkeyDisplayString(_ descriptor: HotkeyDescriptor) -> String {
  let keyName = supportedKey(for: descriptor.keyCode)?.displayName ?? "Key \(descriptor.keyCode)"
  let parts = modifierDisplayTokens(descriptor.modifiers) + [keyName]
  return parts.joined(separator: "+")
}

func parseHotkeyDescriptor(_ value: String) -> HotkeyDescriptor? {
  let tokens = value
    .split(separator: "+")
    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    .filter { !$0.isEmpty }

  guard !tokens.isEmpty else {
    return nil
  }

  var modifiers: UInt32 = 0
  var key: SupportedHotkeyKey?

  for token in tokens {
    switch token.lowercased() {
    case "control", "ctrl", "ctl":
      modifiers |= UInt32(controlKey)
    case "option", "opt", "alt":
      modifiers |= UInt32(optionKey)
    case "shift":
      modifiers |= UInt32(shiftKey)
    case "command", "cmd":
      modifiers |= UInt32(cmdKey)
    default:
      guard key == nil, let parsedKey = supportedKey(for: token) else {
        return nil
      }
      key = parsedKey
    }
  }

  guard let key, modifiers != 0 else {
    return nil
  }

  return HotkeyDescriptor(keyCode: key.code, modifiers: normalizedHotkeyModifiers(modifiers))
}

func currentTimestamp() -> String {
  ISO8601DateFormatter().string(from: Date())
}

func appendLog(_ message: String) {
  let line = "\(currentTimestamp()) \(message)\n"
  let data = Data(line.utf8)

  try? FileManager.default.createDirectory(
    at: logFileURL.deletingLastPathComponent(),
    withIntermediateDirectories: true
  )

  if let handle = try? FileHandle(forWritingTo: logFileURL) {
    _ = try? handle.seekToEnd()
    try? handle.write(contentsOf: data)
    try? handle.close()
  } else {
    try? data.write(to: logFileURL, options: .atomic)
  }
}

func currentVolume() throws -> Int {
  let scriptSource = "return output volume of (get volume settings)"

  var error: NSDictionary?
  guard let script = NSAppleScript(source: scriptSource) else {
    throw NSError(domain: "logi-fine-volume", code: 10)
  }

  let result = script.executeAndReturnError(&error)
  if let error {
    throw NSError(domain: "logi-fine-volume", code: 11, userInfo: error as? [String: Any])
  }

  if result.descriptorType == typeSInt32 || result.descriptorType == typeUInt32 {
    return clamp(Int(result.int32Value))
  }

  if let stringValue = result.stringValue, let parsed = Int(stringValue) {
    return clamp(parsed)
  }

  throw NSError(domain: "logi-fine-volume", code: 12)
}

func adjustedVolume(step: Int) throws -> Int {
  let operation = step >= 0 ? "+" : "-"
  let amount = abs(step)
  let scriptSource = """
  set step to \(amount)
  set currentVolume to output volume of (get volume settings)
  set targetVolume to currentVolume \(operation) step
  if targetVolume < 0 then set targetVolume to 0
  if targetVolume > 100 then set targetVolume to 100
  set volume output volume targetVolume output muted false
  return targetVolume
  """

  var error: NSDictionary?
  guard let script = NSAppleScript(source: scriptSource) else {
    throw NSError(domain: "logi-fine-volume", code: 1)
  }

  let result = script.executeAndReturnError(&error)
  if let error {
    throw NSError(domain: "logi-fine-volume", code: 3, userInfo: error as? [String: Any])
  }

  if result.descriptorType == typeSInt32 || result.descriptorType == typeUInt32 {
    return clamp(Int(result.int32Value))
  }

  if let stringValue = result.stringValue, let parsed = Int(stringValue) {
    return clamp(parsed)
  }

  throw NSError(domain: "logi-fine-volume", code: 2)
}

func processExists(pid: Int32) -> Bool {
  guard pid > 0 else {
    return false
  }

  if kill(pid, 0) == 0 {
    return true
  }

  return errno == EPERM
}

func hudServiceIsRunning() -> Bool {
  guard
    let pidText = try? String(contentsOf: hudPIDFile, encoding: .utf8)
      .trimmingCharacters(in: .whitespacesAndNewlines),
    let pid = Int32(pidText)
  else {
    return false
  }

  return processExists(pid: pid)
}

func hideHUDService() {
  guard
    let pidText = try? String(contentsOf: hudPIDFile, encoding: .utf8)
      .trimmingCharacters(in: .whitespacesAndNewlines),
    let pid = Int32(pidText),
    processExists(pid: pid)
  else {
    return
  }

  _ = kill(pid, SIGTERM)
}

func launchHUDService(from bundleURL: URL, initialVolume: Int) {
  let executableURL = bundleURL
    .appendingPathComponent("Contents")
    .appendingPathComponent("MacOS")
    .appendingPathComponent("volume_hud")

  let process = Process()
  process.executableURL = executableURL
  process.arguments = ["--service", "\(initialVolume)"]
  process.standardOutput = nil
  process.standardError = nil
  try? process.run()
}

func postHUDUpdate(volume: Int) {
  DistributedNotificationCenter.default().postNotificationName(
    hudNotificationName,
    object: nil,
    userInfo: ["volume": volume],
    deliverImmediately: true
  )
}

func showHUD(from bundleURL: URL?, volume: Int) {
  guard fineVolumeOverlayEnabled(), let bundleURL else {
    return
  }

  if hudServiceIsRunning() {
    postHUDUpdate(volume: volume)
  } else {
    launchHUDService(from: bundleURL, initialVolume: volume)
  }
}

func performVolumeStep(step: Int, source: String, bundleURL: URL?, bundleIdentifier: String, bundlePath: String) {
  appendLog("launch source=\(source) bundle=\(bundleIdentifier) path=\(bundlePath) step=\(step)")

  guard step != 0 else {
    appendLog("ignored source=\(source) bundle=\(bundleIdentifier) reason=zero_step")
    return
  }

  let beforeVolume = (try? currentVolume()) ?? -1
  if let volume = try? adjustedVolume(step: step) {
    appendLog("success source=\(source) bundle=\(bundleIdentifier) step=\(step) volume=\(beforeVolume)->\(volume)")
    showHUD(from: bundleURL, volume: volume)
  } else {
    appendLog("failure source=\(source) bundle=\(bundleIdentifier) step=\(step)")
  }
}
