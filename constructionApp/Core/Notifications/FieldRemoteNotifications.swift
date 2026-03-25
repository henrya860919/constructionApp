//
//  FieldRemoteNotifications.swift
//  constructionApp
//

import UIKit
import UserNotifications

enum FieldRemoteNotificationsStorage {
    static let deviceTokenHexKey = "field.apnsDeviceTokenHex"
}

enum FieldRemoteNotifications {
    /// 使用者已允許通知時向 Apple 註冊遠端推播；成功後由 `FieldAppDelegate` 取得 device token。
    @MainActor
    static func registerWithAPNsIfAuthorized() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            UIApplication.shared.registerForRemoteNotifications()
        default:
            break
        }
    }
}
