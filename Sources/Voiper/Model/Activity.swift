

import Foundation
import RealmSwift
import MessageKit
import UIKit

extension Activity {
    
    public init(activity realmObject: ActivityRealm) {
        self.id = realmObject.activityId
        self.type = ActivityType(rawValue: realmObject.type)!
        self.from = realmObject.from
        self.to = realmObject.to
        self.numberId = realmObject.numberId
        self.participant = realmObject.participant
        self.status = Status(rawValue: realmObject.status)!
        self.direction = Direction(rawValue: realmObject.direction)!
        self.duration = realmObject.duration
        self.body = realmObject.body
        if let images = realmObject.images?.components(separatedBy: ","),
            images.count > 0 {
            self.images = images
        } else {
            self.images = nil
        }
        self.startedAt = realmObject.startedAt
        self.endedAt = realmObject.endedAt
        self.sentAt = realmObject.sentAt
        self.insertedAt = realmObject.insertedAt
        self.read = realmObject.read
    }
    
    public init(chatActivity realmObject: ChatActivityRealm) {
        self.id = realmObject.activityId
        self.type = ActivityType(rawValue: realmObject.type)!
        self.from = realmObject.from
        self.to = realmObject.to
        self.numberId = realmObject.numberId
        self.participant = realmObject.participant
        self.status = Status(rawValue: realmObject.status)!
        self.direction = Direction(rawValue: realmObject.direction)!
        self.duration = realmObject.duration
        self.body = realmObject.body
        if let images = realmObject.images?.components(separatedBy: ","),
            images.count > 0 {
            self.images = images
        } else {
            self.images = nil
        }
        self.startedAt = realmObject.startedAt
        self.endedAt = realmObject.endedAt
        self.sentAt = realmObject.sentAt
        self.insertedAt = realmObject.insertedAt
        self.read = realmObject.read
    }
}


public struct Activity: Decodable {
    
    
    
    public init(
        id: Int,
        type: ActivityType,
        from: String,
        to: String,
        numberId: Int,
        participant: String,
        status: Status,
        direction: Direction,
        read: Bool,
        duration: Int?,
        body: String?,
        images: [String]?,
        startedAt: Date?,
        endedAt: Date?,
        sentAt: Date?,
        insertedAt: Date?
    ) {
        self.id = id
        self.type = type
        self.from = from
        self.to = to
        self.numberId = numberId
        self.participant = participant
        self.status = status
        self.direction = direction
        self.read = read
        self.duration = duration
        self.body = body
        self.images = images
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.sentAt = sentAt
        self.insertedAt = insertedAt
    }
    
    
    
    public enum ActivityType: String, Decodable {
        case message, call
    }
    public enum Status: String, Decodable {
        case accepted, queued, sending, sent, receiving, received, delivered, undelivered, failed, ringing, inProgress, noAnswer, canceled, completed, busy, unknown
        
        public init(from decoder: Decoder) throws {
            let label = try decoder.singleValueContainer().decode(String.self)
            switch label {
            case "in-progress": self = .inProgress
            case "no-answer": self = .noAnswer
            default: self = Status(rawValue: label) ?? .unknown
            }
        }
        
        var coolStatuc:String? {
            switch self {
           
            case .accepted:
                return nil
            case .queued:
                return nil
            case .sending:
                return nil
            case .sent:
                return nil
            case .receiving:
                return nil
            case .received:
                return nil
            case .delivered:
                return nil
            case .undelivered:
                return nil
            case .failed:
                return "Failed"
            case .ringing:
                return nil
            case .inProgress:
                return "In Progress"
            case .noAnswer:
                return "No Answer"
            case .canceled:
                return "Canceled"
            case .completed:
                return nil
            case .busy:
                return "Busy"
            case .unknown:
                return nil
            }
        }
    }
    public enum Direction: String, Decodable {
        case outbound, inbound
    }
    
    public let id: Int
    public let type: ActivityType
    public let from: String
    public let to: String
    public let numberId: Int
    public let participant: String
    public let status: Status
    public let direction: Direction
    public let read: Bool
    public let duration: Int?
    public let body: String?
    public let images: [String]?
    public let startedAt: Date?
    public let endedAt: Date?
    public let sentAt: Date?
    public let insertedAt: Date?
    
