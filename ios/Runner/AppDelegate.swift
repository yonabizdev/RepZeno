import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let storageChannelName = "com.repzeno.repzeno/storage"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "StorageProtectionPlugin")
    let channel = FlutterMethodChannel(
      name: storageChannelName,
      binaryMessenger: registrar.messenger()
    )

    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "excludeFromBackup" else {
        result(FlutterMethodNotImplemented)
        return
      }

      guard let self else {
        result(nil)
        return
      }

      guard
        let arguments = call.arguments as? [String: Any],
        let path = arguments["path"] as? String
      else {
        result(
          FlutterError(
            code: "invalid_args",
            message: "A file path is required.",
            details: nil
          )
        )
        return
      }

      do {
        try self.excludeFromBackup(atPath: path)
        result(nil)
      } catch {
        result(
          FlutterError(
            code: "exclude_backup_failed",
            message: "Unable to update iCloud backup settings.",
            details: error.localizedDescription
          )
        )
      }
    }
  }

  private func excludeFromBackup(atPath path: String) throws {
    let url = URL(fileURLWithPath: path)
    var resourceValues = URLResourceValues()
    resourceValues.isExcludedFromBackup = true
    var mutableUrl = url
    try mutableUrl.setResourceValues(resourceValues)
  }
}
