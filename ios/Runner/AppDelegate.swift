import UIKit
import Flutter

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    if let registrar = registrar(forPlugin: "AppSettings") {
      let channel = FlutterMethodChannel(
        name: "pay_cal/app_settings", binaryMessenger: registrar.messenger())
      channel.setMethodCallHandler { call, result in
        guard call.method == "open" else {
          result(FlutterMethodNotImplemented)
          return
        }
        guard let url = URL(string: UIApplication.openSettingsURLString) else {
          result(false)
          return
        }
        UIApplication.shared.open(url, options: [:]) { opened in
          result(opened)
        }
      }
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
