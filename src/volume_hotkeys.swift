import AppKit
import Carbon
import Foundation

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
  private let bundleIdentifier = Bundle.main.bundleIdentifier ?? "\(fineVolumeIdentifierPrefix).hotkeys"
  private let bundlePath = Bundle.main.bundlePath

  func start() {
    if eventHandlerRef == nil {
      var eventType = EventTypeSpec(
        eventClass: OSType(kEventClassKeyboard),
        eventKind: UInt32(kEventHotKeyPressed)
      )
      let selfPointer = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())

      InstallEventHandler(
        GetApplicationEventTarget(),
        hotkeyEventHandler,
        1,
        &eventType,
        selfPointer,
        &eventHandlerRef
      )
    }

    reloadHotkeys()
  }

  func reloadHotkeys() {
    unregisterHotkeys()

    let downShortcut = fineVolumeDownHotkey()
    let upShortcut = fineVolumeUpHotkey()

    if downShortcut == upShortcut {
      appendLog("hotkeys_error bundle=\(bundleIdentifier) reason=duplicate_shortcuts shortcut=\(hotkeyDisplayString(downShortcut))")
      register(shortcut: downShortcut, id: downHotkeyID, ref: &downHotkeyRef)
      return
    }

    register(shortcut: downShortcut, id: downHotkeyID, ref: &downHotkeyRef)
    register(shortcut: upShortcut, id: upHotkeyID, ref: &upHotkeyRef)

    appendLog(
      "hotkeys_ready bundle=\(bundleIdentifier) down=\(hotkeyDisplayString(downShortcut)) step=-\(fineVolumeStepSize()) up=\(hotkeyDisplayString(upShortcut)) step=\(fineVolumeStepSize())"
    )
  }

  private func register(shortcut: HotkeyDescriptor, id: UInt32, ref: inout EventHotKeyRef?) {
    let hotKeyID = EventHotKeyID(signature: OSType(0x4649564F), id: id)
    let status = RegisterEventHotKey(
      shortcut.keyCode,
      shortcut.modifiers,
      hotKeyID,
      GetApplicationEventTarget(),
      0,
      &ref
    )

    if status != noErr {
      appendLog(
        "hotkeys_error bundle=\(bundleIdentifier) reason=register status=\(status) shortcut=\(hotkeyDisplayString(shortcut))"
      )
    }
  }

  private func unregisterHotkeys() {
    if let downHotkeyRef {
      UnregisterEventHotKey(downHotkeyRef)
      self.downHotkeyRef = nil
    }

    if let upHotkeyRef {
      UnregisterEventHotKey(upHotkeyRef)
      self.upHotkeyRef = nil
    }
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

final class ShortcutCaptureView: NSView {
  var onShortcut: ((HotkeyDescriptor) -> Void)?
  var onInvalidShortcut: ((String) -> Void)?
  var onCancel: (() -> Void)?

  override var acceptsFirstResponder: Bool {
    true
  }

  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    DispatchQueue.main.async { [weak self] in
      self?.window?.makeFirstResponder(self)
    }
  }

  override func keyDown(with event: NSEvent) {
    if UInt32(event.keyCode) == UInt32(kVK_Escape) {
      onCancel?()
      return
    }

    guard let descriptor = hotkeyDescriptor(from: event) else {
      onInvalidShortcut?("Use a supported key together with Control, Option, Shift, or Command.")
      return
    }

    onShortcut?(descriptor)
  }
}

final class ShortcutRecorderWindowController: NSWindowController, NSWindowDelegate {
  private var completion: ((HotkeyDescriptor?) -> Void)?
  private let statusField = NSTextField(labelWithString: "")
  private let captureView = ShortcutCaptureView(frame: .zero)
  private var didFinish = false

