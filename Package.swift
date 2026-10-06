// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "LatexSnip",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "LatexSnip", targets: ["LatexSnip"])
    ],
    dependencies: [
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.1.0")
    ],
    targets: [
        .target(
            name: "LatexSnipCore",
            dependencies: ["Yams"]
        ),
        .executableTarget(
            name: "LatexSnip",
            dependencies: ["LatexSnipCore"]
        ),
        .testTarget(
            name: "LatexSnipCoreTests",
            dependencies: ["LatexSnipCore"]
        )
    ]
)
