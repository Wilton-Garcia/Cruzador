// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "Cruzador", platforms: [.macOS(.v14)],
    products: [.library(name: "CruzadorCore", targets: ["CruzadorCore"]), .executable(name: "Cruzador", targets: ["Cruzador"])],
    targets: [.target(name: "CruzadorCore"), .executableTarget(name: "Cruzador", dependencies: ["CruzadorCore"]), .testTarget(name: "CruzadorCoreTests", dependencies: ["CruzadorCore"]), .testTarget(name: "CruzadorPresentationTests", dependencies: ["Cruzador", "CruzadorCore"])]
)
