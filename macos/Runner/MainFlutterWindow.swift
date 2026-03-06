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

    let soundChannel = FlutterMethodChannel(
      name: "tree_launcher/system_sound",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    soundChannel.setMethodCallHandler { (call, result) in
      if call.method == "playSystemSound" {
        guard
          let arguments = call.arguments as? [String: Any],
          let soundName = arguments["soundName"] as? String
        else {
          result(
            FlutterError(
              code: "invalid_arguments",
              message: "Expected a soundName argument.",
              details: nil
            )
          )
          return
        }

        let namedSound = NSSound.Name(soundName)
        guard let sound = NSSound(named: namedSound) else {
          result(
            FlutterError(
              code: "sound_not_found",
              message: "macOS system sound '\(soundName)' is not available.",
              details: nil
            )
          )
          return
        }

        sound.stop()
        if sound.play() {
          result(nil)
        } else {
          result(
            FlutterError(
              code: "sound_playback_failed",
              message: "Failed to play macOS system sound '\(soundName)'.",
              details: nil
            )
          )
        }
      } else {
        result(FlutterMethodNotImplemented)
      }
    }

    super.awakeFromNib()
  }
}
