import AppKit
import Darwin
import Foundation

func clamp(_ value: Int) -> Int {
  max(0, min(100, value))
}

let hudNotificationName = Notification.Name("com.murat-taskaynatan.logi-fine-volume.hud-update")
let hudPIDFile = URL(fileURLWithPath: NSTemporaryDirectory())
  .appendingPathComponent("com.murat-taskaynatan.logi-fine-volume.hud.pid")

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

func launchHUDService(initialVolume: Int) {
  guard let bundleURL = Bundle.main.bundleURL as URL? else {
    return
  }

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

func showHUD(volume: Int) {
  if hudServiceIsRunning() {
    postHUDUpdate(volume: volume)
  } else {
    launchHUDService(initialVolume: volume)
  }
}

let step = Bundle.main.object(forInfoDictionaryKey: "LFVStep") as? Int ?? 0
if step != 0, let volume = try? adjustedVolume(step: step) {
  showHUD(volume: volume)
}
