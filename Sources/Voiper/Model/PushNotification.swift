
import Foundation
import PromiseKit
import UserNotifications
import UIKit

public class PushNotification {
    static func checkAccess() -> Guarantee<Bool> {
        return Guarantee { seal in
            UNUserNotificationCenter.current().getNotificationSettings(completionHandler: { settings in
                switch settings.authorizationStatus {
                case .authorized:
                    _ = registerForRemote()
                    seal(true)
                case .denied, .provisional:
                    seal(false)
                case .notDetermined:
                    _ = self.registerForRemote()
                        .done { success in
                            seal(success)
                    }
                case .ephemeral:
                    //TODO SASHA
                    assertionFailure("dont implementd")
                @unknown default:
                    assertionFailure("unknown status")
                }
            })
        }
    }

    static func registerForRemote() -> Guarantee<Bool> {
        return getAccess()
            .map { success in
                if success {
                    UIApplication.shared.registerForRemoteNotifications()
                }
                return success
            }
    }

    static private func getAccess() -> Guarantee<Bool> {
        return Guarantee { seal in
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound, .carPlay], completionHandler: { success, error in
                seal(success)
            })
        }
    }
}
