import AppKit
import CoreGraphics
import Foundation
import XCTest

enum M5UITestPrerequisiteError: LocalizedError {
    case physicalFlagMissing
    case xctestConfigurationMissing
    case activeDisplayQueryFailed(CGError)
    case extendedDisplayRequired(activeCount: Int, screenCount: Int)
    case mirroringMustBeDisabled
    case uniquePrivateDisplayRequired
    case unsafeTemporaryRoot(String)
    case shieldControlMissing(String)
    case privateDisplayMenuItemMissing(String)
    case confirmationDidNotRevealController

    var errorDescription: String? {
        switch self {
        case .physicalFlagMissing:
            "Set PRIVATE_PRESENTER_M5_REAL_DISPLAY_UI=1 and attach a real extended, non-mirrored display."
        case .xctestConfigurationMissing:
            "XCTestConfigurationFilePath must be nonempty; the M5 UI test store override cannot be authorized."
        case .activeDisplayQueryFailed(let status):
            "CGGetActiveDisplayList failed with status \(status.rawValue)."
        case .extendedDisplayRequired(let activeCount, let screenCount):
            "M5 physical UI tests require at least two active NSScreen-backed displays; found \(activeCount) active and \(screenCount) screens."
        case .mirroringMustBeDisabled:
            "M5 physical UI tests require Extended Display mode; disable display mirroring and retry."
        case .uniquePrivateDisplayRequired:
            "A real private display with a unique visible name is required to drive the shield without topology substitution."
        case .unsafeTemporaryRoot(let path):
            "The canonical UI-test store root is not a strict descendant of NSTemporaryDirectory(): \(path)"
        case .shieldControlMissing(let identifier):
            "The real privacy shield did not expose required control \(identifier)."
        case .privateDisplayMenuItemMissing(let name):
            "The real privacy shield did not expose the active private display named \(name)."
        case .confirmationDidNotRevealController:
            "Real shield confirmation did not reveal the confirmed controller."
        }
    }
}

@MainActor
final class M5UITestSupport {
    let storeRoot: URL
    let privateDisplayName: String
    private let xctestConfigurationPath: String
    private let fileManager: FileManager

    init(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        fileManager: FileManager = .default
    ) throws {
        guard environment["PRIVATE_PRESENTER_M5_REAL_DISPLAY_UI"] == "1" else {
            throw M5UITestPrerequisiteError.physicalFlagMissing
        }
        guard let configuration = environment["XCTestConfigurationFilePath"],
            !configuration.isEmpty
        else {
            throw M5UITestPrerequisiteError.xctestConfigurationMissing
        }

        let activeIDs = try Self.activeDisplayIDs()
        let screens = NSScreen.screens
        guard activeIDs.count >= 2, screens.count >= 2 else {
            throw M5UITestPrerequisiteError.extendedDisplayRequired(
                activeCount: activeIDs.count,
                screenCount: screens.count
            )
        }
        guard activeIDs.allSatisfy({ displayID in
            CGDisplayIsInMirrorSet(displayID) == 0
                && CGDisplayMirrorsDisplay(displayID) == kCGNullDirectDisplay
        }) else {
            throw M5UITestPrerequisiteError.mirroringMustBeDisabled
        }

        let activeNames = screens.compactMap { screen -> String? in
            guard let number = screen.deviceDescription[
                NSDeviceDescriptionKey("NSScreenNumber")
            ] as? NSNumber,
                activeIDs.contains(CGDirectDisplayID(number.uint32Value))
            else { return nil }
            return screen.localizedName
        }
        let nameCounts = Dictionary(grouping: activeNames, by: { $0 }).mapValues(\.count)
        let preferredName = NSScreen.main?.localizedName
        guard
            let selectedName = preferredName.flatMap({ nameCounts[$0] == 1 ? $0 : nil })
                ?? activeNames.first(where: { nameCounts[$0] == 1 })
        else {
            throw M5UITestPrerequisiteError.uniquePrivateDisplayRequired
        }

        let temporary = URL(
            fileURLWithPath: NSTemporaryDirectory(),
            isDirectory: true
        ).resolvingSymlinksInPath().standardizedFileURL
        let candidate = temporary.appendingPathComponent(
            "private-presenter-m5-ui-\(UUID().uuidString)",
            isDirectory: true
        )
        try fileManager.createDirectory(at: candidate, withIntermediateDirectories: true)
        let canonicalCandidate = candidate.resolvingSymlinksInPath().standardizedFileURL
        guard Self.isStrictDescendant(canonicalCandidate, of: temporary) else {
            try? fileManager.removeItem(at: candidate)
            throw M5UITestPrerequisiteError.unsafeTemporaryRoot(canonicalCandidate.path)
        }

        self.fileManager = fileManager
        xctestConfigurationPath = configuration
        storeRoot = canonicalCandidate
        privateDisplayName = selectedName
    }

