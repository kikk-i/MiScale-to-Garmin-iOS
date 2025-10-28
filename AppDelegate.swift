import UIKit
import BackgroundTasks
import UserNotifications

class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.yourapp.syncWeight", using: nil) { task in
            self.handleSyncWeightTask(task: task as! BGProcessingTask)
        }

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }

        return true
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        scheduleWeightSync()
    }

    func scheduleWeightSync() {
        let request = BGProcessingTaskRequest(identifier: "com.yourapp.syncWeight")
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = false

        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Nie udało się zaplanować tasku w tle: \(error)")
        }
    }

    func handleSyncWeightTask(task: BGProcessingTask) {
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }

        let syncManager = WeightSyncManager()
        syncManager.startSync {
            task.setTaskCompleted(success: true)
        }
    }
}
