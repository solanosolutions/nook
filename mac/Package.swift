// swift-tools-version:5.9
import PackageDescription

// Nook para macOS: app nativo (AppKit + SwiftUI), sem dependências de terceiros.
// O .app é montado por scripts/bundle.sh a partir do executável gerado aqui.
let package = Package(
    name: "Nook",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "Nook",
            path: "Sources/Nook"
        )
    ]
)
