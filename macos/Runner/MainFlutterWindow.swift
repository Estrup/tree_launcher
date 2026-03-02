import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    // Make the title bar match the app's dark theme (#14171C)
    self.titleVisibility = .hidden
    self.titlebarAppearsTransparent = true
    self.backgroundColor = NSColor(calibratedRed: 0.078, green: 0.090, blue: 0.110, alpha: 1.0)
    self.isMovableByWindowBackground = true

    RegisterGeneratedPlugins(registry: flutterViewController)

    let channel = FlutterMethodChannel(
      name: "tree_launcher/directory_picker",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    channel.setMethodCallHandler { (call, result) in
      if call.method == "pickDirectory" {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.showsHiddenFiles = true
        panel.title = "Select a Git Repository"
        panel.begin { response in
          if response == .OK, let url = panel.url {
            result(url.path)
          } else {
            result(nil)
          }
        }
      } else {
        result(FlutterMethodNotImplemented)
      }
    }

    super.awakeFromNib()
  }
}
