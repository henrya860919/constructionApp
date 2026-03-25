//
//  FieldAppDelegate.swift
//  constructionApp
//
//  前景顯示通知橫幅（與一般 App 一致），並向 APNs 註冊以取得 device token（供後端發遠端推播）。
//

import UIKit
import UserNotifications

extension Notification.Name {
    /// Device token 更新時廣播；`userInfo["hex"]` 為十六進位字串（日後上傳後端用）。
    static let fieldAPNsDeviceTokenDidUpdate = Notification.Name("FieldAPNs.deviceTokenDidUpdate")
}

final class FieldAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    // MARK: UNUserNotificationCenterDelegate（App 開著時也要出現橫幅／通知中心）

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .sound, .badge])
    }

    // MARK: Remote notifications（APNs）

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let hex = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        UserDefaults.standard.set(hex, forKey: FieldRemoteNotificationsStorage.deviceTokenHexKey)
        NotificationCenter.default.post(
            name: .fieldAPNsDeviceTokenDidUpdate,
            object: nil,
            userInfo: ["hex": hex]
        )
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        // 模擬器通常無法取得 APNs token。個人免費開發者帳號無法使用遠端推播；付費帳號請在 entitlements 加回 aps-environment 並啟用 Push capability。
        _ = error
    }
}
