#!/usr/bin/env swift
import Foundation
import CryptoKit
import Darwin

// The seed stays outside the repository. Reusing it is essential for future updates.
let directory = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent("Library/Application Support/CruxShotter/ReleaseSigning", isDirectory: true)
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
                                      attributes: [.posixPermissions: 0o700])
let file = directory.appendingPathComponent("ed25519.key")
let key: Curve25519.Signing.PrivateKey
if FileManager.default.fileExists(atPath: file.path) {
    guard let data = Data(base64Encoded: try String(contentsOf: file, encoding: .utf8)
        .trimmingCharacters(in: .whitespacesAndNewlines)) else { fatalError("Invalid signing seed") }
    key = try .init(rawRepresentation: data)
} else {
    key = .init()
    let seed = Data(key.rawRepresentation.base64EncodedString().utf8)
    guard FileManager.default.createFile(atPath: file.path, contents: seed, attributes: [.posixPermissions: 0o600])
    else { fatalError("Cannot save signing seed") }
}
guard chmod(file.path, 0o600) == 0 else { fatalError("Cannot protect signing seed") }
print(key.publicKey.rawRepresentation.base64EncodedString())
