import Foundation

#if canImport(os)
import os

private let appKitPerformanceLog = OSLog(subsystem: "Free", category: "AppKitPerformance")

@inline(__always)
func withAppKitSignpost<T>(_ name: StaticString, _ body: () -> T) -> T {
    let signpostId = OSSignpostID(log: appKitPerformanceLog)
    os_signpost(.begin, log: appKitPerformanceLog, name: name, signpostID: signpostId)
    defer {
        os_signpost(.end, log: appKitPerformanceLog, name: name, signpostID: signpostId)
    }
    return body()
}
#else
@inline(__always)
func withAppKitSignpost<T>(_: StaticString, _ body: () -> T) -> T {
    body()
}
#endif
