import Foundation

enum Capture {
    /// Interactive region capture via `/usr/sbin/screencapture -i`.
    /// Returns PNG URL, or nil if cancelled.
    static func selection() -> URL? {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("latex-snip-\(UUID().uuidString).png")
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        proc.arguments = ["-i", "-x", url.path]
        do {
            try proc.run()
            proc.waitUntilExit()
        } catch {
            return nil
        }
        guard proc.terminationStatus == 0,
              FileManager.default.fileExists(atPath: url.path),
              let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attrs[.size] as? NSNumber,
              size.intValue > 0
        else {
            try? FileManager.default.removeItem(at: url)
            return nil
        }
        return url
    }
}