    func cleanUp() {
        try? fileManager.removeItem(at: storeRoot)
    }

    func launchShieldedApplication() throws -> XCUIApplication {
        let application = XCUIApplication()
        application.launchEnvironment["PRIVATE_PRESENTER_UI_TEST"] = "1"
        application.launchEnvironment["XCTestConfigurationFilePath"] =
            xctestConfigurationPath
        application.launchEnvironment["PRIVATE_PRESENTER_UI_TEST_STORE_ROOT"] =
            storeRoot.path
        application.launch()

        let picker = element("privatePresenter.privateDisplayPicker", in: application)
        guard picker.waitForExistence(timeout: 5) else {
            application.terminate()
            throw M5UITestPrerequisiteError.shieldControlMissing(picker.identifier)
        }
        return application
    }

    func launchConfirmedApplication() throws -> XCUIApplication {
        let application = try launchShieldedApplication()
        let picker = element("privatePresenter.privateDisplayPicker", in: application)
        picker.click()
        let realDisplay = application.menuItems[privateDisplayName]
        guard realDisplay.waitForExistence(timeout: 3) else {
            application.terminate()
            throw M5UITestPrerequisiteError.privateDisplayMenuItemMissing(
                privateDisplayName
            )
        }
        realDisplay.click()

        let confirm = element("privatePresenter.confirmPrivateDisplay", in: application)
        guard confirm.waitForExistence(timeout: 3) else {
            application.terminate()
            throw M5UITestPrerequisiteError.shieldControlMissing(confirm.identifier)
        }
        confirm.click()
        guard element("privatePresenter.scriptTitle", in: application)
            .waitForExistence(timeout: 5)
        else {
            application.terminate()
            throw M5UITestPrerequisiteError.confirmationDidNotRevealController
        }
        return application
    }

    func element(_ identifier: String, in application: XCUIApplication) -> XCUIElement {
        application.descendants(matching: .any)[identifier]
    }

    private static func activeDisplayIDs() throws -> [CGDirectDisplayID] {
        var count: UInt32 = 0
        var status = CGGetActiveDisplayList(0, nil, &count)
        guard status == .success else {
            throw M5UITestPrerequisiteError.activeDisplayQueryFailed(status)
        }
        var displays = Array(repeating: CGDirectDisplayID(), count: Int(count))
        var actual: UInt32 = 0
        status = displays.withUnsafeMutableBufferPointer { buffer in
            CGGetActiveDisplayList(count, buffer.baseAddress, &actual)
        }
        guard status == .success else {
            throw M5UITestPrerequisiteError.activeDisplayQueryFailed(status)
        }
        return Array(displays.prefix(Int(actual)))
    }

    private static func isStrictDescendant(_ candidate: URL, of parent: URL) -> Bool {
        let parentComponents = parent.pathComponents
        let candidateComponents = candidate.pathComponents
        return candidateComponents.count > parentComponents.count
            && Array(candidateComponents.prefix(parentComponents.count)) == parentComponents
    }
}
