import Foundation

public enum CounterStyle: String, CaseIterable, Sendable {
    case preciseRing, openRing, baseline

    public var title: String {
        switch self {
        case .preciseRing: "精密圆环"
        case .openRing: "开口圆环"
        case .baseline: "基线数字"
        }
    }
}
