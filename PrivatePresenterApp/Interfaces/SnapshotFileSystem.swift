import Foundation

protocol SnapshotFileSystem: Sendable {
    func createDirectory(at url: URL) throws
    func fileExists(at url: URL) -> Bool
    func readFile(at url: URL) throws -> Data

    /// Performs the complete temp-file write and atomic destination update
    /// synchronously. No file handle escapes this call across an actor await.
    func atomicCommit(_ data: Data, to destinationURL: URL, temporaryURL: URL) throws

    func moveItem(at sourceURL: URL, to destinationURL: URL) throws
}

struct LocalSnapshotFileSystem: SnapshotFileSystem {
    func createDirectory(at url: URL) throws {
        try FileManager.default.createDirectory(
            at: url,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        try? FileManager.default.setAttributes(
            [.posixPermissions: 0o700],
            ofItemAtPath: url.path
        )
    }

    func fileExists(at url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
    }

    func readFile(at url: URL) throws -> Data {
        try Data(contentsOf: url, options: [.mappedIfSafe])
    }

    func atomicCommit(_ data: Data, to destinationURL: URL, temporaryURL: URL) throws {
        let fileManager = FileManager.default
        var temporaryWasCreated = false

        do {
            try Data().write(to: temporaryURL, options: [.withoutOverwriting])
            temporaryWasCreated = true
            try fileManager.setAttributes(
                [.posixPermissions: 0o600],
                ofItemAtPath: temporaryURL.path
            )

            let handle = try FileHandle(forWritingTo: temporaryURL)
            do {
                try handle.write(contentsOf: data)
                try handle.synchronize()
                try handle.close()
            } catch {
                try? handle.close()
                throw error
            }

            if fileManager.fileExists(atPath: destinationURL.path) {
                _ = try fileManager.replaceItemAt(
                    destinationURL,
                    withItemAt: temporaryURL,
                    backupItemName: nil,
                    options: []
                )
            } else {
                try fileManager.moveItem(at: temporaryURL, to: destinationURL)
            }
            temporaryWasCreated = false

            // Directory synchronization is best-effort because FileHandle does
            // not support opening directories on every Foundation platform.
            if let directoryHandle = try? FileHandle(
                forReadingFrom: destinationURL.deletingLastPathComponent()
            ) {
                try? directoryHandle.synchronize()
                try? directoryHandle.close()
            }
        } catch {
            if temporaryWasCreated {
                try? fileManager.removeItem(at: temporaryURL)
            }
            throw error
        }
    }

    func moveItem(at sourceURL: URL, to destinationURL: URL) throws {
        try FileManager.default.moveItem(at: sourceURL, to: destinationURL)
    }
}
