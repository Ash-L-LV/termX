// swift-tools-version:5.9

import PackageDescription

let package = Package(
    name: "TermX",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
        .package(url: "https://github.com/migueldeicaza/SwiftTerm.git", from: "1.15.0"),
    ],
    targets: [
        .target(
            name: "CPTY",
            path: "Sources/CPTY",
            publicHeadersPath: "include"
        ),
        .target(
            name: "TermXCore",
            dependencies: [
                .product(name: "SwiftTerm", package: "SwiftTerm"),
            ],
            path: "Sources/TermXCore"
        ),
        .executableTarget(
            name: "TermX",
            dependencies: [
                "CPTY",
                "TermXCore",
                .product(name: "SwiftTerm", package: "SwiftTerm"),
            ],
            path: "Sources/TermX"
        ),
        .executableTarget(
            name: "TermXTests",
            dependencies: ["TermXCore"],
            path: "Sources/TermXTests"
        ),
    ]
)
