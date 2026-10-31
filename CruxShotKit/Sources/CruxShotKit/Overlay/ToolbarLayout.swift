import CoreGraphics

/// Placement shared by capture overlays (local coordinates) and pin panels (screen coordinates).
struct ToolbarLayout {
    let tools: CGRect
    let actions: CGRect

    init(selection: CGRect, available: CGRect, toolSize: CGSize, actionSize: CGSize) {
        let gap: CGFloat = 8
        let area = available.insetBy(dx: 6, dy: 6)
        func clamped(_ origin: CGPoint, _ size: CGSize) -> CGRect {
            CGRect(x: max(area.minX, min(origin.x, area.maxX - size.width)),
                   y: max(area.minY, min(origin.y, area.maxY - size.height)),
                   width: size.width, height: size.height)
        }
        func overlap(_ a: CGRect, _ b: CGRect) -> CGFloat {
            let r = a.intersection(b)
            return r.isNull ? 0 : r.width * r.height
        }
        let toolXs = [selection.minX - gap - toolSize.width, selection.maxX + gap,
                      area.minX, area.maxX - toolSize.width]
        let toolYs = [selection.maxY - toolSize.height, selection.minY,
                      area.maxY - toolSize.height, area.minY]
        let actionXs = [selection.maxX - actionSize.width, selection.minX,
                        area.maxX - actionSize.width, area.minX]
        let actionYs = [selection.minY - gap - actionSize.height, selection.maxY + gap,
                        area.minY, area.maxY - actionSize.height]
        var best: (CGRect, CGRect, CGFloat)?
        for x in toolXs {
            for y in toolYs {
                let tools = clamped(CGPoint(x: x, y: y), toolSize)
                for ax in actionXs {
                    for ay in actionYs {
                        let actions = clamped(CGPoint(x: ax, y: ay), actionSize)
                        // Keep the two controls apart first, then preserve as much image as possible.
                        let collision = overlap(tools.insetBy(dx: -gap / 2, dy: -gap / 2), actions)
                        let covered = overlap(tools, selection) + overlap(actions, selection)
                        let distance = abs(tools.maxX + gap - selection.minX)
                            + abs(tools.maxY - selection.maxY)
                            + abs(actions.maxX - selection.maxX)
                            + abs(actions.maxY + gap - selection.minY)
                        let score = collision * 10_000 + covered * 10 + distance
                        if best == nil || score < best!.2 { best = (tools, actions, score) }
                    }
                }
            }
        }
        tools = best!.0
        actions = best!.1
    }
}
