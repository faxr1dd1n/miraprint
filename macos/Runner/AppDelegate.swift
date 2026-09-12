import Cocoa
import FlutterMacOS
import ServiceManagement

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationDidFinishLaunching(_ notification: Notification) {
      super.applicationDidFinishLaunching(notification)

      if #available(macOS 13.0, *) {
        try? SMAppService.mainApp.register()
      }
  }
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return false
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
  override func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag:
  Bool) -> Bool {
      if !flag {
        for window in sender.windows {
          window.makeKeyAndOrderFront(self)
        }
      }
      return true
    }
  }