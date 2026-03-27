import AppKit
import Carbon
import Foundation

let hotkeyModifiers = UInt32(cmdKey | optionKey | controlKey)
let downHotkeyID: UInt32 = 1
let upHotkeyID: UInt32 = 2

func hotkeyEventHandler(
  _ nextHandler: EventHandlerCallRef?,
  _ event: EventRef?,
  _ userData: UnsafeMutableRawPointer?
) -> OSStatus {
  guard let event, let userData else {
    return noErr
  }

  let controller = Unmanaged<HotkeyController>.fromOpaque(userData).takeUnretainedValue()
  controller.handle(event: event)
  return noErr
}

final class HotkeyController {
  private var downHotkeyRef: EventHotKeyRef?
  private var upHotkeyRef: EventHotKeyRef?
  private var eventHandlerRef: EventHandlerRef?
  private let bundleURL = Bundle.main.bundleURL
  private let bundleIdentifier = Bundle.main.bundleIdentifier ?? "com.murat-taskaynatan.logi-fine-volume.hotkeys"
  private let bundlePath = Bundle.main.bundlePath

  func start() {
    var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
    let selfPointer = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())

    InstallEventHandler(
      GetApplicationEventTarget(),
      hotkeyEventHandler,
      1,
      &eventType,
      selfPointer,
      &eventHandlerRef
    )

    register(keyCode: UInt32(kVK_ANSI_J), id: downHotkeyID, ref: &downHotkeyRef)
    register(keyCode: UInt32(kVK_ANSI_K), id: upHotkeyID, ref: &upHotkeyRef)

    appendLog(
      "hotkeys_ready bundle=\(bundleIdentifier) down=ctrl+opt+cmd+j step=-\(fineVolumeStepSize()) up=ctrl+opt+cmd+k step=\(fineVolumeStepSize())"
    )
  }

  private func register(keyCode: UInt32, id: UInt32, ref: inout EventHotKeyRef?) {
    let hotKeyID = EventHotKeyID(signature: OSType(0x4c465648), id: id)
    RegisterEventHotKey(
      keyCode,
      hotkeyModifiers,
      hotKeyID,
      GetApplicationEventTarget(),
      0,
      &ref
    )
  }

  func handle(event: EventRef) {
    guard fineVolumeHotkeysEnabled() else {
      appendLog("hotkey_ignored bundle=\(bundleIdentifier) reason=disabled")
      return
    }

    var hotKeyID = EventHotKeyID()
    let status = GetEventParameter(
      event,
      EventParamName(kEventParamDirectObject),
      EventParamType(typeEventHotKeyID),
      nil,
      MemoryLayout<EventHotKeyID>.size,
      nil,
      &hotKeyID
    )

    guard status == noErr else {
      appendLog("hotkey_error bundle=\(bundleIdentifier) reason=event_parameter status=\(status)")
      return
    }

    switch hotKeyID.id {
    case downHotkeyID:
      performVolumeStep(
        step: -fineVolumeStepSize(),
        source: "hotkey_down",
        bundleURL: bundleURL,
        bundleIdentifier: bundleIdentifier,
        bundlePath: bundlePath
      )
    case upHotkeyID:
      performVolumeStep(
        step: fineVolumeStepSize(),
        source: "hotkey_up",
        bundleURL: bundleURL,
        bundleIdentifier: bundleIdentifier,
        bundlePath: bundlePath
      )
    default:
      appendLog("hotkey_ignored bundle=\(bundleIdentifier) id=\(hotKeyID.id)")
    }
  }
}

