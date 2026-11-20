// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FORGE",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "ForgeCore", targets: ["ForgeCore"]),
        .executable(name: "ForgeDesktop", targets: ["ForgeDesktop"]),
        .executable(name: "ForgeIntegrationCheck", targets: ["ForgeIntegrationCheck"])
    ],
    targets: [
        .target(name: "ForgeCore"),
        .executableTarget(name: "ForgeIntegrationCheck", dependencies: ["ForgeCore"]),
        .executableTarget(name: "ForgeDesktop", dependencies: ["ForgeCore"], path: "App", exclude: ["ForgeMac.entitlements", "PrivacyInfo.xcprivacy", "Assets.xcassets"]),
        .testTarget(name: "ForgeCoreTests", dependencies: ["ForgeCore"])
    ]
)
