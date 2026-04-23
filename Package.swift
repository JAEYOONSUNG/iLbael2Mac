// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "iLabel2Mac",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "iLabel2Mac", targets: ["iLabelMac"])
    ],
    targets: [
        .executableTarget(
            name: "iLabelMac",
            path: "Sources/iLabelMac"
        ),
        .testTarget(
            name: "iLabelMacTests",
            dependencies: ["iLabelMac"],
            path: "Tests/iLabelMacTests"
        )
    ]
)
