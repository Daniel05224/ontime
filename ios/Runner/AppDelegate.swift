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

    // Reset badge immediately on every launch — before FCM or anything else runs
    application.applicationIconBadgeNumber = 0

    // Become the UNUserNotificationCenter delegate so we can intercept
    // foreground notifications and prevent badge from ever being set
    UNUserNotificationCenter.current().delegate = self

    application.registerForRemoteNotifications()
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // Called when a notification arrives while the app is in the FOREGROUND.
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    // Remote FCM pushes are suppressed in the foreground — Flutter's onMessage
    // handler re-shows them as a local notification with our own rules (skip the
    // chat you already have open, skip blocked senders). This avoids a duplicate
    // banner (system FCM push + app-generated local notification).
    let isRemotePush = notification.request.trigger is UNPushNotificationTrigger
    if isRemotePush {
      completionHandler([])
    } else if #available(iOS 14.0, *) {
      completionHandler([.banner, .sound])
    } else {
      completionHandler([.alert, .sound])
    }
    // Immediately wipe any badge the notification payload may have included
    clearBadge(UIApplication.shared)
  }

  override func applicationDidBecomeActive(_ application: UIApplication) {
    super.applicationDidBecomeActive(application)
    clearBadge(application)
    // Second clear covers races with Flutter/FCM initialization
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
      self.clearBadge(application)
    }
    // Third clear at 2s to catch any delayed FCM registration notification
    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
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