final class StatusBarController: NSObject, NSMenuDelegate {
  private let stepSizeOptions = [1, 2, 3, 5, 10]
  private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
  private let menu = NSMenu()
  private let titleItem = NSMenuItem(title: "Logi Fine Volume", action: nil, keyEquivalent: "")
  private let hotkeysItem = NSMenuItem(title: "Enable Fine Volume", action: #selector(toggleHotkeys), keyEquivalent: "")
  private let overlayItem = NSMenuItem(title: "Show Overlay", action: #selector(toggleOverlay), keyEquivalent: "")
  private let stepSizeItem = NSMenuItem(title: "Step Size", action: nil, keyEquivalent: "")
  private let stepSizeMenu = NSMenu()
  private let shortcutsItem = NSMenuItem(title: "Shortcuts: Ctrl+Opt+Cmd+J/K", action: nil, keyEquivalent: "")

  override init() {
    super.init()

    titleItem.isEnabled = false
    shortcutsItem.isEnabled = false
    hotkeysItem.target = self
    overlayItem.target = self
    stepSizeItem.submenu = stepSizeMenu

    menu.delegate = self
    menu.addItem(titleItem)
    menu.addItem(NSMenuItem.separator())
    menu.addItem(hotkeysItem)
    menu.addItem(overlayItem)
    menu.addItem(stepSizeItem)
    menu.addItem(NSMenuItem.separator())
    menu.addItem(shortcutsItem)

    stepSizeMenu.autoenablesItems = false
    for stepSize in stepSizeOptions {
      let item = NSMenuItem(
        title: "\(stepSize)%",
        action: #selector(selectStepSize(_:)),
        keyEquivalent: ""
      )
      item.target = self
      item.representedObject = stepSize
      stepSizeMenu.addItem(item)
    }

    statusItem.menu = menu
    refresh()
  }

  func refresh() {
    hotkeysItem.state = fineVolumeHotkeysEnabled() ? .on : .off
    overlayItem.state = fineVolumeOverlayEnabled() ? .on : .off
    let currentStepSize = fineVolumeStepSize()
    stepSizeItem.title = "Step Size (\(currentStepSize)%)"
    for item in stepSizeMenu.items {
      item.state = (item.representedObject as? Int) == currentStepSize ? .on : .off
    }
    updateStatusButton()
  }

  func menuWillOpen(_ menu: NSMenu) {
    refresh()
  }

  private func updateStatusButton() {
    guard let button = statusItem.button else {
      return
    }

    let symbolName: String
    if !fineVolumeHotkeysEnabled() {
      symbolName = "speaker.slash.fill"
    } else if fineVolumeOverlayEnabled() {
      symbolName = "speaker.wave.2.fill"
    } else {
      symbolName = "speaker.wave.2"
    }

    if let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "Logi Fine Volume") {
      image.isTemplate = true
      button.image = image
      button.title = ""
    } else {
      button.image = nil
      button.title = fineVolumeHotkeysEnabled() ? "LFV" : "LFV Off"
    }

    if fineVolumeHotkeysEnabled() {
      button.toolTip = fineVolumeOverlayEnabled() ? "Logi Fine Volume: on" : "Logi Fine Volume: overlay off"
    } else {
      button.toolTip = "Logi Fine Volume: disabled"
    }
  }

  @objc private func toggleHotkeys() {
    let enabled = !fineVolumeHotkeysEnabled()
    setFineVolumeHotkeysEnabled(enabled)
    appendLog("settings hotkeys_enabled=\(enabled)")
    refresh()
  }

  @objc private func toggleOverlay() {
    let enabled = !fineVolumeOverlayEnabled()
    setFineVolumeOverlayEnabled(enabled)
    if !enabled {
      hideHUDService()
    }
    appendLog("settings overlay_enabled=\(enabled)")
    refresh()
  }

  @objc private func selectStepSize(_ sender: NSMenuItem) {
    guard let stepSize = sender.representedObject as? Int else {
      return
    }

    setFineVolumeStepSize(stepSize)
    appendLog("settings step_size=\(stepSize)")
    refresh()
  }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
  private let controller = HotkeyController()
  private var statusBarController: StatusBarController?

  func applicationDidFinishLaunching(_ notification: Notification) {
    registerSharedDefaults()
    controller.start()
    statusBarController = StatusBarController()
  }
}

@main
struct VolumeHotkeysApp {
  static func main() {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
  }
}
