import CoreGraphics

/// Keeps the two-row tool rack near one crop corner and the output bar apart from it.
struct ToolbarLayout {
    let tools: CGRect
    let actions: CGRect

    init(selection: CGRect, available: CGRect, toolSize: CGSize, actionSize: CGSize) {
        let gap: CGFloat = 8
        let area = available.insetBy(dx: 6, dy: 6)
        func clamped(_ x: CGFloat, _ y: CGFloat, _ size: CGSize) -> CGRect {
            CGRect(x: max(area.minX, min(x, area.maxX - size.width)),
                   y: max(area.minY, min(y, area.maxY - size.height)),
                   width: size.width, height: size.height)
        }
        func overlap(_ a: CGRect, _ b: CGRect) -> CGFloat {
            let intersection = a.intersection(b)
            return intersection.isNull ? 0 : intersection.width * intersection.height
        }
        let toolXs = [selection.minX, area.minX, selection.maxX - toolSize.width,
                      area.maxX - toolSize.width]
        let toolYs = [selection.minY - gap - toolSize.height, selection.maxY + gap,
                      area.minY, area.maxY - toolSize.height]
        let actionXs = [selection.maxX - actionSize.width, selection.maxX + gap,
                        area.maxX - actionSize.width, selection.minX, area.minX]
        let actionYs = [selection.minY - gap - actionSize.height, selection.maxY + gap,
                        area.minY, area.maxY - actionSize.height]
        var best: (CGRect, CGRect, (CGFloat, CGFloat, CGFloat))?
        for x in toolXs {
            for y in toolYs {
                let rack = clamped(x, y, toolSize)
                for ax in actionXs {
                    for ay in actionYs {
                        let output = clamped(ax, ay, actionSize)
                        let collision = overlap(rack.insetBy(dx: -gap / 2, dy: -gap / 2), output)
                        let covered = overlap(rack, selection) + overlap(output, selection)
                        let distance = abs(rack.minX - selection.minX)
                            + abs(rack.maxY + gap - selection.minY)
                            + abs(output.maxX - selection.maxX)
                            + abs(output.maxY + gap - selection.minY)
                        let score = (collision, covered, distance)
                        if let previous = best?.2 {
                            if score.0 < previous.0 || (score.0 == previous.0 &&
                                (score.1 < previous.1 || (score.1 == previous.1 && score.2 < previous.2))) {
                                best = (rack, output, score)
                            }
                        } else {
                            best = (rack, output, score)
                        }
                    }
                }
            }
        }
        tools = best!.0
        actions = best!.1
    }
}
