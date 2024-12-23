import Flutter
import UIKit

import workmanager

let iOSDailyTask = "com.example.widgetMemories.updateDaily"

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    WorkmanagerPlugin.setPluginRegistrantCallback { registry in
      // Registry in this case is the FlutterEngine that is created in Workmanager's
      // performFetchWithCompletionHandler or BGAppRefreshTask.
      // This will make other plugins available during a background operation.
      GeneratedPluginRegistrant.register(with: registry)
    }

    // Every hour to be sure
    WorkmanagerPlugin.registerPeriodicTask(withIdentifier: iOSDailyTask, frequency: NSNumber(value: 1 * 60 * 60))

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