    public enum CodingKeys: String, CodingKey {
        case id, type, from, to, participant, status, direction, duration, body, read, images
        case numberId = "account_number_id"
        case startedAt = "started_at"
        case endedAt = "ended_at"
        case sentAt = "sent_at"
        case insertedAt = "inserted_at"
    }
}

extension Activity {
    public enum BodyType {
        case text, call, image
    }
    
    public var senderId: String {
        return isMine ? "me" : "user"
    }
    
    public var isMine: Bool {
        return direction == .outbound
    }
    
    public var isRead: Bool {
        return read || direction == .outbound
    }
    
    public var previewMessage: String {
        switch (bodyType, direction) {
        case (.call, .outbound):
            var s = "Outgoing Call"
            if let k = self.status.coolStatuc {
                s.append(contentsOf: ", \(k)")
            }
            return s
        case (.call, .inbound):
            var s = "Incoming Call"
            if let k = self.status.coolStatuc {
                s.append(contentsOf: ", \(k)")
            }
            return s
        case (.text, _):
            return body ?? ""
        case (.image, _):
            return "Sent image".localized
        }
    }
    
    public var bodyType: BodyType {
        switch type {
        case .call:
            return .call
        case .message:
            return (images?.count ?? 0) != 0 && (body?.count ?? 0) == 0 ? .image : .text
        }
    }
    
    public var formattedDuration: String {
        guard let duration = duration else {
            return ""
        }
        
        return DateComponentsFormatter.durationFormatter.string(from: TimeInterval(duration)) ?? ""
    }
}

extension Activity: CustomStringConvertible {
    public var description: String {
        return jsonFormatDescription((name: "id", value: String(id)),
                                     (name: "type", value: type.rawValue),
                                     (name: "from", value: from),
                                     (name: "to", value: to),
                                     (name: "numberId", value: String(numberId)),
                                     (name: "participant", value: participant),
                                     (name: "status", value: status.rawValue),
                                     (name: "direction", value: direction.rawValue),
                                     (name: "read", value: String(read)),
                                     (name: "duration", value: String(duration ?? 0)),
                                     (name: "body", value: body ?? ""),
                                     (name: "images", value: images?.description ?? ""),
                                     (name: "startedAt", value: startedAt?.description ?? ""),
                                     (name: "endedAt", value: endedAt?.description ?? ""),
                                     (name: "sentAt", value: sentAt?.description ?? ""),
                                     (name: "insertedAt", value: insertedAt?.description ?? ""))
    }
}

extension Activity: Equatable {
    public static func == (lhs: Activity, rhs: Activity) -> Bool {
        let equal = (lhs.id == rhs.id) &&
            (lhs.read == rhs.read) &&
            (lhs.status == rhs.status) &&
            ((lhs.images?.count ?? 0) == (rhs.images?.count ?? 0))
        return equal
    }
}

extension Activity: MessageType {
    public var sender: SenderType {
        return Sender(id: isMine ? "me" : "user", displayName: "")
    }
    
    public var messageId: String {
        return String(id)
    }
    
    public var sentDate: Date {
        switch type {
        case .call:
            return startedAt ?? Date()
        case .message:
            return insertedAt ?? (sentAt ?? Date())
        }
    }
    
    public var kind: MessageKind {
        switch type {
        case .call:
            return .custom(nil)
        case .message:
            
            if let imageURLString = self.images?.first, let imageURl = URL(string: imageURLString)  {
                return .photo(PhotoMediaItem(url: imageURl))
            }
            
            var text = ""
            if let body = body {
                text.append(body)
            }
            if let images = images,
                images.count > 0 {
                text.append("\n")
                images.forEach { text.append("\($0)\n") }
            }
            text = text.trimmingCharacters(in: .whitespacesAndNewlines)
            
            return .text(text)
        }
    }
}

public class PhotoMediaItem: MediaItem {
    
    public let url:URL?
    public let placeholderImage:UIImage
    public let size:CGSize
    public let image: UIImage?
    
    public init(url:URL) {
        self.url = url
        self.placeholderImage = UIImage(named: "MessagePlaceholder", in: Bundle.module, compatibleWith: nil)!
        self.size = self.placeholderImage.size
        self.image = nil
    }
    
}
