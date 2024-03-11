

import Foundation

public struct TwilioAccessTokenResponse: Decodable {
    let token: String
    let identity: String?
    let data: TelnyxCredentials?
}

extension TwilioAccessTokenResponse: CustomStringConvertible {
    public var description: String {
        return jsonFormatDescription((name: "token", value: token))
    }
}

struct TelnyxCredentials: Decodable {
    let password: String
    let username: String
    
    enum CodingKeys: String, CodingKey {
        case password = "password"
        case username = "user_name"
    }
}
