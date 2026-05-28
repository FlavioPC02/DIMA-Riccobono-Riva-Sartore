import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
<<<<<<< HEAD

=======
    SwiftFlutterBackgroundServicePlugin.taskIdentifier = "com.example.application.background"
    UIApplication.shared.setMinimumBackgroundFetchInterval(UIApplication.backgroundFetchIntervalMinimum)
    self.setupLocationManager()
>>>>>>> feature/navigator
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
