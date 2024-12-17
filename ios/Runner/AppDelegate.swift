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
        if #available(iOS 13.0, *) {
            BGTaskScheduler.shared.register(forTaskWithIdentifier: taskIdentifier, using: nil) { task in
                self.handleWidgetUpdateTask(task: task as! BGAppRefreshTask)
            }
            scheduleNextUpdate()
        }
        
        GeneratedPluginRegistrant.register(with: self)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
    @available(iOS 13.0, *)
    func handleWidgetUpdateTask(task: BGAppRefreshTask) {
        scheduleNextUpdate() // Schedule the next task

        let queue = OperationQueue()
        queue.addOperation {
            // Execute Flutter code to update the image
            self.executeFlutterUpdate()
        }

        task.expirationHandler = {
            queue.cancelAllOperations()
        }

        task.setTaskCompleted(success: !queue.operations.contains { $0.isCancelled })
    }
    
    @available(iOS 13.0, *)
    func scheduleNextUpdate() {
        let request = BGAppRefreshTaskRequest(identifier: taskIdentifier)
        request.earliestBeginDate = next2AMDate()
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            
        }
    }
    
    // Calculate the date for the next 2 AM
    func next2AMDate() -> Date {
        let calendar = Calendar.current
        let now = Date()
        
        // Get today's 2 AM
        var next2AM = calendar.date(
            bySettingHour: updateTime,
            minute: 0,
            second: 0,
            of: now
        )!
        
        // If 2 AM has already passed today, set it for tomorrow
        if next2AM <= now {
            next2AM = calendar.date(byAdding: .day, value: 1, to: next2AM)!
        }
        
        return next2AM
    }

    @available(iOS 13.0, *)
    func executeFlutterUpdate() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            // Call a Flutter method channel
            if let controller = self.window?.rootViewController as? FlutterViewController {
                let channel = FlutterMethodChannel(name: iOSMethodChannel, binaryMessenger: controller.binaryMessenger)
                channel.invokeMethod(iOSCallMethod, arguments: nil)
            }
        }
    }
}
