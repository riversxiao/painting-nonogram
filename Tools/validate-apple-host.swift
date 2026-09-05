#!/usr/bin/env swift

import Foundation

struct EntitlementConfigurationDocument: Decodable {
    let schema: String
    let productToMuseumIDs: [String: [String]]
}

struct MuseumIdentityDocument: Decodable {
    let schema: String
    let id: String
}

enum HostValidationError: Error, CustomStringConvertible {
    case invalidArguments
    case missingDirectory(String)
    case missingFile(String)
    case missingSwiftFileList(String)
    case sourceMembership(missing: [String], unexpected: [String])
    case invalidInfoPlist(String)
    case invalidEntitlements(String)

    var description: String {
        switch self {
        case .invalidArguments:
            "usage: swift Tools/validate-apple-host.swift <app-bundle> <derived-data>"
        case .missingDirectory(let path):
            "missing directory: \(path)"
        case .missingFile(let path):
            "missing file: \(path)"
        case .missingSwiftFileList(let path):
            "no KanakaApp.SwiftFileList found below \(path)"
        case .sourceMembership(let missing, let unexpected):
            "Xcode source membership mismatch; missing=\(missing), unexpected=\(unexpected)"
        case .invalidInfoPlist(let reason):
            "invalid KanakaApp Info.plist contract: \(reason)"
        case .invalidEntitlements(let reason):
            "invalid entitlement configuration: \(reason)"
        }
    }
}

func requiredDirectory(_ url: URL, fileManager: FileManager) throws {
    var isDirectory: ObjCBool = false
    guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory),
          isDirectory.boolValue else {
        throw HostValidationError.missingDirectory(url.path)
    }
}

func requiredFile(_ url: URL, fileManager: FileManager) throws {
    var isDirectory: ObjCBool = false
    guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory),
          !isDirectory.boolValue else {
        throw HostValidationError.missingFile(url.path)
    }
}

func regularFiles(
    below root: URL,
    named fileName: String? = nil,
    withExtension fileExtension: String? = nil,
    fileManager: FileManager
) throws -> [URL] {
    guard let enumerator = fileManager.enumerator(
        at: root,
        includingPropertiesForKeys: [.isRegularFileKey],
        options: [.skipsHiddenFiles]
    ) else {
        throw HostValidationError.missingDirectory(root.path)
    }

    var files: [URL] = []
    for case let url as URL in enumerator {
        let values = try url.resourceValues(forKeys: [.isRegularFileKey])
        guard values.isRegularFile == true else { continue }
        if let fileName, url.lastPathComponent != fileName { continue }
        if let fileExtension, url.pathExtension != fileExtension { continue }
        files.append(url.standardizedFileURL)
    }
    return files.sorted { $0.path < $1.path }
}

func relativePath(_ url: URL, below root: URL) -> String {
    String(url.standardizedFileURL.path.dropFirst(root.standardizedFileURL.path.count + 1))
}

func validateSourceMembership(
    repositoryRoot: URL,
    derivedData: URL,
    fileManager: FileManager
) throws {
    let sourceRoot = repositoryRoot
        .appendingPathComponent("Apps/KanakaApp/Sources/KanakaApp", isDirectory: true)
    try requiredDirectory(sourceRoot, fileManager: fileManager)
    try requiredDirectory(derivedData, fileManager: fileManager)

    let expected = Set(
        try regularFiles(
            below: sourceRoot,
            withExtension: "swift",
            fileManager: fileManager
        ).map(\.path)
    )
    let currentConfigurationMarker =
        "/KanakaApp.build/Debug-iphonesimulator/KanakaApp.build/"
    let fileLists = try regularFiles(
        below: derivedData,
        named: "KanakaApp.SwiftFileList",
        fileManager: fileManager
    ).filter { $0.path.contains(currentConfigurationMarker) }
    guard !fileLists.isEmpty else {
        throw HostValidationError.missingSwiftFileList(derivedData.path)
    }

    var compiled = Set<String>()
    for fileList in fileLists {
        let contents = try String(contentsOf: fileList, encoding: .utf8)
        for rawLine in contents.split(whereSeparator: \.isNewline) {
            let path = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            guard !path.isEmpty else { continue }
            let sourceURL = URL(fileURLWithPath: path).standardizedFileURL
            if sourceURL.path.hasPrefix(sourceRoot.path + "/") {
                compiled.insert(sourceURL.path)
            }
        }
    }

    let missing = expected.subtracting(compiled).sorted()
        .map { relativePath(URL(fileURLWithPath: $0), below: repositoryRoot) }
    let unexpected = compiled.subtracting(expected).sorted()
        .map { relativePath(URL(fileURLWithPath: $0), below: repositoryRoot) }
    guard missing.isEmpty, unexpected.isEmpty else {
        throw HostValidationError.sourceMembership(missing: missing, unexpected: unexpected)
    }
}

