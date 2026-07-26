// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Raze",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "Raze", targets: ["Raze"]),
        .library(name: "RazerCore", targets: ["RazerCore"])
    ],
    targets: [
        .target(name: "RazerCore"),
        .executableTarget(
            name: "Raze",
            dependencies: ["RazerCore"],
            linkerSettings: [.linkedFramework("IOKit")]
        ),
        .testTarget(name: "RazerCoreTests", dependencies: ["RazerCore"]),
        .testTarget(
            name: "RazeTests",
            dependencies: ["Raze"],
            linkerSettings: [.linkedFramework("IOKit")]
        )
    ]
)
