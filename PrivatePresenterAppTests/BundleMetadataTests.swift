import XCTest

final class BundleMetadataTests: XCTestCase {
    func testBundleVersionIsAStringForMetalTelemetryCompatibility() throws {
        let version = try XCTUnwrap(
            Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion")
        )

        XCTAssertTrue(version is String)
        XCTAssertEqual(version as? String, "1")
    }
}