func validateInfoPlist(appBundle: URL, fileManager: FileManager) throws {
    let infoURL = appBundle.appendingPathComponent("Info.plist")
    try requiredFile(infoURL, fileManager: fileManager)
    let data = try Data(contentsOf: infoURL)
    let propertyList = try PropertyListSerialization.propertyList(from: data, format: nil)
    guard let info = propertyList as? [String: Any] else {
        throw HostValidationError.invalidInfoPlist("root is not a dictionary")
    }

    let expectedStrings = [
        "CFBundleIdentifier": "com.riversxiao.kanaka",
        "CFBundleExecutable": "KanakaApp",
        "MinimumOSVersion": "17.0",
    ]
    for (key, expected) in expectedStrings {
        guard let actual = info[key] as? String, actual == expected else {
            throw HostValidationError.invalidInfoPlist(
                "\(key) must be \(expected), found \(String(describing: info[key]))"
            )
        }
    }

    guard let rawFamilies = info["UIDeviceFamily"] as? [Any] else {
        throw HostValidationError.invalidInfoPlist("UIDeviceFamily must be an array")
    }
    let deviceFamilies = Set(rawFamilies.compactMap { ($0 as? NSNumber)?.intValue })
    guard deviceFamilies == Set([1, 2]), rawFamilies.count == 2 else {
        throw HostValidationError.invalidInfoPlist(
            "UIDeviceFamily must contain exactly iPhone (1) and iPad (2)"
        )
    }
}

func validateEntitlements(appBundle: URL, fileManager: FileManager) throws {
    let entitlementURL = appBundle.appendingPathComponent("entitlements.json")
    try requiredFile(entitlementURL, fileManager: fileManager)
    let configuration = try JSONDecoder().decode(
        EntitlementConfigurationDocument.self,
        from: Data(contentsOf: entitlementURL)
    )
    guard configuration.schema == "museum-entitlements-v1" else {
        throw HostValidationError.invalidEntitlements(
            "schema must be museum-entitlements-v1, found \(configuration.schema)"
        )
    }

    let contentRoot = appBundle.appendingPathComponent("Content", isDirectory: true)
    try requiredDirectory(contentRoot, fileManager: fileManager)
    let museumURLs = try regularFiles(
        below: contentRoot,
        named: "museum.json",
        fileManager: fileManager
    )
    var museumIDs = Set<String>()
    for museumURL in museumURLs {
        let museum = try JSONDecoder().decode(
            MuseumIdentityDocument.self,
            from: Data(contentsOf: museumURL)
        )
        guard museum.schema == "museum-v1", !museum.id.isEmpty else {
            throw HostValidationError.invalidEntitlements(
                "invalid museum identity at \(museumURL.path)"
            )
        }
        museumIDs.insert(museum.id)
    }
    guard !museumIDs.isEmpty else {
        throw HostValidationError.invalidEntitlements("Content contains no museums")
    }

    for (productID, grantedMuseumIDs) in configuration.productToMuseumIDs {
        guard !productID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw HostValidationError.invalidEntitlements("product ID must not be empty")
        }
        guard !grantedMuseumIDs.isEmpty,
              Set(grantedMuseumIDs).count == grantedMuseumIDs.count else {
            throw HostValidationError.invalidEntitlements(
                "\(productID) must grant one or more unique museum IDs"
            )
        }
        let unknownMuseumIDs = Set(grantedMuseumIDs).subtracting(museumIDs).sorted()
        guard unknownMuseumIDs.isEmpty else {
            throw HostValidationError.invalidEntitlements(
                "\(productID) references unknown museums \(unknownMuseumIDs)"
            )
        }
    }
}

do {
    guard CommandLine.arguments.count == 3 else {
        throw HostValidationError.invalidArguments
    }
    let fileManager = FileManager.default
    let repositoryRoot = URL(
        fileURLWithPath: fileManager.currentDirectoryPath,
        isDirectory: true
    ).standardizedFileURL
    let appBundle = URL(
        fileURLWithPath: CommandLine.arguments[1],
        relativeTo: repositoryRoot
    ).standardizedFileURL
    let derivedData = URL(
        fileURLWithPath: CommandLine.arguments[2],
        relativeTo: repositoryRoot
    ).standardizedFileURL

    try requiredDirectory(appBundle, fileManager: fileManager)
    try validateSourceMembership(
        repositoryRoot: repositoryRoot,
        derivedData: derivedData,
        fileManager: fileManager
    )
    try validateInfoPlist(appBundle: appBundle, fileManager: fileManager)
    try validateEntitlements(appBundle: appBundle, fileManager: fileManager)
    print("✓ Xcode source membership, Host metadata, and entitlement configuration")
} catch {
    FileHandle.standardError.write(Data("error: \(error)\n".utf8))
    exit(1)
}
