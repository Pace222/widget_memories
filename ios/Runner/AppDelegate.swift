import Flutter
import UIKit

import BackgroundTasks

private var updateTime = 2 // 2 AM

private var taskIdentifier = "com.example.widgetMemories.update"
private var iOSMethodChannel = "com.example/widget"
private var iOSCallMethod = "updateWidget"

@main
@objc class AppDelegate: FlutterAppDelegate {
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        GeneratedPluginRegistrant.register(with: self)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
}
