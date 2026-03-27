import AppKit
import Darwin
import Foundation
import QuartzCore

func clamp(_ value: Int) -> Int {
  max(0, min(100, value))
}

let hudNotificationName = Notification.Name("com.murat-taskaynatan.logi-fine-volume.hud-update")
let hudPIDFile = URL(fileURLWithPath: NSTemporaryDirectory())
  .appendingPathComponent("com.murat-taskaynatan.logi-fine-volume.hud.pid")

final class AppDelegate: NSObject, NSApplicationDelegate {
  private let initialVolume: Int?
  private var panel: NSPanel?
  private var titleField: NSTextField?
  private var fillView: NSView?
  private var hideWorkItem: DispatchWorkItem?
  private var notificationObserver: NSObjectProtocol?

  init(initialVolume: Int?) {
    self.initialVolume = initialVolume.map(clamp)
  }

  func applicationDidFinishLaunching(_ notification: Notification) {
    writePIDFile()

    notificationObserver = DistributedNotificationCenter.default().addObserver(
      forName: hudNotificationName,
      object: nil,
      queue: .main
    ) { [weak self] notification in
      guard let self else {
        return
      }

      guard
        let volumeValue = notification.userInfo?["volume"] as? NSNumber ?? {
          if let intValue = notification.userInfo?["volume"] as? Int {
            return NSNumber(value: intValue)
          }
          return nil
        }()
      else {
        return
      }

      self.present(volume: clamp(volumeValue.intValue))
    }

    if let initialVolume {
      present(volume: initialVolume)
    }
  }

  func applicationWillTerminate(_ notification: Notification) {
    if let notificationObserver {
      DistributedNotificationCenter.default().removeObserver(notificationObserver)
    }
    removePIDFile()
  }

  private func writePIDFile() {
    try? "\(getpid())".write(to: hudPIDFile, atomically: true, encoding: .utf8)
  }

  private func removePIDFile() {
    guard
      let pidText = try? String(contentsOf: hudPIDFile, encoding: .utf8)
        .trimmingCharacters(in: .whitespacesAndNewlines),
      pidText == "\(getpid())"
    else {
      return
    }

    try? FileManager.default.removeItem(at: hudPIDFile)
  }

  private func screenFrame() -> NSRect {
    let mouseLocation = NSEvent.mouseLocation
    let targetScreen = NSScreen.screens.first {
      NSMouseInRect(mouseLocation, $0.frame, false)
    }
    return targetScreen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
  }

  private func panelOrigin(for panelSize: NSSize) -> NSPoint {
    let screenFrame = screenFrame()
    return NSPoint(
      x: screenFrame.midX - (panelSize.width / 2),
      y: screenFrame.minY + 72
    )
  }

  private func ensurePanel() {
    if panel != nil {
      return
    }

    let panelSize = NSSize(width: 220, height: 88)
    let panel = NSPanel(
      contentRect: NSRect(origin: panelOrigin(for: panelSize), size: panelSize),
      styleMask: [.borderless, .nonactivatingPanel],
      backing: .buffered,
      defer: false
    )
    panel.isFloatingPanel = true
    panel.level = .statusBar
    panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
    panel.backgroundColor = .clear
    panel.isOpaque = false
    panel.hasShadow = true
    panel.hidesOnDeactivate = false
    panel.ignoresMouseEvents = true
    panel.isMovable = false
    panel.isReleasedWhenClosed = false
    panel.alphaValue = 1

    let contentView = NSView(frame: NSRect(origin: .zero, size: panelSize))
    contentView.wantsLayer = true
    contentView.layer?.backgroundColor = NSColor(calibratedWhite: 0.08, alpha: 0.86).cgColor
    contentView.layer?.cornerRadius = 18
    contentView.layer?.masksToBounds = true
    panel.contentView = contentView

    let titleField = NSTextField(labelWithString: "")
    titleField.font = .systemFont(ofSize: 26, weight: .semibold)
    titleField.textColor = .white
    titleField.alignment = .center
    titleField.frame = NSRect(x: 20, y: 44, width: 180, height: 30)
    contentView.addSubview(titleField)

    let track = NSView(frame: NSRect(x: 22, y: 22, width: 176, height: 12))
    track.wantsLayer = true
    track.layer?.backgroundColor = NSColor(calibratedWhite: 1.0, alpha: 0.16).cgColor
    track.layer?.cornerRadius = 6
    contentView.addSubview(track)

    let fillView = NSView(frame: NSRect(x: 0, y: 0, width: 12, height: 12))
    fillView.wantsLayer = true
    fillView.layer?.backgroundColor = NSColor.white.cgColor
    fillView.layer?.cornerRadius = 6
    track.addSubview(fillView)

    self.panel = panel
    self.titleField = titleField
    self.fillView = fillView
  }

  private func updatePanel(volume: Int) {
    ensurePanel()

    titleField?.stringValue = "Volume \(volume)%"

    CATransaction.begin()
    CATransaction.setDisableActions(true)
    let fillWidth = max(12.0, floor(176.0 * CGFloat(volume) / 100.0))
    fillView?.frame.size.width = fillWidth
    CATransaction.commit()
  }

  private func present(volume: Int) {
    updatePanel(volume: volume)

    guard let panel else {
      return
    }

    let panelSize = panel.frame.size
    panel.setFrameOrigin(panelOrigin(for: panelSize))

    if !panel.isVisible {
      panel.alphaValue = 1
      panel.orderFrontRegardless()
    }

    hideWorkItem?.cancel()
    let hideWorkItem = DispatchWorkItem { [weak panel] in
      panel?.orderOut(nil)
    }
    self.hideWorkItem = hideWorkItem
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.72, execute: hideWorkItem)
  }
}

let arguments = Array(CommandLine.arguments.dropFirst())
let initialVolume: Int? = {
  if arguments.first == "--service" {
    return arguments.dropFirst().first.flatMap(Int.init).map(clamp)
  }
  return arguments.first.flatMap(Int.init).map(clamp)
}()

let app = NSApplication.shared
let delegate = AppDelegate(initialVolume: initialVolume)
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
