import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: "com.qingheng.bodylog/keep", binaryMessenger: controller.binaryMessenger)
      channel.setMethodCallHandler { call, result in
        switch call.method {
        case "isInstalled":
          result(UIApplication.shared.canOpenURL(URL(string: "keep://")!))
        case "openAuthorization":
          guard let args = call.arguments as? [String: Any],
                let value = args["url"] as? String,
                let url = URL(string: value),
                url.scheme == "keep", url.host == "webview",
                let parts = URLComponents(url: url, resolvingAgainstBaseURL: false),
                let decoded = String(parts.percentEncodedPath.dropFirst()).removingPercentEncoding,
                let auth = URLComponents(string: decoded),
                auth.scheme == "https", auth.host == "show.gotokeep.com",
                auth.path == "/login/auth", auth.user == nil, auth.password == nil,
                auth.port == nil, auth.fragment == nil,
                UIApplication.shared.canOpenURL(url) else {
            result(false)
            return
          }
          UIApplication.shared.open(url, options: [:]) { opened in result(opened) }
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
