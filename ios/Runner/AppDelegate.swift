import Flutter
import UIKit
import FirebaseCore
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    FirebaseApp.configure()
    application.registerForRemoteNotifications()
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func applicationDidBecomeActive(_ application: UIApplication) {
    super.applicationDidBecomeActive(application)
    clearBadge(application)
    // Delayed clear covers any race with Flutter plugin initialization
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
      self.clearBadge(application)
    }
  }

  private func clearBadge(_ application: UIApplication) {
    application.applicationIconBadgeNumber = 0
    UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    if #available(iOS 16.0, *) {
      UNUserNotificationCenter.current().setBadgeCount(0) { _ in }
    }
  }
}
