// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Voiper",
    platforms: [
          .iOS(.v13)
      ],
    products: [
        .library(
            name: "Voiper",
            targets: ["Voiper"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/Alamofire/Alamofire.git", from: "5.6.1"),
        .package(url: "https://github.com/mxcl/PromiseKit.git", from: "6.22.1"),
        .package(url: "https://github.com/realm/realm-swift", from: "10.24.1"),
        .package(url: "https://github.com/MessageKit/MessageKit.git", from: "3.8.0"),
        .package(url: "https://github.com/twilio/twilio-voice-ios", from: "6.3.1"),
        .package(url: "https://github.com/kishikawakatsumi/KeychainAccess.git", from: "3.0.0"),
        .package(url: "https://github.com/facebook/facebook-ios-sdk", from: "17.0.0"),
        .package(url: "https://github.com/Amplitude/Amplitude-iOS.git", from: "8.15.0"),
        .package(url: "https://github.com/appmetrica/appmetrica-sdk-ios.git", from: "5.6.0"),
        .package(url: "https://github.com/firebase/firebase-ios-sdk", from: "10.15.0"),
    ],
    
    targets: [
        .target(
            name: "Voiper",
            dependencies: [
                .product(name: "AppMetricaCore", package: "appmetrica-sdk-ios"),
                .product(name: "FacebookCore", package: "facebook-ios-sdk"),
                .product(name: "Amplitude", package: "Amplitude-iOS"),
                .product(name: "TwilioVoice", package: "twilio-voice-ios"),
                .product(name: "Alamofire", package: "Alamofire"),
                .product(name: "PromiseKit", package: "PromiseKit"),
                .product(name: "RealmSwift", package: "realm-swift"),
                .product(name: "MessageKit", package: "MessageKit"),
                .product(name: "KeychainAccess", package: "KeychainAccess"),
                .product(name: "FirebaseRemoteConfig", package: "firebase-ios-sdk"),
                .product(name: "FirebaseRemoteConfigSwift", package: "firebase-ios-sdk"),
            ]
        )
    ]
)
