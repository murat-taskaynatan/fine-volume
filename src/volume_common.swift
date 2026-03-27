import AppKit
import Darwin
import Foundation

func clamp(_ value: Int) -> Int {
  max(0, min(100, value))
}

let hudNotificationName = Notification.Name("com.murat-taskaynatan.logi-fine-volume.hud-update")
let hudPIDFile = URL(fileURLWithPath: NSTemporaryDirectory())
  .appendingPathComponent("com.murat-taskaynatan.logi-fine-volume.hud.pid")
let logFileURL = FileManager.default.homeDirectoryForCurrentUser
  .appendingPathComponent("Library")
  .appendingPathComponent("Logs")
  .appendingPathComponent("logi-fine-volume.log")
let settingsSuiteName = "com.murat-taskaynatan.logi-fine-volume.shared"
let hotkeysEnabledKey = "hotkeys_enabled"
let overlayEnabledKey = "overlay_enabled"
let stepSizeKey = "step_size"

func normalizedStepSize(_ value: Int) -> Int {
  max(1, min(10, value))
}

func sharedDefaults() -> UserDefaults {
  UserDefaults(suiteName: settingsSuiteName) ?? .standard
}

func synchronizeSharedDefaults() {
  CFPreferencesAppSynchronize(settingsSuiteName as CFString)
}

func registerSharedDefaults() {
  sharedDefaults().register(defaults: [
    hotkeysEnabledKey: true,
    overlayEnabledKey: true,
    stepSizeKey: normalizedStepSize(Bundle.main.object(forInfoDictionaryKey: "LFVStepSizeDefault") as? Int ?? 2),
  ])
}

func fineVolumeHotkeysEnabled() -> Bool {
  registerSharedDefaults()
  return sharedDefaults().bool(forKey: hotkeysEnabledKey)
}

func setFineVolumeHotkeysEnabled(_ enabled: Bool) {
  let defaults = sharedDefaults()
  defaults.set(enabled, forKey: hotkeysEnabledKey)
  synchronizeSharedDefaults()
}

func fineVolumeOverlayEnabled() -> Bool {
  registerSharedDefaults()
  return sharedDefaults().bool(forKey: overlayEnabledKey)
}

func setFineVolumeOverlayEnabled(_ enabled: Bool) {
  let defaults = sharedDefaults()
  defaults.set(enabled, forKey: overlayEnabledKey)
  synchronizeSharedDefaults()
}

func fineVolumeStepSize() -> Int {
  registerSharedDefaults()
  return normalizedStepSize(sharedDefaults().integer(forKey: stepSizeKey))
}

func setFineVolumeStepSize(_ stepSize: Int) {
  let defaults = sharedDefaults()
  defaults.set(normalizedStepSize(stepSize), forKey: stepSizeKey)
  synchronizeSharedDefaults()
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

func showHUD(from bundleURL: URL, volume: Int) {
  guard fineVolumeOverlayEnabled() else {
    return
  }

  if hudServiceIsRunning() {
    postHUDUpdate(volume: volume)
  } else {
    launchHUDService(from: bundleURL, initialVolume: volume)
  }
}

func performVolumeStep(step: Int, source: String, bundleURL: URL, bundleIdentifier: String, bundlePath: String) {
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