  init(actionName: String, currentShortcut: HotkeyDescriptor, completion: @escaping (HotkeyDescriptor?) -> Void) {
    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 430, height: 180),
      styleMask: [.titled, .closable],
      backing: .buffered,
      defer: false
    )
    self.completion = completion
    super.init(window: window)

    window.title = actionName
    window.isReleasedWhenClosed = false
    window.center()
    window.delegate = self

    let contentView = NSView(frame: window.contentLayoutRect)
    window.contentView = contentView

    let headlineField = NSTextField(labelWithString: actionName)
    headlineField.font = .systemFont(ofSize: 18, weight: .semibold)
    headlineField.frame = NSRect(x: 20, y: 132, width: 390, height: 24)
    contentView.addSubview(headlineField)

    let currentField = NSTextField(labelWithString: "Current: \(hotkeyDisplayString(currentShortcut))")
    currentField.font = .systemFont(ofSize: 13, weight: .regular)
    currentField.textColor = .secondaryLabelColor
    currentField.frame = NSRect(x: 20, y: 108, width: 390, height: 18)
    contentView.addSubview(currentField)

    statusField.font = .systemFont(ofSize: 13, weight: .regular)
    statusField.stringValue = "Press the new shortcut now. Press Escape to cancel."
    statusField.frame = NSRect(x: 20, y: 78, width: 390, height: 18)
    contentView.addSubview(statusField)

    captureView.frame = NSRect(x: 20, y: 20, width: 390, height: 44)
    captureView.wantsLayer = true
    captureView.layer?.cornerRadius = 10
    captureView.layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.85).cgColor
    captureView.onShortcut = { [weak self] descriptor in
      self?.finish(with: descriptor)
    }
    captureView.onInvalidShortcut = { [weak self] message in
      self?.statusField.stringValue = message
      NSSound.beep()
    }
    captureView.onCancel = { [weak self] in
      self?.finish(with: nil)
    }
    contentView.addSubview(captureView)

    let hintField = NSTextField(labelWithString: "Examples: Control+Option+Command+J or Shift+Command+F18")
    hintField.font = .systemFont(ofSize: 12, weight: .regular)
    hintField.textColor = .secondaryLabelColor
    hintField.frame = NSRect(x: 24, y: 32, width: 360, height: 14)
    captureView.addSubview(hintField)

    let cancelButton = NSButton(title: "Cancel", target: self, action: #selector(cancelRecording))
    cancelButton.frame = NSRect(x: 330, y: 12, width: 80, height: 30)
    contentView.addSubview(cancelButton)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    nil
  }

  func showRecorder() {
    NSApplication.shared.activate(ignoringOtherApps: true)
    showWindow(nil)
    window?.makeKeyAndOrderFront(nil)
    window?.makeFirstResponder(captureView)
  }

  func windowWillClose(_ notification: Notification) {
    finish(with: nil)
  }

  @objc private func cancelRecording() {
    finish(with: nil)
  }

  private func finish(with descriptor: HotkeyDescriptor?) {
    guard !didFinish else {
      return
    }

    didFinish = true
    let completion = self.completion
    self.completion = nil
    close()
    completion?(descriptor)
  }
}

