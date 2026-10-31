import Foundation

public enum ArrowStyle: String, CaseIterable, Sendable {
    case classic, fine, tapered, doubleEnded, dashed, handDrawn

    public var title: String {
        switch self {
        case .classic: "经典实心"
        case .fine: "精细开口"
        case .tapered: "渐粗聚焦"
        case .doubleEnded: "双向对照"
        case .dashed: "虚线关联"
        case .handDrawn: "手绘弧箭"
        }
    }
}
