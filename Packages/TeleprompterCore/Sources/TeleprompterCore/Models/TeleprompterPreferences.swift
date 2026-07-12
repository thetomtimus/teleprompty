import Foundation

public enum TeleprompterFontWeight: String, Codable, CaseIterable, Equatable, Sendable {
    case regular
    case medium
    case semibold
}

public enum TeleprompterTextAlignment: String, Codable, CaseIterable, Equatable, Sendable {
    case left
    case center
}

public struct TeleprompterPreferences: Codable, Equatable, Sendable {
    public static let speedRange: ClosedRange<Double> = 10...240
    public static let speedStep: Double = 5
    public static let defaultSpeedPointsPerSecond: Double = 60
    public static let fontSizeRange: ClosedRange<Double> = 24...96
    public static let fontSizeStep: Double = 2
    public static let defaultFontSizePoints: Double = 42

    public var speedPointsPerSecond: Double
    public var fontSizePoints: Double
    public var fontWeight: TeleprompterFontWeight
    public var textAlignment: TeleprompterTextAlignment
    public var isActiveBandEnabled: Bool
    public var isFocusModeEnabled: Bool
    public var isLocked: Bool
    public var selectedDisplayFingerprint: DisplayFingerprint?

    public init(
        speedPointsPerSecond: Double = TeleprompterPreferences.defaultSpeedPointsPerSecond,
        fontSizePoints: Double = TeleprompterPreferences.defaultFontSizePoints,
        fontWeight: TeleprompterFontWeight = .regular,
        textAlignment: TeleprompterTextAlignment = .left,
        isActiveBandEnabled: Bool = true,
        isFocusModeEnabled: Bool = true,
        isLocked: Bool = false,
        selectedDisplayFingerprint: DisplayFingerprint? = nil
    ) {
        self.speedPointsPerSecond = Self.clamp(
            speedPointsPerSecond,
            to: Self.speedRange,
            nonfiniteDefault: Self.defaultSpeedPointsPerSecond
        )
        self.fontSizePoints = Self.clamp(
            fontSizePoints,
            to: Self.fontSizeRange,
            nonfiniteDefault: Self.defaultFontSizePoints
        )
        self.fontWeight = fontWeight
        self.textAlignment = textAlignment
        self.isActiveBandEnabled = isActiveBandEnabled
        self.isFocusModeEnabled = isFocusModeEnabled
        self.isLocked = isLocked
        self.selectedDisplayFingerprint = selectedDisplayFingerprint
    }

    private enum CodingKeys: String, CodingKey {
        case speedPointsPerSecond
        case fontSizePoints
        case fontWeight
        case textAlignment
        case isActiveBandEnabled
        case isFocusModeEnabled
        case isLocked
        case selectedDisplayFingerprint
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            speedPointsPerSecond: try container.decode(Double.self, forKey: .speedPointsPerSecond),
            fontSizePoints: try container.decode(Double.self, forKey: .fontSizePoints),
            fontWeight: try container.decode(TeleprompterFontWeight.self, forKey: .fontWeight),
            textAlignment: try container.decode(
                TeleprompterTextAlignment.self,
                forKey: .textAlignment
            ),
            isActiveBandEnabled: try container.decode(Bool.self, forKey: .isActiveBandEnabled),
            isFocusModeEnabled: try container.decode(Bool.self, forKey: .isFocusModeEnabled),
            isLocked: try container.decode(Bool.self, forKey: .isLocked),
            selectedDisplayFingerprint: try container.decodeIfPresent(
                DisplayFingerprint.self,
                forKey: .selectedDisplayFingerprint
            )
        )
    }

    private static func clamp(
        _ value: Double,
        to range: ClosedRange<Double>,
        nonfiniteDefault: Double
    ) -> Double {
        guard value.isFinite else { return nonfiniteDefault }
        return min(max(value, range.lowerBound), range.upperBound)
    }
}