final class StatusBarController: NSObject, NSMenuDelegate {
  private let stepSizeOptions = [1, 2, 3, 5, 10]
  private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
  private let menu = NSMenu()
  private let titleItem = NSMenuItem(title: "Fine Volume", action: nil, keyEquivalent: "")
  private let hotkeysItem = NSMenuItem(title: "Enable Fine Volume", action: #selector(toggleHotkeys), keyEquivalent: "")
  private let overlayItem = NSMenuItem(title: "Show Overlay", action: #selector(toggleOverlay), keyEquivalent: "")
  private let stepSizeItem = NSMenuItem(title: "Step Size", action: nil, keyEquivalent: "")
  private let stepSizeMenu = NSMenu()
  private let shortcutsItem = NSMenuItem(title: "Shortcuts", action: nil, keyEquivalent: "")
  private let shortcutsMenu = NSMenu()
  private let downShortcutStatusItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
  private let upShortcutStatusItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
  private let recordDownShortcutItem = NSMenuItem(
    title: "Set Volume Down Shortcut...",
    action: #selector(recordDownShortcut),
    keyEquivalent: ""
  )
  private let recordUpShortcutItem = NSMenuItem(
    title: "Set Volume Up Shortcut...",
    action: #selector(recordUpShortcut),
    keyEquivalent: ""
  )
  private let resetShortcutsItem = NSMenuItem(
    title: "Reset Shortcuts to Default",
    action: #selector(resetShortcuts),
    keyEquivalent: ""
  )
  private var recorderController: ShortcutRecorderWindowController?

  override init() {
    super.init()

    titleItem.isEnabled = false
    downShortcutStatusItem.isEnabled = false
    upShortcutStatusItem.isEnabled = false
    hotkeysItem.target = self
    overlayItem.target = self
    stepSizeItem.submenu = stepSizeMenu
    shortcutsItem.submenu = shortcutsMenu
    recordDownShortcutItem.target = self
    recordUpShortcutItem.target = self
    resetShortcutsItem.target = self

    menu.delegate = self
    menu.addItem(titleItem)
    menu.addItem(NSMenuItem.separator())
    menu.addItem(hotkeysItem)
    menu.addItem(overlayItem)
    menu.addItem(stepSizeItem)
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

    shortcutsMenu.autoenablesItems = false
    shortcutsMenu.addItem(downShortcutStatusItem)
    shortcutsMenu.addItem(upShortcutStatusItem)
    shortcutsMenu.addItem(NSMenuItem.separator())
    shortcutsMenu.addItem(recordDownShortcutItem)
    shortcutsMenu.addItem(recordUpShortcutItem)
    shortcutsMenu.addItem(resetShortcutsItem)

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

    downShortcutStatusItem.title = "Volume Down: \(hotkeyDisplayString(fineVolumeDownHotkey()))"
    upShortcutStatusItem.title = "Volume Up: \(hotkeyDisplayString(fineVolumeUpHotkey()))"
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

    if let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "Fine Volume") {
      image.isTemplate = true
      button.image = image
      button.title = ""
    } else {
      button.image = nil
      button.title = fineVolumeHotkeysEnabled() ? "FV" : "FV Off"
    }

    if fineVolumeHotkeysEnabled() {
      button.toolTip = fineVolumeOverlayEnabled() ? "Fine Volume: on" : "Fine Volume: overlay off"
    } else {
      button.toolTip = "Fine Volume: disabled"
    }
  }

  private func presentAlert(title: String, message: String) {
    NSApplication.shared.activate(ignoringOtherApps: true)
    let alert = NSAlert()
    alert.messageText = title
    alert.informativeText = message
    alert.alertStyle = .warning
    alert.runModal()
  }

  private func beginShortcutRecording(direction: String) {
    let currentShortcut = direction == "down" ? fineVolumeDownHotkey() : fineVolumeUpHotkey()
    let currentLabel = direction == "down" ? "Volume Down" : "Volume Up"

    let recorderController = ShortcutRecorderWindowController(
      actionName: "Set \(currentLabel) Shortcut",
      currentShortcut: currentShortcut
    ) { [weak self] descriptor in
      defer { self?.recorderController = nil }

      guard let descriptor else {
        return
      }

      let otherShortcut = direction == "down" ? fineVolumeUpHotkey() : fineVolumeDownHotkey()
      if descriptor == otherShortcut {
        self?.presentAlert(
          title: "Shortcut Already In Use",
          message: "Pick a different shortcut so Volume Up and Volume Down stay separate."
        )
        return
      }

      if direction == "down" {
        setFineVolumeDownHotkey(descriptor)
        appendLog("settings shortcut_down=\(hotkeyDisplayString(descriptor))")
      } else {
        setFineVolumeUpHotkey(descriptor)
        appendLog("settings shortcut_up=\(hotkeyDisplayString(descriptor))")
      }

      self?.refresh()
    }

    self.recorderController = recorderController
    recorderController.showRecorder()
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

  @objc private func recordDownShortcut() {
    beginShortcutRecording(direction: "down")
  }

  @objc private func recordUpShortcut() {
    beginShortcutRecording(direction: "up")
  }

  @objc private func resetShortcuts() {
    resetFineVolumeHotkeysToDefault()
    appendLog("settings shortcuts_reset")
    refresh()
  }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
  private let controller = HotkeyController()
  private var statusBarController: StatusBarController?
  private var settingsObserver: NSObjectProtocol?

  func applicationDidFinishLaunching(_ notification: Notification) {
    registerSharedDefaults()
    controller.start()
    statusBarController = StatusBarController()

    settingsObserver = DistributedNotificationCenter.default().addObserver(
      forName: settingsNotificationName,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      self?.controller.reloadHotkeys()
      self?.statusBarController?.refresh()
    }
  }

  func applicationWillTerminate(_ notification: Notification) {
    if let settingsObserver {
      DistributedNotificationCenter.default().removeObserver(settingsObserver)
    }
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
