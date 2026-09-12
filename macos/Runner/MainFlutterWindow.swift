import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController

    // pos_app'dagi kabi: oyna ekranga birinchi marta chiqarilishidan oldin,
    // shu yerda (native Swift'da) to'g'ridan-to'g'ri to'liq ekran o'lchamiga
    // (taskbar/dock'siz ish maydoni) o'rnatiladi — shu sababli "avval kichik,
    // keyin katta" degan ko'rinish umuman bo'lmaydi.
    if let screen = NSScreen.main {
      self.setFrame(screen.visibleFrame, display: true)
    }

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
