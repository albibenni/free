import Foundation
import NetworkExtension

// System-extension entry point: hand control to the NetworkExtension runtime,
// which instantiates the FilterDataProvider named in Info.plist's NEProviderClasses.
autoreleasepool {
    NEProvider.startSystemExtensionMode()
}

dispatchMain()
