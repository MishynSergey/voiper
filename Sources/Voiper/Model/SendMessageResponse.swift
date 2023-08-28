

import Foundation

public struct SendMessageResponse: Decodable {
    public let activity: Activity?
    let cancel_id:Int?
    let will_be_sent_at:Date?
}

extension SendMessageResponse: CustomStringConvertible {
    public var description: String {
        return jsonFormatDescription((name: "activity", value: activity?.description ?? "Unknown, cancel_id \(cancel_id)"))
    }
}
