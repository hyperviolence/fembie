// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "EstradiolPK",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "EstradiolPK", targets: ["EstradiolPK"])],
    targets: [.target(name: "EstradiolPK")]
)
