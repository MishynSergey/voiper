

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
    let sipPassword: String
    let sipUsername: String
    
    enum CodingKeys: String, CodingKey {
        case sipPassword = "sip_password"
        case sipUsername = "sip_username"
    }
}
