// swift-tools-version:5.7
// Lets the pure logic (models, time maths) be tested with `swift test` on any Mac or on CI. The app itself is built from project.yml.
import PackageDescription

let package = Package(
    name: "Shared",
    platforms: [.macOS(.v12), .iOS(.v16)],
    products: [.library(name: "Shared", targets: ["Shared"])],
    dependencies: [.package(url: "https://github.com/batoulapps/adhan-swift", from: "1.4.0")],
    targets: [
        .target(name: "Shared", dependencies: [.product(name: "Adhan", package: "adhan-swift")], path: "Sources/Shared"),
        .testTarget(name: "SharedTests", dependencies: ["Shared"], path: "Tests/SharedTests", resources: [.copy("Fixtures")]),
    ]
)
