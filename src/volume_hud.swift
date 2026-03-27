import AppKit

let volume = max(0, min(100, Int(CommandLine.arguments.dropFirst().first ?? "0") ?? 0))

final class AppDelegate: NSObject, NSApplicationDelegate {
  private var panel: NSPanel?

  func applicationDidFinishLaunching(_ notification: Notification) {
    let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
    let panelSize = NSSize(width: 220, height: 88)
    let origin = NSPoint(
      x: screenFrame.midX - (panelSize.width / 2),
      y: screenFrame.minY + 72
    )

    let panel = NSPanel(
      contentRect: NSRect(origin: origin, size: panelSize),
      styleMask: [.nonactivatingPanel, .fullSizeContentView],
      backing: .buffered,
      defer: false
    )
    panel.isFloatingPanel = true
    panel.level = .statusBar
    panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
    panel.backgroundColor = .clear
    panel.isOpaque = false
    panel.hasShadow = true
    panel.hidesOnDeactivate = false
    panel.ignoresMouseEvents = true
    panel.titleVisibility = .hidden
    panel.titlebarAppearsTransparent = true
    panel.isMovable = false
    panel.isReleasedWhenClosed = false

    let contentView = NSView(frame: NSRect(origin: .zero, size: panelSize))
    contentView.wantsLayer = true
    contentView.layer?.backgroundColor = NSColor(calibratedWhite: 0.08, alpha: 0.86).cgColor
    contentView.layer?.cornerRadius = 18
    contentView.layer?.masksToBounds = true
    panel.contentView = contentView

    let title = NSTextField(labelWithString: "Volume \(volume)%")
    title.font = .systemFont(ofSize: 26, weight: .semibold)
    title.textColor = .white
    title.alignment = .center
    title.frame = NSRect(x: 20, y: 44, width: 180, height: 30)
    contentView.addSubview(title)

    let track = NSView(frame: NSRect(x: 22, y: 22, width: 176, height: 12))
    track.wantsLayer = true
    track.layer?.backgroundColor = NSColor(calibratedWhite: 1.0, alpha: 0.16).cgColor
    track.layer?.cornerRadius = 6
    contentView.addSubview(track)

    let fillWidth = max(12.0, floor(176.0 * CGFloat(volume) / 100.0))
    let fill = NSView(frame: NSRect(x: 0, y: 0, width: fillWidth, height: 12))
    fill.wantsLayer = true
    fill.layer?.backgroundColor = NSColor.white.cgColor
    fill.layer?.cornerRadius = 6
    track.addSubview(fill)

    self.panel = panel
    panel.orderFrontRegardless()

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) {
      panel.close()
      NSApp.terminate(nil)
    }
  }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
